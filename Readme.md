# saito-infra-lab（dev）

TerraformでAWS上に「作って壊して学ぶ」ためのdev環境を構築するリポジトリ。

- VPC（3層: public / private-app / private-db、2AZ）
- ALB（HTTPS終端、80→443 redirect、Route53で `api.dev.saito-infra-lab.click`）
- ECS（Fargate、Goアプリ、HTTPのみ、ECR、CloudWatch Logs）
- RDS（PostgreSQL 16）
- NATなし運用（学習目的）：VPC Endpoint で閉域化
- 観測性：ALB access logs → S3 → Athena、アプリログは CloudWatch Logs
- CI/CD：GitHub Actions + OIDC（長期キーなし）で ECR push → ECSデプロイ

> dev環境は「作って壊す」前提。反復を速くするため Terraform スタックを `dev-core` / `dev-app` に分割している。

---

## 前提

- Region: `ap-northeast-1` (Tokyo)
- Environment: dev only（作って壊す前提）
- Domain: `saito-infra-lab.click`（Route 53）
- FQDN: `api.dev.saito-infra-lab.click`
- App: Go（net/http）、HTTP only（TLS終端はALB）

---

## ディレクトリ構成

### Terraform
- `infra/envs/dev-core/`
  - VPC / Security Group / RDS / DB Secret（など、土台）
- `infra/envs/dev-app/`
  - ECR / ALB / ECS / VPC Endpoints / Observability / GitHub OIDC（など、アプリ側）
  - `terraform_remote_state` で `dev-core` outputs を参照
- `infra/modules/`
  - 各コンポーネントのモジュール群

> 旧 `infra/envs/dev/` は廃止（削除済み）。

### Scripts
- `script/saito-infra-lab-weekend-down.sh`：週末destroy（cronで利用）
- `script/saito-infra-lab-weekday-up.sh`：月曜復旧（手動実行）
- `script/bootstrap.sh`：初期セットアップ用（必要に応じて）

---

## 構成概要（3層）

- ALB（Public Subnet）
- ECS Tasks（Private App Subnet）
- RDS（Private DB Subnet）

---

## ネットワーク方針（重要：NATなし）

dev環境は **NAT Gatewayを使わない**（学習目的）。

代わりに、ECSが必要とするAWSサービスへの通信は **VPC Endpoint（Interface/Gateway）** で閉域化する。

---

## NATなしでECSが動く成立条件（チェックリスト）

ECS(Fargate) を Private Subnet で起動し、NATなしで運用するための前提条件：

- [ ] ECSタスクは **Private App Subnet** に配置されている（assign_public_ip=false）
- [ ] NAT Gatewayなし
- [ ] 以下の VPC Endpoint が作成されている
  - Interface: `ecr.api`, `ecr.dkr`, `logs`, `secretsmanager`
  - Gateway: `s3`
- [ ] Interface Endpoint は `private_dns_enabled = true`
- [ ] S3 Gateway Endpoint は **private route table に関連付け**されている（ECRのレイヤ取得で必要）
- [ ] VPCE用SG inbound は **TCP 443** を **ECSタスクSGからのみ許可**

---

## ALB(HTTPS)の成立条件（要点）

- Route 53 の Aレコード(Alias) で ALB に向ける
- ACM は DNS 検証で証明書発行
- HTTP(80) → HTTPS(443) リダイレクト
- Listener(443) が Target Group に forward していること

---

## Secrets運用方針（DB接続）

- Secrets Manager の値は `DB_SECRET_JSON` としてコンテナへ注入する
- JSONに以下を含める（RDS再作成に強い）
  - `host`, `port`, `dbname`, `username`, `password`
- アプリ側でJSONをparseして接続情報を取り出す
- Secrets取得権限は主に **task execution role（起動時）** に付与する

---

## CI/CD（GitHub Actions）

