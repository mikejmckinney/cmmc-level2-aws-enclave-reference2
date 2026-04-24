.PHONY: demo-up demo-down demo-plan demo-validate demo-fmt

TF := terraform -chdir=$(CURDIR)

demo-fmt:
	terraform fmt -recursive .

demo-validate:
	$(TF) init -backend=false -input=false
	$(TF) validate

demo-plan:
	$(TF) init -input=false
	$(TF) plan -out tfplan

demo-up:
	@echo "About to deploy the cmmc-demo workload to commercial AWS account $$(aws sts get-caller-identity --query Account --output text)."
	@echo "This will incur small charges (~\$$0.50/day) until you run 'make demo-down'."
	@read -p "Continue? [y/N] " ans && [ "$$ans" = "y" ] || exit 1
	$(TF) init -input=false
	$(TF) apply -auto-approve
	@echo ""
	@echo "Demo URL: $$($(TF) output -raw demo_url)"

demo-down:
	@echo "About to DESTROY all cmmc-demo resources in account $$(aws sts get-caller-identity --query Account --output text)."
	@read -p "Continue? [y/N] " ans && [ "$$ans" = "y" ] || exit 1
	$(TF) destroy -auto-approve
