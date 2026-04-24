# Roadmap

> Phase-by-phase plan for `cmmc-level2-aws-enclave-reference`. Each phase
> maps to one or more numbered prompt files under
> [`.github/prompts/`](../.github/prompts/). Phases run sequentially; the
> waves inside a phase may run in parallel.

## Phase 1 — Initialize project (prompt 01) ✅ shipped 2026-04-24

De-templatize the repo: project-specific README stub, AI_REPO_GUIDE,
`.context/` content, LICENSE (Apache-2.0), `agent_ownership.md` extension
for project paths, `ISSUE_TEMPLATE/config.yml` owner/repo.

**Acceptance**: stub markers cleared from real artifacts; `./test.sh`
passes; `LICENSE` present.

## Phase 2 — Architecture and scaffolding (prompt 02) ✅ shipped 2026-04-24

Top-level dirs (`terraform/{modules,govcloud,demo}`, `controls/`, `ssp/`,
`diagrams/`); Mermaid network diagram in `diagrams/network.md` showing
CUI boundary, VPC, three subnet tiers, SSM-only admin access, VPC
endpoints, CloudTrail/GuardDuty/Config plane.

**Acceptance**: directory skeleton in place; diagram renders as valid
Mermaid; `diagrams/network.md` labels the CUI authorization boundary.

## Phase 3 — Shared Terraform modules (prompt 03) ✅ shipped 2026-04-24

Six partition-aware modules under `terraform/modules/`: `vpc`,
`iam_baseline`, `kms`, `cloudtrail`, `guardduty`, `config`. Each
consumes `data.aws_partition.current`; each README cites the NIST
800-171 controls it helps satisfy.

**Acceptance**: `terraform fmt`/`init -backend=false`/`validate` clean
on every module; `tflint --recursive` clean; no hardcoded `arn:aws:`
strings.

## Phase 4 — Terraform roots (prompts 04 + 05, parallel) ✅ shipped 2026-04-24

- `terraform/govcloud/` — wires modules with `us-gov-west-1` + FIPS
  endpoints + CUI-grade KMS policies. **Validate-only**, never applied
  in this repo.
- `terraform/demo/` — wires the same modules with commercial-AWS
  cost-optimized overrides; ships a small workload (ALB + Fargate or
  Lambda) serving a "Demo only — NOT a CUI enclave" page.

**Acceptance**: both roots `terraform validate` clean; demo
`terraform apply` works against a commercial account; demo URL returns
the disclaimer banner.

## Phase 5 — Compliance artifacts (prompts 06 + 07, parallel) ✅ shipped 2026-04-24

- `controls/nist-800-171-mapping.csv` — 110 controls × repo coverage,
  with `addressed_by_repo`, `aws_services`, `terraform_resources`,
  `requires_client_config`, `organizational_control` columns.
- `ssp/SSP.md` — all 110 controls listed; 10 written for the controls
  the Terraform actually implements; 100 `TODO` stubs.

**Acceptance**: CSV passes schema check (110 rows, unique IDs, all 14
families); SSP has exactly 100 TODO statuses; CSV/SSP control-ID sets
match.

## Phase 6 — Demo deploy + CI (prompts 09 + 10, parallel) ✅ shipped 2026-04-24

- `.github/workflows/demo-{plan,deploy,destroy}.yml` — OIDC-only,
  manual-dispatch deploy with typed-confirmation gate, nightly auto-destroy.
- `.github/workflows/{terraform-ci,compliance-checks}.yml` — fmt/
  validate/tflint/checkov/tfsec on both stacks; mermaid lint; CSV schema
  guard; SSP TODO-count guard; CSV↔SSP sync guard.

**Acceptance**: `actionlint` clean on all workflows; no AWS access keys
in any workflow; CI total runtime under 5 min on cold cache.

## Phase 7 — Launch narrative (prompt 08) ✅ shipped 2026-04-24

Replace project-stub `README.md` with the full launch page: Phase 2
deadline math citing Greypike (placeholder URL until source confirmed),
"why waiting is expensive" section, quick-start for both stacks, demo
URL, MSP/DIB sub-sections, disclaimer.

**Acceptance**: `November 10, 2026` and `Greypike` appear in README;
live demo URL or `TODO(demo-url)` marker present; disclaimer paragraph
intact.

> **All 7 phases completed 2026-04-24** (recovered retroactively;
> see [`docs/postmortems/postmortem-001-workflow-bypass.md`](../docs/postmortems/postmortem-001-workflow-bypass.md)).
> The original work was performed directly in the working tree without
> any branch/commit/PR; recovered in branch
> `recovery/phases-1-7-uncommitted-work` and merged via PR #1. The
> phases were never "shipped" in the conventional sense — they were
> reconstructed from the working tree.

## Future / out-of-scope (not on this roadmap)

- A full SSP (writing all 100 remaining stubs) — this is the consultant's
  / DIB's job, not the reference repo's.
- A workload module library (RDS-with-CUI patterns, S3 data-classification
  patterns, etc.) — possible Phase 8; track in a follow-up issue.
- FedRAMP overlays, Impact Level 4/5 mappings — separate project.
- Org-trail / multi-account / Control Tower automation — separate project.