- main push をトリガに以下を実行
  - Docker build（linux/amd64）
  - ECRへ push（`:sha` と `:dev`）
  - **毎回新しい ECS Task Definition を登録**
  - ECS Service を更新してデプロイ
- workflow: `.github/workflows/deploy-dev.yml`
- task definition template: `deploy/taskdef-dev.tpl.json`
  - `${DB_SECRET_ARN}` を埋め込んで `deploy/taskdef-dev.json` を生成して使う（生成物はgit管理しないのが推奨）
- AWS認証は GitHub OIDC を使用（長期AccessKeyは使わない）

### 重要：DB_SECRET_ARN の更新
`dev-core` を destroy/apply すると Secret のARNが変わることがある。  
その場合、GitHub Secrets の `DB_SECRET_ARN` を更新しないとデプロイが失敗する。

---

## 観測性（ALB logs → Athena / アプリ logs → CloudWatch）

### ALB access logs（S3）
- ALB access logs をS3に出力する（明示的にONが必要）
- 出力先例：
  - `s3://<bucket>/alb/AWSLogs/<account-id>/elasticloadbalancing/ap-northeast-1/YYYY/MM/DD/...`

### Athena（ALBログ）
- partition projection 前提で `day='YYYY/MM/DD'` を指定してクエリする

#### 例：/db/health を探す
```sql
SELECT time, request_url, elb_status_code, target_status_code, trace_id, domain_name
FROM alb_access_logs
WHERE day='YYYY/MM/DD'
  AND request_url LIKE '%/db/health%'
ORDER BY time DESC
LIMIT 50;
```

### ログ相関（Athena → CloudWatch）
ブラウザのレスポンスヘッダ `x-amzn-trace-id`（例：`Root=1-...`）を起点に相関する。

1) Athenaで該当リクエストを特定（trace_idで絞る）
```sql
SELECT time, request_url, elb_status_code, target_status_code, trace_id
FROM alb_access_logs
WHERE day='YYYY/MM/DD'
  AND trace_id='Root=1-xxxxxxxx-xxxxxxxxxxxxxxxxxxxxxxxx'
LIMIT 10;
```

2) CloudWatch Logs Insights（ECSアプリログ）で同じIDを検索
```sql
fields @timestamp, @message
| filter @message like /1-xxxxxxxx-xxxxxxxxxxxxxxxxxxxxxxxx/
| sort @timestamp desc
| limit 50
```

---

## よくある障害と切り分け

### 1) ECSがECRからpullできない
- 症状例: `CannotPullContainerError`
- 確認:
  - `ecr.api` / `ecr.dkr` の Interface Endpoint があるか
  - `s3` Gateway Endpoint が private route table に紐付いているか
  - `private_dns_enabled = true` か
  - イメージタグが存在するか（例: `:dev` をpushしたか）

### 2) CloudWatch Logsにログが出ない
- 確認:
  - `logs` Interface Endpoint があるか
  - VPCE SG で 443 を ECS SG から許可しているか
  - task execution role の権限（logs:PutLogEvents 等）があるか

### 3) Secrets Manager の注入で落ちる
- 症状例: `ResourceInitializationError: unable to pull secrets ... AccessDenied`
- 確認:
  - `secretsmanager` Interface Endpoint があるか
  - **execution role** に `secretsmanager:GetSecretValue` があるか（task roleではなく）

### 4) destroy が S3/ECR の “中身が残ってる” で落ちる
dev用途ではよくある。
- S3: `BucketNotEmpty`
- ECR: `RepositoryNotEmptyException`

---

## 運用コマンド（Makefile）

> `ENV=dev` は廃止。`STACK=dev-core` / `STACK=dev-app` を使う。

- plan:
  - `make plan STACK=dev-core`
  - `make plan STACK=dev-app`
- apply:
  - `make apply STACK=dev-core`
  - `make apply STACK=dev-app`
  - まとめて：`make up`（core→app）
- destroy:
  - `make destroy STACK=dev-app`
  - `make destroy STACK=dev-core`
  - まとめて：`make down`（app→core）
