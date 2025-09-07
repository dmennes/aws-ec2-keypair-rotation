# ==== Load local config (not committed) ====
-include .env
ifeq ($(strip $(BUCKET)),)
  $(error BUCKET is not set. Create .env from .env.example)
endif
ifeq ($(strip $(DDB)),)
  $(error DDB is not set. Create .env from .env.example)
endif
ifeq ($(strip $(REGION)),)
  $(error REGION is not set. Create .env from .env.example)
endif

# Optional: where to store states per workspace (S3 path prefix)
KEY_PREFIX ?= aws-ec2-keypair-rotation/states

# ==== Branch -> WORKSPACE mapping ====
BRANCH := $(shell git rev-parse --abbrev-ref HEAD)
ifeq ($(BRANCH),main)
  WORKSPACE := prod
else ifeq ($(BRANCH),develop)
  WORKSPACE := dev
else
  WORKSPACE := sandbox-$(subst /,-,$(BRANCH))
endif

# ==== Optional varfile lookup ====
# Looks for env/<workspace>/*.tfvars then <workspace>.tfvars
VARFILE := $(firstword $(wildcard env/$(WORKSPACE)/*.tfvars env/$(WORKSPACE)/*.tfvars.json $(WORKSPACE).tfvars $(WORKSPACE).tfvars.json))

# ==== Backend flags ====
# With workspaces, S3 backend uses:
#   s3://$(BUCKET)/$(KEY_PREFIX)/<workspace>/terraform.tfstate
BACKEND_FLAGS = \
	-backend-config="bucket=$(BUCKET)" \
	-backend-config="key=terraform.tfstate" \
	-backend-config="workspace_key_prefix=$(KEY_PREFIX)" \
	-backend-config="region=$(REGION)" \
	-backend-config="dynamodb_table=$(DDB)" \
	-backend-config="encrypt=true"

# ==== Common TF args ====
TFVAR_ARGS = $(if $(VARFILE),-var-file=$(VARFILE),-var="env=$(WORKSPACE)")

.PHONY: help show-env init init-reconfigure workspace validate fmt plan apply destroy output clean

help:
	@echo "Usage:"
	@echo "  make show-env         # print branch/workspace/state path/varfile"
	@echo "  make init             # terraform init (S3 backend + DynamoDB lock)"
	@echo "  make init-reconfigure # reconfigure backend (no state migration)"
	@echo "  make plan             # init + select workspace + plan"
	@echo "  make apply            # init + select workspace + apply"
	@echo "  make destroy          # init + select workspace + destroy"
	@echo ""
	@echo "Detected: BRANCH=$(BRANCH)  WORKSPACE=$(WORKSPACE)  VARFILE=$(VARFILE)"

show-env:
	@echo "BRANCH    = $(BRANCH)"
	@echo "WORKSPACE = $(WORKSPACE)"
	@echo "STATE     = s3://$(BUCKET)/$(KEY_PREFIX)/$(WORKSPACE)/terraform.tfstate"
	@echo "REGION    = $(REGION)"
	@echo "VARFILE   = $(if $(VARFILE),$(VARFILE),<none>)"

init:
	terraform init $(BACKEND_FLAGS)

init-reconfigure:
	terraform init -reconfigure $(BACKEND_FLAGS)

# Ensure workspace exists, then select it
workspace:
	@terraform workspace list >/dev/null 2>&1 || terraform init $(BACKEND_FLAGS)
	@if ! terraform workspace list | grep -qE '^\*?[[:space:]]*$(WORKSPACE)$$'; then \
		echo ">> Creating workspace: $(WORKSPACE)"; \
		terraform workspace new $(WORKSPACE); \
	else \
		echo ">> Selecting workspace: $(WORKSPACE)"; \
		terraform workspace select $(WORKSPACE); \
	fi

validate: init workspace
	terraform validate

fmt:
	terraform fmt -recursive

plan: init workspace
	terraform plan -input=false $(TFVAR_ARGS) -out=tfplan.$(WORKSPACE).bin

apply: init workspace
	terraform apply -input=false -auto-approve $(TFVAR_ARGS)

destroy: init workspace
	terraform destroy -input=false -auto-approve $(TFVAR_ARGS)

output:
	terraform output

clean:
	rm -f tfplan.*.bin || true
