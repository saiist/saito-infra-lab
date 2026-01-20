# デフォルトは dev 環境
ENV ?= dev
DIR = infra/envs/$(ENV)

.PHONY: init plan apply destroy fmt check

# 初期化 (モジュール追加時などに実行)
init:
	cd $(DIR) && terraform init

# コード整形 & 文法チェック (CI/CDの基本)
check:
	cd $(DIR) && terraform fmt -recursive
	cd $(DIR) && terraform validate

# 実行計画 (整形→検証→Plan の順で実行して品質を保つ)
plan: check
	cd $(DIR) && terraform plan

# 適用 (Planなしで直接Apply)
apply: check
	cd $(DIR) && terraform apply

# 削除 (お掃除用)
destroy:
	cd $(DIR) && terraform destroy
