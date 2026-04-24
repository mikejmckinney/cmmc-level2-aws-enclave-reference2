# cloudtrail

Multi-region CloudTrail with KMS-encrypted S3 (Object Lock governance) and CloudWatch Logs metric filters for high-signal events.

## What it creates

- `aws_cloudtrail` — multi-region, log file validation, KMS-encrypted, all management events.
- `aws_s3_bucket` for log delivery — versioned, public-access blocked, SSE-KMS via `var.kms_key_arn`, **Object Lock GOVERNANCE mode** with default retention (`object_lock_retention_years`, default 7y), bucket policy denies non-TLS traffic.
- `aws_cloudwatch_log_group` — KMS-encrypted, configurable retention (default 365d).
- IAM role + policy for CloudTrail → CloudWatch Logs delivery.
- 4 metric filters: `RootAccountUsage`, `IAMPolicyChange`, `ConsoleSignInWithoutMFA`, `KMSKeyDisableOrDelete` (namespace `CMMC/CloudTrail`).

## Controls satisfied (NIST SP 800-171 r2)

| Control | How |
|---|---|
| 3.3.1 | All management events captured to immutable S3 + indexed CloudWatch Logs. |
| 3.3.2 | User actions traceable via `userIdentity` in trail records (multi-region, all read/write). |
| 3.3.8 | Object Lock governance + KMS encryption + bucket policy deny-non-TLS protect audit data from unauthorized modification. |

Alarms (SNS subscribers) on the metric filters are wired in `terraform/govcloud/`, not in this module — keep the module composable.

## Variables

See `variables.tf`. Required: `name`, `kms_key_arn`. Common knobs: `log_retention_days`, `object_lock_retention_years`, `is_multi_region`.

## Outputs

`trail_arn`, `trail_name`, `log_bucket_name`, `log_bucket_arn`, `log_group_name`, `log_group_arn`, `metric_filter_names`, `partition`.
