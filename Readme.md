# saito-infra-lab（dev）

Terraformで以下を学習目的で構築する。

- VPC
- ALB (HTTPS)
- ECS(Fargate)
- RDS(PostgreSQL 16)

> dev環境は「作って壊す」を前提にしている。

---

## 前提
- Region: ap-northeast-1 (Tokyo)
- Environment: dev only（作って壊す前提）
- Domain: saito-infra-lab.click（Route 53）
- Example FQDN: api.dev.saito-infra-lab.click
- App: Go (net/http), HTTP only（TLS終端はALB）

---

## ディレクトリ構成（Terraform）
- `infra/envs/dev/` : 実行単位（plan/apply/destroyはここを対象）
- `infra/modules/`  : 各コンポーネントのモジュール群（vpc/alb/ecs/rds/...）

---

## 構成概要

- ALB（Public Subnet）
- ECS Tasks（Private App Subnet）
- RDS（Private DB Subnet）

### ネットワーク方針（重要）

dev環境は **NAT Gatewayを使わない**（enable_nat_gateway=false）。

その代わり、ECSが必要とするAWSサービスへの通信は **VPC Endpoint（PrivateLink / Gateway）** で閉域化する。

---

## NATなしでECSが動く成立条件（チェックリスト）

ECS(Fargate) を Private Subnet で起動し、NATなしで運用するための前提条件：

- [ ] ECSタスクは **Private Subnet** に配置されている
- [ ] NAT Gateway なし（`enable_nat_gateway = false`）
- [ ] 以下の VPC Endpoint が作成されている
  - Interface: `ecr.api`, `ecr.dkr`, `logs`, `secretsmanager`
  - Gateway: `s3`
- [ ] Interface Endpoint は `private_dns_enabled = true`
- [ ] S3 Gateway Endpoint は **private route table に関連付け**されている  
      （ECRのイメージレイヤ取得でS3が使われるため）
- [ ] VPCE用SGの inbound は **TCP 443** を **ECSタスクSGからのみ許可**している

---

## ALB(HTTPS)の成立条件（要点）
- Route 53 の Aレコード(Alias) で ALB に向ける
- ACM は DNS 検証で証明書発行
- HTTP(80) → HTTPS(443) リダイレクト
- Listener(443) が Target Group に forward していること（ECSサービス作成で詰まりがち）

---

## Secrets運用方針
- Secrets Manager の値は `DB_SECRET_JSON` としてコンテナへ注入する
- アプリ側でJSONをparseして接続情報を取り出す
- Secrets取得権限は主に **task execution role**（起動時）に付与する

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
  - task execution role の権限（ログ出力）があるか

### 3) Secrets Manager の注入で落ちる
- 症状例: `ResourceInitializationError: unable to pull secrets ... AccessDenied`
- 確認:
  - `secretsmanager` Interface Endpoint があるか
  - **execution role** に `secretsmanager:GetSecretValue` があるか（task roleではなく）

---

## 運用コマンド

### Terraform
- plan:
  - `make plan ENV=dev`
- apply:
  - `make apply ENV=dev`
- destroy:
  - `make destroy ENV=dev`

### 動作確認（例）
- `/health`
- `/db/health`

---

## コスト注意点（dev）
- NAT Gatewayは高額になりやすいので dev では使わない方針
- Interface VPC Endpoint は AZごとに時間課金があるため、必要最小限にする
