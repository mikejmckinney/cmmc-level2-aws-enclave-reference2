# ADR-011: Phase 8 — workload module library scope and sequencing

## Status

Accepted

## Date

2026-04-25

## Context

Phases 1–7 ([roadmap](../../.context/roadmap.md)) shipped the *enclave
plumbing* — VPC, IAM baseline, KMS, CloudTrail, GuardDuty, Config, plus
a demo Lambda. The roadmap explicitly listed *"a workload module library
(RDS-with-CUI patterns, S3 data-classification patterns, etc.)"* under
**Future / out-of-scope** with the note "possible Phase 8; track in a
follow-up issue." Issue #2 is that tracker.

Issue #2 lists four candidate workload patterns (RDS-with-CUI,
S3-data-classification, secrets/parameter store, alarms) and explicitly
calls out three pre-implementation problems that need to be decided
*once*, repo-wide, before any module code lands:

1. **Per-workload variability is high.** RDS-Postgres differs from
   RDS-MySQL on encryption-in-transit defaults; "active CUI" S3 differs
   from "archive CUI" S3 on lifecycle and access-pattern shape. Without
   a rubric, every PR re-litigates which variant ships.
2. **GovCloud feature-parity gaps.** RDS Proxy, Macie sub-features, and
   several others differ between commercial AWS and GovCloud. Modules
   must have a documented policy for what to do when a feature is
   unavailable in the target partition.
3. **Cost in the demo stack.** RDS at the cheapest sizing
   (`db.t4g.micro` + 20 GB gp3) is roughly $13/mo plus storage and I/O.
   The demo destroy workflow has historically only been verified
   against the demo Lambda; a stateful workload changes the destroy
   contract.

The issue also references a per-phase prompt file
[`.github/prompts/11-workload-modules.md`](../../.github/prompts/11-workload-modules.md)
that does not yet exist, and notes that **the prompt is itself a
deliverable** before any implementation PR can run. AGENTS.md's
*Analyst pre-flight gate* applies to that prompt before the first
implementation PR opens.

This ADR exists to make the cross-cutting decisions (scope, sequencing,
GovCloud policy, demo-cost policy, per-PR boundary) once so the prompt
file and downstream module PRs don't need to re-derive them.

## Decision

We will ship a Phase 8 workload module library as a **series of
independent additive PRs**, one workload module per PR, governed by
the rubric and policies below.

### 1. Scope: in / out for Phase 8

**In scope** (this ADR commits to all four; sequencing in §2 below):

| # | Module path | Purpose |
|---|---|---|
| 1 | `terraform/modules/workloads/secrets/` | `aws_secretsmanager_secret` + `aws_ssm_parameter` patterns scoped to the enclave CMK; rotation Lambda hook (off by default; consumer enables per-secret) |
| 2 | `terraform/modules/workloads/s3_cui/` | CUI bucket pattern: object lock (governance), default KMS encryption, public-access block, lifecycle for retention, access logs to a separate log bucket, tag-based policy enforcing `data_classification = cui` |
| 3 | `terraform/modules/workloads/rds_cui/` | RDS-Postgres in private subnets: KMS-encrypted at rest, TLS-only in transit, IAM auth enabled, audit logging to CloudWatch, deletion protection on, automated backups + cross-region snapshot copy |
| 4 | `terraform/modules/workloads/alarms/` | Opinionated CloudWatch alarm set wiring the Phase 3 GuardDuty/Config/CloudTrail signals to SNS topics; control-mapped to the IR family |

**Out of scope for Phase 8** (file separate issues if/when needed):

- RDS-MySQL, RDS-MariaDB, Aurora variants. Postgres-only is the
  *commitment* — not a placeholder. Expanding to other engines is a
  separate ADR.
- Macie / DLP automation. Macie's GovCloud feature surface is too
  partial for a clean partition-aware module; revisit when parity
  closes.
- ALB / API Gateway / Fargate workload patterns. The Phase 4 demo
  already includes a Lambda; further compute patterns should be a
  separate "compute workload" series, not bundled here.
- Multi-account / Control Tower / org-trail extensions. Already
  excluded by the roadmap; restating for clarity.
- A "secret rotation Lambda library" of canned rotators (Postgres,
  MySQL, etc.). The secrets module ships the *hook*; the rotators
  themselves are downstream consumer work.

### 2. Sequencing rubric

Each candidate module is scored on five weighted dimensions. Sequencing
is by descending total score (ties broken by ascending demo cost).

| Dimension | Weight | Rationale |
|---|---|---|
| Number of NIST 800-171 controls the module moves from `requires_client_config = TRUE` to `addressed_by_repo = TRUE` (in `controls/nist-800-171-mapping.csv`) | 3 | Direct compliance utility — the whole point of the repo |
| Demo-cost ceiling per month at the documented sizing (raw $/mo) | -2 | Cheaper modules ship earlier; expensive ones need their own destroy-workflow verification first |
| GovCloud parity (1 = full parity, 0 = partial, -2 = no parity) | 2 | Modules with no GovCloud parity should fail closed, not ship |
| Number of *other Phase 8 modules* that depend on this one (transitive) | 2 | Prerequisite-first reduces rework |
| Implementation complexity (1 = small, 0 = medium, -1 = large) | 1 | Smaller PRs review faster and reduce blast radius |

