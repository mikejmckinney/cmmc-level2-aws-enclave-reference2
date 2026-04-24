# 05 — Terraform demo root (commercial AWS, deployable)

> The "click to see it live" half of the project. Mirrors the GovCloud
> reference's *shape* in commercial AWS so prospects can poke at a real
> environment. **Must be deployable end-to-end** by a developer with a
> commercial AWS account.

## Context

The GovCloud root (prompt `04`) is unverifiable here (no GovCloud account).
The demo root proves the architecture works by actually applying it in a
commercial account, while being honest that it is **not** a CUI environment.
Cost-optimized to keep nightly demos cheap.

## Prerequisites

- `03-terraform-shared-modules.md` complete.
- `04-terraform-govcloud-root.md` complete (for shape parity).

## Deliverables

Under `terraform/demo/`:

- [ ] `versions.tf` — same pins as GovCloud root
- [ ] `providers.tf` — `region = "us-east-1"`, `default_tags` includes
      `Environment = "demo"`, `DataClassification = "synthetic"`,
      `AutoDestroy = "true"`
- [ ] `backend.tf.example` — S3 backend stub for the demo state
- [ ] `main.tf` — same modules as GovCloud root with **cost overrides**:
  - `vpc` with `enable_nat_gateway = false`, `az_count = 2` (single NAT
    is still pricey; rely on VPC endpoints + SSM)
  - `kms` with two keys (`logs`, `data`)
  - `iam_baseline` with `attach_deny_non_fips = false` (commercial doesn't
    have universal FIPS endpoints)
  - `cloudtrail` single-region trail to keep S3 storage minimal
  - `guardduty` with optional features off by default (`var.enable_guardduty_extras = false`)
  - `config` with the conformance pack reference but recorder set to
    `recording_group.all_supported = false` and a small named resource
    list to bound cost
- [ ] A small **demo workload** that makes the live URL meaningful:
  - One ALB + one Fargate task (or Lambda + API Gateway — whichever is
    cheaper) serving a static "CMMC L2 Enclave Demo" page
  - The page banner reads: **"DEMO ENVIRONMENT — NOT A CUI ENCLAVE.
    Do not upload real CUI."**
  - Page links back to the repo, the diagram, and the SSP skeleton
- [ ] `variables.tf` with safe defaults so `terraform apply` works with
      zero overrides on a fresh account
- [ ] `outputs.tf` exposing the public demo URL
- [ ] `README.md` covering:
  - One-command deploy (`make demo-up` or equivalent)
  - One-command teardown (`make demo-down`)
  - Estimated cost per day with `AutoDestroy` enabled vs. disabled
  - Loud "this is not CUI-compliant" disclaimer
- [ ] `Makefile` (or `scripts/demo-deploy.sh` / `demo-destroy.sh`) wrapping
      `init`/`apply`/`destroy` with confirmation prompts

## Acceptance criteria

- `terraform -chdir=terraform/demo init -backend=false && terraform -chdir=terraform/demo validate` passes
- `terraform -chdir=terraform/demo plan` produces a coherent plan against a
  real (or mocked-via-localstack) account
- `terraform apply` creates the workload and the output URL returns HTTP
  200 with the demo banner
- `terraform destroy` removes everything; no orphaned resources flagged
  by `aws-nuke --dry-run` (or a documented manual check list)
- README has a "Cost" section with a concrete dollar/day figure
- The string "NOT A CUI ENCLAVE" appears in: the served page, the README,
  and a Terraform `output "warning"`

## Verification

```bash
terraform fmt -recursive -check terraform/demo
terraform -chdir=terraform/demo init -backend=false -input=false
terraform -chdir=terraform/demo validate
tflint --chdir=terraform/demo
checkov -d terraform/demo --framework terraform --soft-fail --quiet

# Live test (requires AWS creds):
make demo-up
curl -sf "$(terraform -chdir=terraform/demo output -raw demo_url)" | grep -q "NOT A CUI ENCLAVE"
make demo-down
```

## Do NOT

- Do NOT use long-lived AWS access keys; the deploy workflow (prompt `09`)
  uses OIDC.
- Do NOT seed the demo bucket / DB with anything resembling real CUI;
  synthetic strings only.
- Do NOT enable expensive features by default (Security Hub, Macie,
  Detective, full GuardDuty extras).
- Do NOT diverge module *interfaces* from the GovCloud root — only flip
  variables. If you need to change a module signature, update prompt `03`'s
  module and re-validate `04`.

## Truth-hierarchy updates

- `terraform/demo/README.md` canonical for the demo stack.
- `AI_REPO_GUIDE.md` → "Live demo" section pointing here and to the deploy
  workflow added in prompt `09`.
- `docs/demo-deploy.md` (created in `09`) cross-links to this README.
