# Terraform modules

Six partition-aware modules consumed by both `terraform/govcloud/` and
`terraform/demo/`. Each module:

- Pins `terraform >= 1.6` and `hashicorp/aws >= 5.40` in `versions.tf`
- Constructs ARNs via `data.aws_partition.current.partition` (no
  hardcoded `arn:aws:` strings)
- Documents the NIST SP 800-171 r2 controls it helps satisfy in its README

Authored in [`.github/prompts/03-terraform-shared-modules.md`](../../.github/prompts/03-terraform-shared-modules.md).

| Module | Purpose |
|---|---|
| [`vpc/`](vpc/) | 3-tier VPC (public / private / data) with VPC endpoints and flow logs |
| [`iam_baseline/`](iam_baseline/) | IAM password policy, Access Analyzer, optional `DenyNonFipsEndpoints` policy |
| [`kms/`](kms/) | One CMK per declared data class with rotation enabled |
| [`cloudtrail/`](cloudtrail/) | Multi-region trail, log-file validation, KMS-encrypted Object-Locked S3 bucket |
| [`guardduty/`](guardduty/) | Detector with toggleable EKS / malware / S3 / RDS protection features |
| [`config/`](config/) | AWS Config recorder + delivery channel, conformance-pack ready |
