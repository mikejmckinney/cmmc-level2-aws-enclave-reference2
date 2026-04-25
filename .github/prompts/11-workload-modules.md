# 11 — Workload modules (per-module implementation template)

> **Phase 8** — workload module library. This prompt is invoked **once
> per workload module**, not once per phase. ADR-011 decides the
> cross-cutting questions (which modules, in what order, with what
> partition/cost policy); this prompt decides only the per-module
> implementation shape.

## Context

Phases 1–7 shipped the enclave plumbing (VPC, IAM, KMS, CloudTrail,
GuardDuty, Config, demo Lambda). Phase 8 layers CUI-workload-shaped
patterns on top, the kinds MSPs and DIBs would copy/paste into their
own infrastructure.

[ADR-011](../../docs/decisions/adr-011-phase-8-workload-module-scope.md)
commits Phase 8 to four modules under `terraform/modules/workloads/`,
with this sequencing:

1. `s3_cui` — CUI bucket pattern
2. `secrets` — Secrets Manager / SSM parameter pattern
3. `alarms` — opinionated CloudWatch alarm set
4. `rds_cui` — RDS-Postgres for CUI (gated on a separate
   destroy-workflow verification PR; do not start without that PR
   merged)

This file is the implementation prompt for *one* of those modules at a
time. The issue assigning the work names which module.

## Prerequisites

- Read [ADR-011](../../docs/decisions/adr-011-phase-8-workload-module-scope.md)
  end-to-end before starting. It is the source of truth for scope,
  GovCloud-degradation policy, and demo-cost policy. This prompt does
  not restate those decisions — it enforces them via the acceptance
  criteria.
- Phase 3 modules under `terraform/modules/` exist and pass
  `terraform validate` (already true on `main`).
- Phase 4 roots (`terraform/govcloud/`, `terraform/demo/`) wire the
  Phase 3 modules and pass `terraform validate` (already true on
  `main`).
- For `rds_cui` only: the destroy-workflow verification PR
  (chore: verify demo-destroy.yml destroys RDS instances) has merged.
  If it has not, **stop and surface the dependency** rather than
  shipping without it.
- AGENTS.md *Analyst pre-flight gate*: this prompt is `NN-prefixed`,
  so the gate applies. Do not start implementation until the
  Pre-Flight Report on the assigned issue has verdict **PASS**.

## Deliverables

Per ADR-011 §5, every workload-module PR delivers:

### Module files (`terraform/modules/workloads/<name>/`)

- `main.tf` — resources, with `data.aws_partition.current` lookup; no
  hardcoded `arn:aws:` strings. Partition-conditional features fail
  closed at `terraform validate` time via `precondition` blocks on the
  affected resource / output / `check` block (per ADR-011 §3 —
  variables can’t host `precondition`, only `validation`)
- `variables.tf` — input variables; every var has `description` and
  (where applicable) a `validation` block. Variable-shaped invariants
  (“must be a /16 CIDR”, “must match a known partition string”) live
  here; cross-resource or partition-conditional invariants live on
  `precondition` blocks in `main.tf` / `outputs.tf` / `check` blocks
- `outputs.tf` — minimum surface needed for the demo + govcloud roots
  to consume the module; downstream consumers documented in README
  "Outputs" section
- `versions.tf` — pins matching Phase 3 modules (terraform >= 1.6,
  hashicorp/aws >= 5.40)
- `README.md` — exact section list below

### `README.md` section list (in this order)

1. **Purpose** — one paragraph, what the module is and is not
2. **Inputs** — variable name, type, default, description (table)
3. **Outputs** — output name, type, description (table)
4. **NIST 800-171 controls addressed** — bullet list of control IDs
   the module *fully or partially* implements, with one sentence each
   citing how
5. **Partition parity** — per ADR-011 §3: which AWS features the
   module uses, which partitions support each, and what the
   `precondition` failure mode is when a feature is missing
6. **Demo cost** — per ADR-011 §4: line-item monthly cost breakdown
   (compute / storage / network / data transfer) at the documented
   sizing
7. **Production overrides** — what variables a real production caller
   would override, and to what values, with rationale
8. **Gaps the consumer must fill** — what this module deliberately
   does not handle (e.g., DNS records, application-level secret
   rotation, cross-account replication policies)

### Demo + govcloud wiring

- `terraform/govcloud/main.tf` — instantiate the module with
  GovCloud-appropriate inputs; **validate-only**, never applied
- `terraform/demo/main.tf` — instantiate the module with the
  cheapest-viable sizing per ADR-011 §4; if the steady-state demo
  cost exceeds $15/mo, gate the wiring behind a
  `var.enable_<module>_demo` input that defaults to `false` and
  document this in the demo README
- `.github/workflows/demo-destroy.yml` — verified (manually or via a
  CI assertion) to remove every resource the module created. State
  the verification method in the PR description

