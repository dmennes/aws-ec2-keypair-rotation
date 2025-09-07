# ==== Load local config (not committed) ====
-include .env
# Guards (fail fast if missing)
ifeq ($(strip $(BUCKET)),)
  $(error BUCKET is not set. Create .env from .env.example)
endif
ifeq ($(strip $(DDB)),)
  $(error DDB is not set. Create .env from .env.example)
endif
ifeq ($(strip $(REGION)),)
  $(error REGION is not set. Create .env from .env.example)
endif
# Optional default if not provided
KEY_PREFIX ?= aws-ec2-keypair-rotation/states

# ==== Branch -> ENV mapping ====
BRANCH := $(shell git rev-parse --abbrev-ref HEAD)
ifeq ($(BRANCH),main)
  ENV := prod
else ifeq ($(BRANCH),develop)
  ENV := dev
else
  ENV := sandbox-$(subst /,-,$(BRANCH))
endif

# ==== Optional varfile ====
VARFILE := $(firstword $(wildcard envs/$(ENV).tfvars $(ENV).tfvars))

BACKEND_FLAGS = \
	-backend-config="bucket=$(BUCKET)" \
	-backend-config="key=$(KEY_PREFIX)/$(ENV)/terraform.tfstate" \
	-backend-config="region=$(REGION)" \
	-backend-config="dynamodb_table=$(DDB)" \
	-backend-config="encrypt=true"

TFVAR_ARGS = $(if $(VARFILE),-var-file=$(VARFILE),-var="env=$(ENV)")

.PHONY: help show-env fmt init init-migrate validate plan apply destroy output clean

help:
	@echo "Usage:"
	@echo "  make show-env | init | init-migrate | plan | apply | destroy"
	@echo "Detected: BRANCH=$(BRANCH)  ENV=$(ENV)  VARFILE=$(VARFILE)"

show-env:
	@echo "BRANCH  = $(BRANCH)"
	@echo "ENV     = $(ENV)"
	@echo "VARFILE = $(if $(VARFILE),$(VARFILE),<none>)"
	@echo "STATE   = s3://$(BUCKET)/$(KEY_PREFIX)/$(ENV)/terraform.tfstate"
	@echo "REGION  = $(REGION)"

fmt:
	terraform fmt -recursive

init:
	terraform init $(BACKEND_FLAGS)

# First migration from old backend path to $(KEY_PREFIX)/$(ENV)/
init-migrate:
	terraform init -reconfigure -migrate-state $(BACKEND_FLAGS)

validate: init
	terraform validate

plan: init
	terraform plan -input=false $(TFVAR_ARGS) -out=tfplan.$(ENV).bin

apply: init
	terraform apply -input=false -auto-approve $(TFVAR_ARGS)

destroy: init
	terraform destroy -input=false -auto-approve $(TFVAR_ARGS)

output:
	terraform output

clean:
	rm -f tfplan.*.bin || true
