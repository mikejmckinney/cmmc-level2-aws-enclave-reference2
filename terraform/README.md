# Terraform

Two parallel root configurations consume one set of partition-aware modules.

| Path | Purpose | Deployable here? |
|---|---|---|
| [`modules/`](modules/) | Six shared partition-aware modules: `vpc`, `iam_baseline`, `kms`, `cloudtrail`, `guardduty`, `config`. Authored in prompt 03. | n/a |
| [`govcloud/`](govcloud/) | Reference root for AWS GovCloud (`us-gov-west-1`) with FIPS endpoints + CUI-grade KMS policies. **Validate-only** — not applied here. Authored in prompt 04. | no (no GovCloud account) |
| [`demo/`](demo/) | Commercial-AWS deployable demo (`us-east-1`), cost-optimized, with a small disclaimer-page workload. Authored in prompt 05. | yes |

Both roots use the same module sources via `source = "../modules/<name>"`
and switch behavior via `var.partition`-aware `data.aws_partition.current`
lookups inside the modules.

See [`../diagrams/network.md`](../diagrams/network.md) for the network
topology these roots realize.