### Compliance artifact updates

- `controls/nist-800-171-mapping.csv` — at least one row moves
  `addressed_by_repo` from `none` to `partial` or `full`, and/or flips
  `requires_client_config` from `true` to `false` (per the enum values
  defined in `controls/schema.json`) as a result of this module
  shipping. The CSV columns to update for each affected row:
  `addressed_by_repo`, `aws_services`, `terraform_resources`,
  `requires_client_config`. If no row qualifies, this is a signal that
  the module isn’t actually earning its keep — escalate, don’t fudge.
- `ssp/SSP.md` — for every newly-covered control, replace the `TODO`
  status with a written control statement following the format used
  by Phase 3 controls. The CSV↔SSP sync guard in
  `.github/workflows/compliance-checks.yml` will fail if these
  diverge.

### Documentation updates

- `AI_REPO_GUIDE.md` — add a row to the "Terraform modules" inventory
  pointing at `terraform/modules/workloads/<name>/`
- For the *first* Phase 8 PR to merge: add a "Phase 8 — workload
  module library" section to `.context/roadmap.md`. For PRs 2–4: add
  a sub-bullet under that existing section.

## Acceptance criteria

A module PR is mergeable only when **all** of these pass:

- `terraform fmt -recursive -check terraform/` exits 0
- `terraform -chdir=terraform/modules/workloads/<name> init -backend=false && terraform -chdir=terraform/modules/workloads/<name> validate` passes
- `terraform -chdir=terraform/govcloud init -backend=false && terraform -chdir=terraform/govcloud validate` passes (module wired in)
- `terraform -chdir=terraform/demo init -backend=false && terraform -chdir=terraform/demo validate` passes (module wired in)
- `tflint --recursive` clean
- `tfsec terraform/` reports no NEW high or critical findings
  attributable to this module (pre-existing findings are not blockers
  but should be acknowledged in the PR body)
- `checkov -d terraform/` reports no NEW failed checks attributable
  to this module
- `bash test.sh` passes (199+ checks, 0 failed)
- `.github/workflows/compliance-checks.yml` passes (CSV schema, CSV↔SSP
  sync, SSP TODO-count guard)
- README has all eight sections from the section list above, in that
  order
- For `rds_cui` only: PR description cites the destroy-workflow
  verification PR by number and includes a manual-verification
  paragraph confirming the destroy worked end-to-end against a real
  AWS account

## Verification

```bash
# Module-level
terraform fmt -recursive -check terraform/
for m in terraform/modules/workloads/*/; do
  terraform -chdir="$m" init -backend=false -input=false
  terraform -chdir="$m" validate
done

# Root-level
for r in terraform/govcloud terraform/demo; do
  terraform -chdir="$r" init -backend=false -input=false
  terraform -chdir="$r" validate
done

# Static analysis
tflint --recursive --chdir=terraform
tfsec terraform/
checkov -d terraform/

# Repo-wide
bash test.sh
grep -RE 'arn:aws:' terraform/modules/workloads/ && exit 1 || echo "no hardcoded ARN partitions"

# Compliance artifacts (CI runs these automatically)
python3 scripts/check-controls-csv.py
bash scripts/check-ssp.sh
```

## Do NOT

- Do NOT introduce more than one workload module in a single PR
  (ADR-011 §6, per-PR boundary).
- Do NOT modify a Phase 3 module's variables, outputs, or behavior in
  a backward-incompatible way (ADR-011 §7). If the workload module
  needs new surface from a Phase 3 module, land that as a separate
  preceding PR.
- Do NOT silently skip features missing in GovCloud (ADR-011 §3).
  Fail closed at `terraform validate` time via `precondition` blocks.
- Do NOT exceed the $15/mo demo cost ceiling without the opt-out flag
  (ADR-011 §4) or a supersedence to ADR-011.
- Do NOT pre-write a roadmap entry for a module that has not yet
  merged. Roadmap entries describe shipped or actively-in-flight
  work, not aspirations.
- Do NOT start `rds_cui` until the destroy-workflow verification PR
  has merged.
- Do NOT bake account IDs, region names, or bucket names into module
  defaults.

## Truth-hierarchy updates

- The module README (`terraform/modules/workloads/<name>/README.md`)
  is the canonical doc for that module — control mappings, inputs,
  outputs, and partition parity all live there.
- `AI_REPO_GUIDE.md` "Terraform modules" inventory is the discovery
  surface; keep it current.
- `controls/nist-800-171-mapping.csv` and `ssp/SSP.md` are the
  compliance source of truth; CI guards their consistency. Update
  both atomically in the same PR as the module.
- ADR-011 governs the *phase*. Per-module decisions (sizing, schema
  shape, output surface) live in the module README and the PR body
  — not in new ADRs unless they supersede a Phase 3 or Phase 8
  cross-cutting decision.
