# ===== 対象スタック（dev専用）=====
# STACK は dev-core / dev-app のどちらかを指定する
# 例: make plan STACK=dev-core
STACK ?= dev-app
ALLOWED_STACKS := dev-core dev-app

# Terraform 実行ディレクトリ（envs/<stack>）
DIR := infra/envs/$(STACK)

# 使用コマンド（必要なら TF=/path/to/terraform で上書き可）
TF ?= terraform

# plan の出力ファイル名（apply はこの plan を適用する）
PLANFILE ?= tfplan

# 実行時間計測
TIME ?= /usr/bin/time -p

.PHONY: whoami guard-stack init fmt validate check plan apply apply-auto \
        show outputs state destroy destroy-auto \
        core-up app-up up app-down core-down down

# 実行対象の確認（事故防止・デバッグ用）
# guard-stack を通すので、存在しないSTACKならここで止まる
whoami: guard-stack
	@echo "STACK=$(STACK)"
	@echo "DIR=$(DIR)"
	@echo "AWS_PROFILE=$${AWS_PROFILE}"
	@echo "AWS_REGION=$${AWS_REGION}"

# 事故防止ガード：
# - STACK が許可リスト外なら停止
# - 対象ディレクトリが存在しなければ停止
guard-stack:
	@if ! echo "$(ALLOWED_STACKS)" | tr ' ' '\n' | grep -qx "$(STACK)"; then \
		echo "Invalid STACK=$(STACK)"; \
		echo "Allowed: $(ALLOWED_STACKS)"; \
		exit 1; \
	fi
	@if [ ! -d "$(DIR)" ]; then \
		echo "DIR not found: $(DIR)"; \
		exit 1; \
	fi

# 初期化（backend/providerの準備）
init: guard-stack
	cd $(DIR) && $(TF) init

# フォーマット（全体を整形）
fmt: guard-stack
	cd $(DIR) && $(TF) fmt -recursive

# 構文チェック
validate: guard-stack
	cd $(DIR) && $(TF) validate

# いつものチェック（fmt + validate）
check: fmt validate

# plan を作ってファイルに保存（apply は必ずこの plan を使う）
plan: guard-stack check
	cd $(DIR) && $(TIME) $(TF) plan -out=$(PLANFILE)

# terraform show（直近の状態表示。planfileを見たいなら `terraform show tfplan` を別途）
show: guard-stack
	cd $(DIR) && $(TF) show

# 推奨：plan を必ず経由し、その planfile を apply
apply: plan
	cd $(DIR) && $(TIME) $(TF) apply -parallelism=20 $(PLANFILE)

# CI/自動化向け：plan は作るが apply は自動承認
apply-auto: plan
	cd $(DIR) && $(TIME) $(TF) apply -parallelism=20 -auto-approve $(PLANFILE)

# outputs の確認（例: db_secret_arn など）
outputs: guard-stack
	cd $(DIR) && $(TF) output

# state の中身確認（デバッグ用）
state: guard-stack
	cd $(DIR) && $(TF) state list

# 手動 destroy（確認プロンプトあり）
destroy: guard-stack check
	cd $(DIR) && $(TIME) $(TF) destroy -parallelism=20

# 自動 destroy（cron/自動化向け）
destroy-auto: guard-stack check
	cd $(DIR) && $(TIME) $(TF) destroy -auto-approve -parallelism=20

# ===== ショートカット =====
# core/app を個別に up/down したいとき用

# core を作る（VPC/RDSなど）
core-up:
	$(MAKE) apply STACK=dev-core

# app を作る（ALB/ECS/ECR/VPCEなど）
app-up:
	$(MAKE) apply STACK=dev-app

# app を落とす（依存関係の外側から消す）
app-down:
	$(MAKE) destroy STACK=dev-app

# core を落とす（RDS含む。app を先に落としてから）
core-down:
	$(MAKE) destroy STACK=dev-core

# まとめて作成：core → app の順（依存順）
up: core-up app-up

# まとめて削除：app → core の順（依存順）
down: app-down core-down
