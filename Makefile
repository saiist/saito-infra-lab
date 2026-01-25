# ===== Basics =====
# STACK: dev-core / dev-app （推奨）
STACK ?= dev-app

# 旧互換（ENV=dev-core みたいに指定しても動く）
ENV ?=

TF ?= terraform
PLANFILE ?= tfplan

# STACK優先。STACK未指定でENVだけある場合はENVを使う。
ifeq ($(ENV),)
  DIR := infra/envs/$(STACK)
else
  DIR := infra/envs/$(ENV)
endif

.PHONY: whoami init fmt validate check plan apply apply-auto destroy destroy-auto \
        show outputs state guard-stack guard-no-prod \
        up down core-up core-down app-up app-down

whoami:
	@echo "STACK=$(STACK)"
	@echo "ENV=$(ENV)"
	@echo "DIR=$(DIR)"
	@echo "AWS_PROFILE=$${AWS_PROFILE}"
	@echo "AWS_REGION=$${AWS_REGION}"

# ===== Guards =====
guard-stack:
	@if [ ! -d "$(DIR)" ]; then \
		echo "DIR not found: $(DIR)"; \
		echo "Hint: make whoami STACK=dev-core  or  make whoami STACK=dev-app"; \
		exit 1; \
	fi

# 事故防止：prod系は全部拒否（必要なら緩めてOK）
guard-no-prod:
	@case "$(STACK)$(ENV)" in \
	  *prod*|*production*) echo "Refusing to run for prod-like stack: STACK=$(STACK) ENV=$(ENV)"; exit 1 ;; \
	esac

# ===== Terraform wrappers =====
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

destroy: guard-stack guard-no-prod check
	cd $(DIR) && $(TF) destroy

destroy-auto: guard-stack guard-no-prod check
	cd $(DIR) && $(TF) destroy -auto-approve

# ===== Stack-aware shortcuts (recommended) =====
core-up:
	$(MAKE) apply STACK=dev-core ENV=
app-up:
	$(MAKE) apply STACK=dev-app ENV=

# 依存順序：downは app → core
app-down:
	$(MAKE) destroy STACK=dev-app ENV=
core-down:
	$(MAKE) destroy STACK=dev-core ENV=

up: core-up app-up
down: app-down core-down
