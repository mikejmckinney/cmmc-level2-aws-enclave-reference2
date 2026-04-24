# 04 — Terraform GovCloud root

> Wires the shared modules into a `us-gov-west-1` reference deployment
> targeting CMMC L2 / NIST SP 800-171 r2. **Validate-clean only — not
> applied** in this repo (no GovCloud account available here).

## Context

This root is the "reference" half of the project: the configuration a client
or MSP would lift, customize, and deploy in their own GovCloud account. It
must be obviously CUI-grade (FIPS endpoints, restrictive KMS policies,
minimal egress) and clearly mark every place where client-specific work is
required.

## Prerequisites

- `03-terraform-shared-modules.md` complete.

## Deliverables

Under `terraform/govcloud/`:

- [ ] `versions.tf` — pin terraform `>= 1.6`, aws `>= 5.40`
- [ ] `providers.tf`:
  - `provider "aws"` with `region = "us-gov-west-1"`,
    `use_fips_endpoint = true`, `default_tags` block (Environment,
    DataClassification = "CUI", Owner, Compliance = "CMMC-L2")
- [ ] `backend.tf.example` — S3 backend stub (KMS-encrypted, DynamoDB
      lock table); commit as `.example` so consumers must opt in
- [ ] `main.tf` — instantiates each module from `../modules/<name>`:
  - `vpc` with `enable_nat_gateway = true`, `az_count = 3`, flow logs
    365-day retention
  - `kms` with at least three keys: `logs`, `data`, `config`
  - `iam_baseline` with `attach_deny_non_fips = true`
  - `cloudtrail` with org-trail mode disabled by default but documented
  - `guardduty` with all features on
  - `config` with conformance pack reference
- [ ] `variables.tf` — every input the consumer must supply (account ID,
      org ID, log archive bucket prefix, allowed admin principal ARNs)
      with **no defaults** so `terraform plan` fails fast if missing
- [ ] `outputs.tf` — VPC ID, subnet IDs by tier, KMS key ARNs (for the
      consumer to wire workloads into)
- [ ] `terraform.tfvars.example` — concrete-looking but obviously fake values
- [ ] `README.md` documenting:
  - "What this deploys" (1-paragraph + link to `diagrams/network.md`)
  - **"What you must supply"** — explicit list of client-fill gaps
    (org-trail bucket, IAM Identity Center, route tables to TGW/DX,
    workload modules, log retention beyond defaults, IR runbooks, ...)
  - **"What this does NOT do"** — does not deploy workloads, does not
    configure SIEM forwarding, does not implement organizational
    controls (training, policies, IR plans), does not create the
    GovCloud account itself
  - Step-by-step deploy instructions (`aws sso login` → `terraform init`
    → `plan` → `apply`)
  - Cost estimate range with assumptions

## Acceptance criteria

- `terraform -chdir=terraform/govcloud init -backend=false && \
   terraform -chdir=terraform/govcloud validate` passes
- `tflint --chdir=terraform/govcloud` reports no errors
- `checkov -d terraform/govcloud --framework terraform --soft-fail` runs
  cleanly (soft-fail because some checks intentionally don't apply to a
  reference scaffold; document each skip in the README)
- README "What you must supply" section lists at least 6 explicit gaps
- No `terraform apply` is performed; CI does not require GovCloud creds

## Verification

```bash
terraform fmt -recursive -check terraform/govcloud
terraform -chdir=terraform/govcloud init -backend=false -input=false
terraform -chdir=terraform/govcloud validate
tflint --chdir=terraform/govcloud
checkov -d terraform/govcloud --framework terraform --soft-fail --quiet
```

## Do NOT

- Do NOT include real account IDs, ARNs, or bucket names anywhere.
- Do NOT commit a working `backend.tf` — only `backend.tf.example`.
- Do NOT add a deploy GitHub Actions workflow for this root (the demo
  root in prompt `09` gets the only deploy workflow).
- Do NOT silently work around `checkov` findings — either fix them or
  document the skip with rationale.

## Truth-hierarchy updates

- `terraform/govcloud/README.md` is canonical for this stack.
- `AI_REPO_GUIDE.md` → note that the GovCloud root is validate-only in CI.
- `controls/nist-800-171-mapping.csv` (prompt `06`) → mark `addressed_by_repo`
  for controls this root configures.