Applied to the four in-scope modules:

| Module | Controls | Cost/mo | GovCloud | Depends-on count | Complexity | Score |
|---|---|---|---|---|---|---|
| `secrets` | ~4 (SC-12, SC-28, IA family) | ~$0.40/secret | 1 | 2 (rds, alarms reference it) | 1 (small) | `4·3 − 0·(-2) + 1·2 + 2·2 + 1·1` = **19** |
| `s3_cui` | ~6 (MP family + SC-28 + AU mapping via existing data events) | ~$0.20 (storage-trivial demo bucket) | 1 | 0 | 0 (medium) | `6·3 − 0·(-2) + 1·2 + 0·2 + 0·1` = **20** |
| `rds_cui` | ~5 (SC-12, SC-28, IA-5, AU family) | ~$13/mo (db.t4g.micro + 20 GB gp3) | 1 | 0 | -1 (large) | `5·3 − 13·(-2) + 1·2 + 0·2 + (-1)·1` = **−10** (cost dominates) |
| `alarms` | ~3 (IR family) | ~$0/mo (alarms are free; SNS at demo volume is free-tier) | 1 | 0 (consumes Phase 3 outputs) | 1 (small) | `3·3 − 0·(-2) + 1·2 + 0·2 + 1·1` = **12** |

(Cost enters the score as the literal dollar figure with weight −2,
which is why RDS scores so low — the rubric is designed to punish
high-monthly-cost demo modules unless the control coverage is
overwhelming.)

**Resulting sequencing**: `s3_cui` (20) → `secrets` (19) → `alarms` (12)
→ `rds_cui` (−10).

The `secrets` module is implemented to expose its outputs (KMS key
references, SSM-path conventions) so that `rds_cui` can consume them
when it lands; this is documented as a forward-compatibility
requirement on PR-2 (`secrets`), not enforced via runtime dependency.

The `rds_cui` PR is **gated on** a separate verification that
`.github/workflows/demo-destroy.yml` correctly destroys an RDS
instance — adding a stateful workload changes the destroy contract
and that needs its own PR before the workload module ships.

### 3. GovCloud-degradation policy

When a feature used by a workload module is unavailable or partially
available in the target partition (commercial vs. `aws-us-gov`), the
module **MUST fail closed** rather than silently degrade:

- Detect via `data.aws_partition.current.partition` and explicit
  partition-conditional `var.enable_<feature>` toggles.
- If a required feature is missing in the configured partition, emit a
  `terraform validate`-time error (use a `precondition` or `validation`
  block) — not a runtime AWS API failure on apply.
- Document the gap in the module README under a `## Partition parity`
  heading.

Silent degradation (e.g., "if Macie isn't available we just skip it")
is forbidden. The whole point of the reference repo is that the
shipped configuration is exactly what evidences the controls; a
silently-skipped feature breaks that contract.

### 4. Demo-cost policy

Each workload module's `terraform/demo/` wiring **MUST**:

- Document the steady-state monthly cost in the module README under
  `## Demo cost` with a per-line breakdown (compute, storage, network,
  data transfer).
- Default to the cheapest-viable sizing (e.g., `db.t4g.micro` for RDS,
  single-AZ where the workload pattern allows). Production-shaped
  defaults belong in the module README's `## Production overrides`
  section, not in the demo wiring.
- Be verified against `.github/workflows/demo-destroy.yml` — the
  destroy workflow run from a clean state must remove every resource
  the module created. This is an explicit acceptance criterion on
  every workload-module PR.

If a module's demo cost exceeds **$15/mo** at the documented sizing,
the PR introducing it must either (a) lower the sizing, (b) gate the
module's demo wiring behind a `var.enable_<module>_demo` flag that
defaults to `false`, or (c) update this ADR with a supersedence and a
new cost ceiling.

### 5. Module conventions (per-module checklist)

Every workload module follows the Phase 3 module conventions
([prompt 03](../../.github/prompts/03-terraform-shared-modules.md)
acceptance criteria) plus these Phase 8 additions:

- [ ] Path: `terraform/modules/workloads/<name>/`
- [ ] Files: `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`,
  `README.md`
- [ ] `versions.tf` matches the Phase 3 pins (terraform >= 1.6,
  hashicorp/aws >= 5.40)
- [ ] `data.aws_partition.current` lookup; no hardcoded `arn:aws:`
- [ ] README sections: Purpose, Inputs, Outputs, NIST 800-171 controls
  addressed, Partition parity, Demo cost, Production overrides, Gaps
  the consumer must fill
- [ ] Wired into `terraform/govcloud/` (validate-only)
- [ ] Wired into `terraform/demo/` (deployable; destroy-verified)
- [ ] `controls/nist-800-171-mapping.csv` updated: at least one row
  flips from `requires_client_config = TRUE` to
  `addressed_by_repo = TRUE`
