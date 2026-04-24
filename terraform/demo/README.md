# Demo root (commercial AWS, deployable)

> **DEMO ENVIRONMENT — NOT A CUI ENCLAVE.** This stack runs in **commercial
> AWS** (not GovCloud), uses **non-FIPS endpoints**, and serves a public
> page anyone can hit. Do not upload, store, or process real CUI here. The
> CUI-grade configuration lives in [`terraform/govcloud/`](../govcloud/).

## Why this exists

The GovCloud root is unverifiable here (no GovCloud account). The demo root
proves the architecture *applies cleanly* by mirroring the GovCloud root's
shape in commercial AWS, then layering a tiny Lambda + Function URL that
serves the disclaimer page so reviewers can click a real URL.

## What it deploys

Same module set as `terraform/govcloud/`, with cost overrides:

| Module | Demo overrides |
|---|---|
| `vpc` | `enable_nat_gateway = false`, `az_count = 2` (relies on VPC endpoints) |
| `kms` | 2 keys (`logs`, `data`) instead of 3 |
| `iam_baseline` | `attach_deny_non_fips = false` (commercial doesn't have universal FIPS endpoints) |
| `cloudtrail` | `is_multi_region = false`, 7-day log retention, 1-year Object Lock |
| `guardduty` | `enable = false` by default (flip `enable_guardduty=true` to test) |
| `config` | *Not deployed in demo* (recorder is a per-region resource and adds noise; covered in GovCloud root) |

Plus a workload:

- `aws_lambda_function` (`python3.12`, 128 MB, 5s timeout) packaged from `lambda/index.py`.
- `aws_lambda_function_url` with `authorization_type = NONE` — the public demo URL.

## Deploy

Requires AWS credentials with admin or equivalent on a sandbox account.

```bash
cd terraform/demo
make demo-up      # interactive confirm; runs init + apply
# … prints the demo URL …

curl -sf "$(terraform output -raw demo_url)" | grep -q "NOT A CUI ENCLAVE" && echo OK

make demo-down    # interactive confirm; destroys everything
```

The deploy / nightly-destroy GitHub Actions workflow lands in prompt `09`.

## Cost

Order-of-magnitude estimate for an idle deploy (no NAT, no GuardDuty, no Config):

| Component | Estimated cost / day |
|---|---|
| 4 VPC interface endpoints × 2 AZ | ~$0.40 |
| CloudTrail (1st trail free) | $0 |
| KMS (2 CMKs, $1/mo each) | ~$0.07 |
| S3 (CloudTrail logs, near zero traffic) | ~$0.01 |
| Lambda + Function URL (a few invokes) | ~$0.00 |
| CloudWatch Logs (7-day retention) | ~$0.02 |
| **Idle total** | **~$0.50/day** |

With `enable_guardduty = true` add ~$1–3/day. With `enable_guardduty_extras = true` add another ~$2–5/day.

If the nightly-destroy workflow runs (prompt `09`), exposure caps at ~24h × $0.50 ≈ **~$15/month** worst case.

## Acceptance / verification

```bash
terraform fmt -recursive -check terraform/demo
terraform -chdir=terraform/demo init -backend=false -input=false
terraform -chdir=terraform/demo validate
```

The "NOT A CUI ENCLAVE" string appears in three places per the prompt-05 acceptance criteria:

1. The served page (`lambda/index.py` &rarr; banner + page text).
2. This README (multiple places).
3. Terraform `output "warning"` in [outputs.tf](outputs.tf).