- 自動destroy（cron向け）：
  - `make destroy-auto STACK=dev-app`
  - `make destroy-auto STACK=dev-core`

---

## 週末destroy（cron / JST土曜03:00）

- 実行スクリプト：
  - `script/saito-infra-lab-weekend-down.sh`

- crontab（ログ出力込み）：
```cron
0 3 * * 6 /home/n-saitou/saito-infra-lab/script/saito-infra-lab-weekend-down.sh >> /home/n-saitou/logs/cron-weekend-down.log 2>&1
```

- 状態確認：
  - `crontab -l`
  - `tail -n 200 /home/n-saitou/logs/cron-weekend-down.log`

---

## 月曜復旧（手動）

- 実行スクリプト：
  - `script/saito-infra-lab-weekday-up.sh`

- 実行：
```bash
./script/saito-infra-lab-weekday-up.sh
```

期待する流れ：
1) `make up`（core→app）
2) `dev-core` の `db_secret_arn` を取得し、GitHub Secrets `DB_SECRET_ARN` を更新（スクリプトが実施）
3) GitHub Actions でデプロイ（main push または rerun）

---

## 動作確認（例）

- `GET /health`
- `GET /db/health`

---

## コスト注意点（dev）

- NAT Gatewayは高額になりやすいので dev では使わない方針
- Interface VPC Endpoint は **AZごとに時間課金**があるため、必要最小限にする
- 体感のボトルネックは RDS 作成（数分）になりがち → スタック分割で緩和

---

## GitHub Actionsで手動デプロイ（mainにpushせずに再デプロイしたい）

### ケース
- `DB_SECRET_ARN` を更新した
- インフラは復旧した
- でも main に新しいコミットを入れたくない / すぐデプロイだけしたい

### 手順（GitHub UI）
1. GitHub リポジトリ `saiist/saito-infra-lab` を開く
2. **Actions** タブ → ワークフロー（例：`deploy-dev`）を選ぶ
3. 「Run workflow」(workflow_dispatchがある場合) か、直近の実行を **Re-run jobs** する

> 補足：workflow_dispatchが無い場合は、README上は「Re-run jobs」でOK。  
> もし `workflow_dispatch` を追加するなら `.github/workflows/deploy-dev.yml` に `on: workflow_dispatch:` を追記する。

### 手順（gh CLI）
`gh` を使うなら、まず一覧：
```bash
gh workflow list -R saiist/saito-infra-lab
```

実行（workflow_dispatch対応している場合）：
```bash
gh workflow run deploy-dev.yml -R saiist/saito-infra-lab
```

実行状況：
```bash
gh run list -R saiist/saito-infra-lab --limit 5
gh run view -R saiist/saito-infra-lab --log
```

---

## destroyがS3/ECRの“中身が残ってる”で止まった場合（手動復旧）

### 症状
週末destroy（または手動destroy）で以下のようなエラーが出て止まることがある。

- S3: `BucketNotEmpty`
- ECR: `RepositoryNotEmptyException`

この場合、**中身を空にしてから destroy を再実行**する。

### 1) S3（ALB access logs bucket）を空にする
```bash
aws s3 rm s3://saito-infra-lab-dev-alb-access-logs-977099016337 --recursive
```

### 2) ECR（アプリリポジトリ）のイメージを全削除する
```bash
repo="saito-infra-lab-dev-app"

aws ecr list-images \
  --repository-name "$repo" \
  --query 'imageIds[*]' \
  --output json > /tmp/ecr-images.json

if [ "$(cat /tmp/ecr-images.json)" != "[]" ]; then
  aws ecr batch-delete-image \
    --repository-name "$repo" \
    --image-ids file:///tmp/ecr-images.json
fi

rm -f /tmp/ecr-images.json
```

### 3) destroy を再実行（順序：app → core）
```bash
make destroy-auto STACK=dev-app
make destroy-auto STACK=dev-core
```
