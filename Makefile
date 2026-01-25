# ===== Allowed stacks =====
STACK ?= dev-app
ALLOWED_STACKS := dev-core dev-app

DIR := infra/envs/$(STACK)

TF ?= terraform
PLANFILE ?= tfplan

.PHONY: whoami guard-stack init fmt validate check plan apply apply-auto \
        show outputs state destroy destroy-auto \
        core-up app-up up app-down core-down down

whoami:
	@echo "STACK=$(STACK)"
	@echo "DIR=$(DIR)"
	@echo "AWS_PROFILE=$${AWS_PROFILE}"
	@echo "AWS_REGION=$${AWS_REGION}"

# STACKが許可リストにない/ディレクトリがない場合は止める
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

init: guard-stack
	cd $(DIR) && $(TF) init

fmt: guard-stack
	cd $(DIR) && $(TF) fmt -recursive

validate: guard-stack
	cd $(DIR) && $(TF) validate

check: fmt validate

plan: guard-stack check
	cd $(DIR) && $(TF) plan -out=$(PLANFILE)

show: guard-stack
	cd $(DIR) && $(TF) show

# planを必ず経由して、そのplanをapplyする（推奨）
apply: plan
	cd $(DIR) && $(TF) apply $(PLANFILE)

# CI向け（planは作るが apply は auto-approve）
apply-auto: plan
	cd $(DIR) && $(TF) apply -auto-approve $(PLANFILE)

outputs: guard-stack
	cd $(DIR) && $(TF) output

state: guard-stack
	cd $(DIR) && $(TF) state list

destroy: guard-stack check
	cd $(DIR) && $(TF) destroy

destroy-auto: guard-stack check
	cd $(DIR) && $(TF) destroy -auto-approve

# ===== Stack-aware shortcuts =====
core-up:
	$(MAKE) apply STACK=dev-core

app-up:
	$(MAKE) apply STACK=dev-app

# downは依存順序：app → core
app-down:
	$(MAKE) destroy STACK=dev-app

core-down:
	$(MAKE) destroy STACK=dev-core

up: core-up app-up
down: app-down core-down
