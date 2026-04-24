# 03 — Terraform shared modules

> Build the six partition-aware modules consumed by both the GovCloud root
> (prompt 04) and the commercial demo root (prompt 05).

## Context

CMMC Level 2 enclaves need: network isolation, identity baseline, encryption,
audit logging, threat detection, and configuration tracking. These six modules
cover the AWS-native pieces. Modules are **partition-aware** so the same code
deploys to `aws` (commercial) and `aws-us-gov` (GovCloud) without forking.

## Prerequisites

- `02-scaffold-and-architecture.md` complete (`terraform/modules/*/` dirs exist).

## Deliverables

For each module under `terraform/modules/<name>/`:

- `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`, `README.md`
- `versions.tf` pins `terraform >= 1.6` and `hashicorp/aws >= 5.40`
- A `data "aws_partition" "current" {}` lookup; ARNs constructed via
  `data.aws_partition.current.partition` (no hardcoded `arn:aws:` strings)
- A `var.partition` validation that errors clearly if mismatched
- README documents: purpose, inputs, outputs, NIST 800-171 controls
  partially or fully addressed, gaps the consumer must fill

### Module specs

#### `vpc/`
- 3-tier subnet layout (public, private, data) across `var.az_count` AZs (default 2)
- Configurable `var.enable_nat_gateway` (default `true`; the demo will
  override to `false`)
- Interface VPC endpoints: `ssm`, `ssmmessages`, `ec2messages`, `kms`,
  `logs`, `sts`, `ec2`, `monitoring`
- Gateway endpoints: `s3`, `dynamodb`
- VPC Flow Logs → CloudWatch Logs, retention `var.flow_log_retention_days`
  (default 365)

#### `iam_baseline/`
- IAM password policy (length ≥ 14, symbols/numbers/upper/lower required,
  90-day rotation, 24-history)
- Account-level `aws_iam_account_password_policy`
- `AWSServiceRoleForSupport` and access-analyzer enablement
- Customer-managed policy `DenyNonFipsEndpoints` for use in permission
  boundaries (GovCloud root attaches; demo root does not)
- IAM Access Analyzer (account-level)

#### `kms/`
- One CMK per logical data class via `var.keys = { logs = {...}, data = {...}, ... }`
- Key rotation enabled (annual)
- Default key policy: root account admin, configurable principal list for
  use, deny `kms:Decrypt` outside the partition

#### `cloudtrail/`
- Multi-region trail (where the root enables it), log-file validation
  enabled, KMS-encrypted, Object Lock-enabled S3 bucket (governance
  mode, 7-year retention default)
- Management events only in the v1 module. **S3 + Lambda data events
  are tracked as a follow-up** (see issue #3 / postmortem-001 — the
  recovery PR scoped them out)
- CloudWatch Logs integration with metric filters for: root login, IAM
  policy change, console without MFA, KMS key disable

#### `guardduty/`
- Detector enabled with EKS audit logs, malware protection, S3 protection,
  RDS protection (toggleable via `var.features` map for cost control)
- Findings remain in GuardDuty (no S3 export wired in v1; the
  publishing-destination resource is a follow-up if/when an S3 bucket
  for findings is provisioned)

#### `config/`
- AWS Config recorder (all resources + global)
- Delivery channel → S3 (KMS-encrypted)
- Conformance pack reference: `Operational-Best-Practices-for-NIST-800-171.yaml`
  — attach via `aws_config_conformance_pack` data lookup; document in README
  if the pack file must be supplied separately

## Acceptance criteria

- `terraform fmt -recursive -check terraform/modules/` exits 0.
- `terraform -chdir=terraform/modules/<name> init -backend=false && \
   terraform -chdir=terraform/modules/<name> validate` passes for each module.
- `tflint --recursive` (with `tflint-ruleset-aws`) reports no errors.
- Every module README lists at least three NIST 800-171 control IDs it
  helps satisfy (consistent with the CSV that ships in prompt `06`).
- No string contains the literal `arn:aws:` outside test fixtures.

## Verification

```bash
terraform fmt -recursive -check terraform/modules/
for m in terraform/modules/*/; do
  terraform -chdir="$m" init -backend=false -input=false
  terraform -chdir="$m" validate
done
tflint --recursive --chdir=terraform/modules
grep -RE "arn:aws:" terraform/modules/ && exit 1 || echo "no hardcoded ARN partitions"
```

## Do NOT

- Do NOT consume these modules from a root yet — that's `04` and `05`.
- Do NOT pin to provider versions older than 5.40 (FIPS endpoint args
  matter in GovCloud).
- Do NOT use `count` for partition switches; use `data.aws_partition.current`.
- Do NOT bake account IDs, bucket names, or region names into module defaults.

## Truth-hierarchy updates

- Each module README is the canonical doc for that module.
- `AI_REPO_GUIDE.md` → "Terraform modules" section listing the six modules
  and where each is consumed.
