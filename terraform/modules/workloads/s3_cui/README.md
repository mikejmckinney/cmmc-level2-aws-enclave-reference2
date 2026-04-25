# `s3_cui` — CUI-bearing S3 bucket pattern

A reusable Terraform module for an S3 bucket that stores Controlled Unclassified
Information (CUI), with the controls a CMMC L2 assessor expects to see on a
data store: SSE-KMS at rest, deny-non-TLS in transit, public-access block,
S3-side access logging, lifecycle, and a tag-based policy that prevents
untagged objects from entering the bucket.

## Purpose

Workload teams reach for `aws_s3_bucket` directly and forget half the
guardrails. This module collapses the "right way to ship a CUI bucket" into
a single block, so a consumer can wire `module "data" { source = ".../s3_cui" }`
into their root, point a KMS key at it, and inherit the controls referenced
in the CMMC L2 family table below.

It is **not** a drop-in for arbitrary S3 use cases — see
[Production overrides](#production-overrides) and
[Gaps the consumer must fill](#gaps-the-consumer-must-fill).

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | — (required) | DNS-compliant lowercase prefix; account ID is appended. |
| `kms_key_arn` | `string` | — (required) | KMS CMK ARN for SSE-KMS on the CUI bucket. The access-log bucket is SSE-S3 (S3 access-log delivery does not support SSE-KMS). |
| `versioning_enabled` | `bool` | `true` | Versioning on the CUI bucket. Strongly recommended for CUI. |
| `transition_to_ia_days` | `number` | `30` | Days before transition to STANDARD_IA. `0` disables. |
| `expiration_days` | `number` | `2555` | Object expiration (~7 years matches a common CUI baseline). |
| `noncurrent_version_expiration_days` | `number` | `90` | Days before non-current versions are deleted. |
| `access_log_retention_days` | `number` | `365` | Retention for the access-log bucket. |
| `data_classification_tag` | `string` | `"cui"` | Value the bucket policy enforces on `s3:RequestObjectTag/data_classification`. |
| `tags` | `map(string)` | `{}` | Merged onto every resource. `data_classification` is auto-added. |

## Outputs

| Name | Description |
|---|---|
| `bucket_id` | Name of the CUI bucket. |
| `bucket_arn` | ARN of the CUI bucket. |
| `bucket_regional_domain_name` | Regional DNS for region-pinned clients / VPC endpoints. |
| `access_logs_bucket_id` | Name of the access-log bucket. |
| `access_logs_bucket_arn` | ARN of the access-log bucket. |
| `partition` | Resolved AWS partition (`aws` or `aws-us-gov`). |

## NIST 800-171 controls addressed

| Control | Coverage | How |
|---|---|---|
| 3.8.1 — Protect media containing CUI | full | SSE-KMS at rest + public-access block + deny-non-TLS bucket policy + classification tag enforcement on PutObject. |
| 3.8.2 — Limit access to media | full | KMS key policy gates decrypt; bucket policy denies untagged uploads and tag removal; public-access block forbids any anonymous/cross-account anonymous reach. |
| 3.8.6 — Cryptographic protection of CUI on transport media | full | `DenyInsecureTransport` policy denies any `s3:*` call where `aws:SecureTransport=false`; KMS key is FIPS-validated when the partition is `aws-us-gov`. |
| 3.8.9 — Protect backups (confidentiality) | full | Versioning enabled + SSE-KMS on object versions + non-current-version lifecycle. (Integrity / retention via Object Lock is an opt-in — see [Production overrides](#production-overrides).) |
| 3.13.11 — Cryptographic protection (already `full` in repo) | reinforced | Bucket cannot be read or written without KMS decrypt and TLS. |

The CSV ([`controls/nist-800-171-mapping.csv`](../../../controls/nist-800-171-mapping.csv))
and SSP ([`ssp/SSP.md`](../../../ssp/SSP.md)) are updated atomically with this
module landing — re-run `python3 scripts/gen-controls-csv.py` and
`python3 scripts/gen-ssp.py` after editing either generator.

## Partition parity

| Partition | Supported | Notes |
|---|---|---|
| `aws` | ✅ | Demo wiring uses this. |
| `aws-us-gov` | ✅ | GovCloud wiring uses this. KMS in this partition is FIPS-validated. |
| `aws-cn` / others | ❌ | A `precondition` on `aws_s3_bucket.cui` fails closed at `terraform validate`. |

The module never hardcodes `arn:aws:` strings; all ARN constructions use
`data.aws_partition.current.partition` and the resolved bucket ARN.

## Demo cost

Demo wiring (in [`terraform/demo/main.tf`](../../../terraform/demo/main.tf))
sizes for ~$0/mo at idle:

- 0 GB stored at idle (~$0.00 storage)
- 0 GET/PUT requests at idle (~$0.00 requests)
- KMS data-key cache hits via `bucket_key_enabled = true` (negligible)
- Access-log bucket carries the same idle profile

If a consumer puts test data in the demo bucket, expect ~$0.023/GB-month
(STANDARD) and ~$0.0125/GB-month (STANDARD_IA after 30 days) per AWS
public pricing. The demo overrides `expiration_days` to 30 so test data
does not accumulate; the [`demo-destroy.yml`](../../../.github/workflows/demo-destroy.yml)
workflow tears the buckets down nightly. No `var.enable_s3_cui_demo`
opt-out flag is wired because the steady-state cost is below the
[ADR-011](../../../docs/decisions/adr-011-phase-8-workload-module-scope.md)
§4 demo-cost ceiling.

## Production overrides

The module ships **safe defaults**, not **production defaults**. A consumer
deploying real CUI should layer the following on top:

- **Object Lock (compliance or governance mode)**: not enabled by default
  because v1 targets active-data CUI buckets where consumers may legitimately
  delete. For archive-only / WORM use cases, enable Object Lock at bucket
  creation (cannot be added later) and pass a retention period; lifecycle
  expiration must be longer than the lock retention or apply will fail.
- **Cross-region replication (CRR)**: not in v1. Add `aws_s3_bucket_replication_configuration`
  in the consumer root and grant the replication role the necessary KMS
  decrypt permissions on the source key + encrypt on the destination key.
- **MFA Delete**: requires the bucket-owning root account credentials at
  enable time and cannot be set via Terraform alone — apply via AWS CLI
  after `terraform apply`.
- **AWS Backup integration**: layer `aws_backup_plan` + `aws_backup_selection`
  in the consumer root referring to `module.s3_cui.bucket_arn`.
- **`force_destroy = true` for ephemeral environments only**: never set this
  on production buckets. The default is `false` so a stray `terraform destroy`
  in a CUI environment fails loud rather than wiping data.
- **Notification-driven scanning** (Macie, antivirus): wire `aws_s3_bucket_notification`
  to SNS / SQS / Lambda in the consumer root.

## Gaps the consumer must fill

1. **Application-layer access control**: this module enforces TLS, KMS, and
   classification tags at the bucket boundary. The IAM identities and
   workload roles that actually call `s3:GetObject` / `s3:PutObject` are
   the consumer's responsibility.
2. **Tagging enforcement at upload time**: the bucket policy denies
   `PutObject` lacking `data_classification = <tag>` — but the *application*
   uploading the object must set `x-amz-tagging: data_classification=cui`
   (or the equivalent SDK tag set). This is documented for the workload
   developer; it is not enforced server-side beyond the policy.
3. **CUI Macie rules / DLP**: explicitly out of scope for v1
   ([ADR-011](../../../docs/decisions/adr-011-phase-8-workload-module-scope.md) §1).
4. **Audit logging coverage on object operations**: the [`cloudtrail`](../../cloudtrail/)
   module wired in [`terraform/govcloud/main.tf`](../../../terraform/govcloud/main.tf)
   records S3 data events partition-wide via `data_event_resources`. If the
   consumer disables that, S3 data-plane operations on this bucket will not
   appear in CloudTrail and the AU controls degrade.
5. **CRR / replication**: see [Production overrides](#production-overrides).

## Example

```hcl
module "data" {
  source = "../modules/workloads/s3_cui"

  name        = "myorg-prod"
  kms_key_arn = module.kms.key_arns["data"]

  expiration_days = 2555
  tags = {
    Environment = "prod"
    Owner       = "data-platform"
  }
}
```
