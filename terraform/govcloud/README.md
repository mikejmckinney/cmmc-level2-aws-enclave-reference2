# GovCloud reference root

> **Status:** Validate-only in this repo. We do not have a GovCloud account
> to apply against. The configuration is written to the same standard as if
> it were apply-tested, but treat it as a starting point — review every
> module input against your organization's IPAM, IAM, and audit conventions
> before applying.

## What this deploys

A single-account CUI enclave foundation in `us-gov-west-1`:

- 3-AZ VPC (public / private / data tiers) with VPC endpoints for SSM, KMS, Logs, Monitoring, STS, EC2, plus S3/DynamoDB Gateway endpoints.
- Per-AZ NAT Gateways, VPC Flow Logs to KMS-encrypted CloudWatch Logs.
- 3 KMS CMKs (`logs`, `data`, `config`) with annual rotation and a `DenyOutsidePartition` guardrail in the key policy.
- IAM baseline: 14-character password policy, IAM Access Analyzer, **DenyNonFipsEndpoints** managed policy ready for SCP / permission boundary attachment.
- Multi-region CloudTrail → KMS-encrypted, Object-Locked S3 + KMS-encrypted CloudWatch Logs + 4 metric filters (root login, IAM policy change, console-without-MFA, KMS key disable).
- GuardDuty detector with all features enabled.
- AWS Config recorder + delivery channel; optional NIST 800-171 conformance pack via `var.config_conformance_pack_template_body`.

Diagram: [diagrams/network.md](../../diagrams/network.md).

## What you must supply

This root deliberately ships **no defaults** for any input. You must supply, at minimum:

1. **`region`** — only `us-gov-west-1` has been validated against this repo's assumptions.
2. **`vpc_cidr`** — coordinate with your IPAM. Must not overlap with TGW / DX peers.
3. **`kms_admin_principal_arns`** — your break-glass admin role(s). Without this, only the account root can administer the CMKs.
4. **`trail_name`** — a unique trail name; CloudTrail names are account-global.
5. **`log_retention_days`** and **`object_lock_retention_years`** — match your organization's retention policy. CUI baselines typically expect 365d / 7y.
6. **A populated `backend.tf`** — copy `backend.tf.example`, fill in your remote-state bucket / KMS / lock table. Do **not** commit the populated file.
7. **An NIST 800-171 conformance pack** — download `Operational-Best-Practices-for-NIST-800-171.yaml` from [`awslabs/aws-config-rules`](https://github.com/awslabs/aws-config-rules/tree/master/aws-config-conformance-packs) (Apache-2.0) and pass via `file(...)`.
8. **Workload modules** — this root creates the platform; you bring the EC2 / RDS / ECS workloads, wired into `module.vpc.private_subnet_ids` and the `data` CMK.
9. **Routing to TGW / Direct Connect** — add `aws_route` resources in your workload root if the enclave must reach on-prem.
10. **IAM Identity Center / SSO config** — out of scope for this root; configure separately in your management account.

## What this does NOT do

- Does **not** create the GovCloud account itself (that's an `aws organizations create-account` call from the commercial linked account).
- Does **not** deploy any workload (no EC2, no RDS, no ECS).
- Does **not** configure SIEM forwarding (no Kinesis / OpenSearch / Splunk integration).
- Does **not** address organizational controls (training, IR plans, written policies, personnel screening).
- Does **not** wire the `DenyNonFipsEndpoints` policy into an SCP — attach via Organizations / Control Tower in your management account.
- Does **not** provision a remote-state backend for itself — bootstrap that in a separate stack.

## Deploy

```bash
cd terraform/govcloud
cp backend.tf.example backend.tf            # then edit
cp terraform.tfvars.example terraform.tfvars # then edit

aws sso login --profile govcloud-prod
export AWS_PROFILE=govcloud-prod

terraform init
terraform plan -out tfplan
terraform apply tfplan
```

## Cost estimate

Rough monthly steady-state for an idle enclave (no workloads):

| Component | Estimate (USD) | Notes |
|---|---|---|
| 3 NAT Gateways | ~$100 | $0.045/hr × 3 AZs × 730h |
| VPC Flow Logs (CW Logs) | ~$5–25 | Depends on traffic volume |
| 8 Interface VPC endpoints | ~$50 | $0.01/hr × 8 × 3 AZs × 730h |
| CloudTrail mgmt events | $0 | First trail is free |
| GuardDuty (all features) | ~$30–100 | Idle account; scales with events |
| AWS Config | ~$10–40 | $0.003/configuration item recorded |
| KMS (3 CMKs + requests) | ~$3 | $1/key/mo + per-request |
| **Total (idle)** | **~$200–320/mo** | Add workloads on top |

Production traffic (real CUI workloads) commonly puts this in the $1,000–$3,000/mo range before workload compute.

## Acceptance / verification

```bash
terraform fmt -recursive -check terraform/govcloud
terraform -chdir=terraform/govcloud init -backend=false -input=false
terraform -chdir=terraform/govcloud validate
tflint --chdir=terraform/govcloud           # optional, requires tflint
checkov -d terraform/govcloud --framework terraform --soft-fail --quiet  # optional
```

`tflint` and `checkov` are exercised by the compliance-checks workflow (prompt `10`). Soft-fail is intentional for the reference root because some Checkov rules don't apply to a no-workload scaffold (e.g. WAF, ALB logging) — see the workflow output for documented skips.
