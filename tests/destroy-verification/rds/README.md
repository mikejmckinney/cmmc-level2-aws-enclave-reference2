# Destroy-verification — RDS

Throwaway Terraform scaffold used by [`.github/workflows/verify-destroy-rds.yml`](../../../.github/workflows/verify-destroy-rds.yml) to prove that `terraform destroy` (the same invocation pattern used by [`demo-destroy.yml`](../../../.github/workflows/demo-destroy.yml)) cleans up a stateful RDS-Postgres instance end-to-end.

This satisfies the gating requirement in [ADR-011](../../../docs/decisions/adr-011-phase-8-workload-module-scope.md) §2 / issue #15 — the Phase 8 `rds_cui` workload module (issue #19) cannot ship until the verification workflow has run green at least once.

## Why this lives outside `terraform/demo/`

Three reasons:

1. The nightly `demo-destroy` schedule must not provision an RDS instance every day; that would burn ~$13/mo (ADR-011 §4 demo-cost ceiling).
2. The verification stack is run on demand only — `workflow_dispatch` with a `VERIFY` confirmation token — so it must not appear in the demo cost accounting.
3. Tearing this stack down does not depend on the demo state bucket, so a destroy verification can run safely while the demo stack itself is in any state.

## What the workflow does

1. `terraform init -backend=false` (no remote state — sandbox stack only).
2. `terraform apply -auto-approve` provisions a `db.t4g.micro` Postgres in a throwaway VPC tagged `Project=cmmc-enclave-destroy-verify`.
3. `aws rds describe-db-instances` records the provisioned instance ID.
4. `terraform destroy -auto-approve`.
5. `aws rds wait db-instance-deleted` then re-`describe-db-instances`; fails if any instance with the verify tag remains.

## Failure modes the scaffold deliberately exercises

| Knob | Setting | Why |
|---|---|---|
| `deletion_protection` | `false` | Default is `false`; setting it `true` would block destroy. The `rds_cui` module will set it `true` and override at destroy time — verifying with `false` here keeps this scaffold simple. |
| `skip_final_snapshot` | `true` | Without this, destroy requires a `final_snapshot_identifier` and fails. Documenting the requirement here so `rds_cui` callers know to pass `skip_final_snapshot = true` (or supply a snapshot name) at teardown. |
| `backup_retention_period` | `0` | Disables automated backups; otherwise destroy can leave automated snapshots (which incur cost) behind. |
| KMS | Default RDS-managed key (storage_encrypted = true) | Avoids orphaning a CMK on destroy. The `rds_cui` module uses an explicit CMK and must verify destroy disposition separately. |

## Local verification

```bash
cd tests/destroy-verification/rds
terraform init -backend=false
terraform validate
# do NOT `terraform apply` locally without an AWS sandbox account; it costs ~$0.02/hour while running
```

## Out of scope

- Production-shaped RDS configuration (encryption with explicit CMK, IAM auth, audit logging, multi-AZ, deletion protection on, automated backups). All of that is the `rds_cui` module's job.
- Cleanup verification for any resource other than RDS. File a separate issue if needed (e.g., for stateful S3 with object lock).
