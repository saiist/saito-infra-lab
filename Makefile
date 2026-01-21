ENV ?= dev
DIR := infra/envs/$(ENV)

TF ?= terraform
PLANFILE ?= tfplan

.PHONY: init fmt validate check plan apply apply-auto destroy destroy-auto \
        show outputs state whoami

whoami:
	@echo "ENV=$(ENV)"
	@echo "DIR=$(DIR)"
	@echo "AWS_PROFILE=$${AWS_PROFILE}"
	@echo "AWS_REGION=$${AWS_REGION}"

init:
	cd $(DIR) && $(TF) init

fmt:
	cd $(DIR) && $(TF) fmt -recursive

validate:
	cd $(DIR) && $(TF) validate

check: fmt validate

plan: check
	cd $(DIR) && $(TF) plan -out=$(PLANFILE)

show:
	cd $(DIR) && $(TF) show

# planを必ず経由して、そのplanをapplyする（推奨）
apply: plan
	cd $(DIR) && $(TF) apply $(PLANFILE)

# どうしても自動承認したいときだけ（CI向け）
apply-auto: plan
	cd $(DIR) && $(TF) apply -auto-approve $(PLANFILE)

outputs:
	cd $(DIR) && $(TF) output

state:
	cd $(DIR) && $(TF) state list

# 事故防止ガード：ENV指定なし/想定外だと止める
guard-env:
	@if [ "$(ENV)" = "prod" ] || [ "$(ENV)" = "production" ]; then \
		echo "Refusing to run destroy for ENV=$(ENV)."; exit 1; \
	fi

destroy: guard-env check
	cd $(DIR) && $(TF) destroy

destroy-auto: guard-env check
	cd $(DIR) && $(TF) destroy -auto-approve