- [ ] `ssp/SSP.md` updated: control statements for newly-covered
  controls promoted from `TODO` to written
- [ ] `compliance-checks.yml` CI passes (CSV/SSP sync guards)

### 6. Per-PR boundary

**One workload module per PR.** A PR may not introduce two modules,
even if related. The rationale is reviewer load, blast radius, and the
ability to revert one module without unwinding others.

### 7. Backwards compatibility

Phase 8 is **additive only**. No PR in this phase may modify a Phase 3
module's variables, outputs, or behavior in a backward-incompatible
way. If a workload module needs something a Phase 3 module doesn't
expose, the right move is:

1. Open a separate PR that adds the new variable/output to the Phase 3
   module with a backward-compatible default.
2. Land that PR first.
3. Open the workload-module PR consuming the new surface.

## Options Considered

### Option 1: One ADR + one prompt + sequenced per-module PRs (chosen)

- **Pros**: Decision-once-execute-many. The prompt file is the same
  shape as Phases 1–7, so existing tooling (Analyst pre-flight, agent
  ownership, `pr-resolve-all.md`, `drive-pr-to-merge.md`) all apply
  unchanged. Cost and GovCloud policy are decided once, not
  re-litigated per PR.
- **Cons**: Forces this ADR to commit to the four-module list and a
  sequencing rubric before any code is written. If implementation
  reveals one of the modules is a bad fit, requires a supersedence.

### Option 2: One ADR per workload module (decision-per-module)

- **Pros**: Each ADR can be deeply tailored to its workload. No
  premature commitment to the four-module list.
- **Cons**: Floods `docs/decisions/` with low-density ADRs that
  duplicate the same GovCloud-policy / demo-cost / per-PR-boundary
  language. ADRs become a per-PR formality rather than a record of
  cross-cutting decisions.

### Option 3: No ADR, just a prompt file

- **Pros**: Less doc work upfront.
- **Cons**: The four cross-cutting decisions in §1–§4 would silently
  live inside a prompt file (conventionally a how-to, not a decision
  record). Future agents asking "why did Phase 8 ship S3 before RDS?"
  or "why doesn't the secrets module ship a Postgres rotator?" would
  have nowhere to look. ADRs exist for exactly this question.

## Consequences

### Positive

- Sequencing (`s3_cui` → `secrets` → `alarms` → `rds_cui`) is explicit,
  justified, and reviewable. The first PR doesn't have to argue why it
  goes first.
- The GovCloud-fail-closed policy is set once. No per-module PR
  re-debates it.
- Demo cost has a hard ceiling ($15/mo per module) and an opt-out
  escape hatch (`var.enable_<module>_demo` flag), so a module can ship
  even if its cheapest sizing exceeds the ceiling.
- The `rds_cui` gating on a destroy-workflow verification PR is
  explicit, not discovered late.

### Negative

- The four-module commitment may turn out wrong for one or more
  modules. A supersedence is the contract for changing the list, which
  is the right cost — but it's not free.
- The sequencing rubric weights are judgment calls (3 / -2 / 2 / 2 /
  1). Reasonable people could pick different weights and get a
  different order. The weights are documented so future agents can
  argue with the rubric, not the ranking.

### Neutral

- The phase will likely span several months of calendar time given the
  per-PR boundary and the destroy-workflow gating on `rds_cui`. This
  is by design — the v1 enclave was the contracted deliverable; Phase
  8 is utility expansion.

## Implementation

- [x] Land this ADR (PR for issue #2).
- [x] Land [`.github/prompts/11-workload-modules.md`](../../.github/prompts/11-workload-modules.md)
  in the same PR — references this ADR for the cross-cutting
  decisions, supplies the per-module template for individual
  implementation PRs.
- [ ] File a separate issue for the destroy-workflow verification PR
  that gates `rds_cui`.
- [ ] File one tracking issue per module (4 issues), each referencing
  this ADR + the prompt file. Sequence per §2.
- [ ] First implementation PR: `s3_cui` (per the rubric).
- [ ] Update `.context/roadmap.md` to add a "Phase 8 — workload module
  library" section once the first module merges (don't pre-write the
  section before implementation begins; roadmap entries describe
  shipped or actively-in-flight work).

## References

- Issue #2 — Phase 8 tracker
- [`.context/roadmap.md`](../../.context/roadmap.md) — Future /
  out-of-scope section that originally promised Phase 8
- [`docs/postmortems/postmortem-001-workflow-bypass.md`](../postmortems/postmortem-001-workflow-bypass.md)
  — context on why follow-up issues for Phase 8 are being filed
  retroactively
- [`.github/prompts/03-terraform-shared-modules.md`](../../.github/prompts/03-terraform-shared-modules.md)
  — Phase 3 module conventions that Phase 8 extends
- [`.github/prompts/11-workload-modules.md`](../../.github/prompts/11-workload-modules.md)
  — the per-module implementation prompt that this ADR's §5 checklist
  enforces
