# AI_REPO_GUIDE.md

> **Purpose**: Canonical reference for AI agents working with
> `cmmc-level2-aws-enclave-reference`.
> **Last verified**: 2026-04-24

For human documentation, see [`README.md`](README.md). For agent
instructions and the truth hierarchy, read [`AGENTS.md`](AGENTS.md) first.

## Project summary

A reference architecture for a minimal CUI enclave in AWS GovCloud aligned
to CMMC 2.0 Level 2 / NIST SP 800-171 r2, plus a deployable commercial-AWS
demo. Ships:

- Mermaid network diagram of the boundary, VPC, subnets, and access patterns
- Six partition-aware Terraform modules (vpc, iam_baseline, kms,
  cloudtrail, guardduty, config) consumed by both stacks
- A GovCloud root that `terraform validate`s clean (not applied here — no
  GovCloud account)
- A commercial-AWS demo root that `terraform apply` deploys end-to-end
  (cost-bounded, nightly auto-destroy)
- 110-control NIST 800-171 → AWS mapping CSV
- SSP markdown skeleton (10 controls fully written, 100 TODO stubs)

## Where canonical truth lives

- [`AGENTS.md`](AGENTS.md) — agent instructions, truth hierarchy, role
  selection, onboarding
- [`.context/00_INDEX.md`](.context/00_INDEX.md) — project context entry
  point (lazy-loads rules, state, roadmap, vision)
- [`.context/rules/agent_ownership.md`](.context/rules/agent_ownership.md)
  — which role may edit which paths
- [`.context/roadmap.md`](.context/roadmap.md) — phase plan mirroring the
  prompt series
- [`.github/prompts/README.md`](.github/prompts/README.md) — numbered
  prompt series and execution order

## Repository layout

```
/
├── AGENTS.md                 # agent instructions (read first)
├── AI_REPO_GUIDE.md          # this file
├── CLAUDE.md                 # Claude Code memory pointer to AGENTS.md
├── README.md                 # project stub (full version in prompt 08)
├── LICENSE                   # Apache-2.0
├── install.sh                # Codespace bootstrap (template-provided)
├── test.sh                   # template structural verification
│
├── .context/                 # canonical project truth
│   ├── 00_INDEX.md
│   ├── backlog.yaml
│   ├── roadmap.md            # phase plan
│   ├── rules/                # immutable constraints (agent_ownership, code quality)
│   ├── sessions/             # session summaries
│   ├── state/                # active-task tracking
│   └── vision/               # design artifacts (diagrams live here too)
│
├── .github/
│   ├── agents/               # role agent files (Analyst, Architect, …, DevOps, Docs)
│   ├── ISSUE_TEMPLATE/
│   ├── prompts/              # numbered prompt series + shared procedural prompts
│   └── workflows/            # CI (terraform-ci, compliance-checks, demo-*)
│
├── terraform/                # added in prompts 03–05
│   ├── modules/              # vpc, iam_baseline, kms, cloudtrail, guardduty, config
│   ├── govcloud/             # GovCloud reference root (validate-clean)
│   └── demo/                 # commercial-AWS deployable demo
│
├── controls/                 # added in prompt 06 (NIST 800-171 mapping CSV)
├── ssp/                      # added in prompt 07 (SSP skeleton)
├── diagrams/                 # added in prompt 02 (Mermaid network diagram)
├── docs/                     # FAQ, ADRs, postmortems, guides
└── scripts/                  # setup, verify, dispatch helpers
```

## Repo conventions

- **Truth hierarchy**: `.context/**` > `docs/**` > codebase. Conflicts are
  resolved by the higher-priority source; the lower one gets a follow-up
  fix in the same PR.
- **Multi-agent workflow**: roles (Analyst, Architect, PM, Backend, QA,
  DevOps, Docs, Judge, Critic) are defined under `.github/agents/`. See
  [`docs/guides/multi-agent-coordination.md`](docs/guides/multi-agent-coordination.md).
- **Path ownership**: every file is owned by exactly one role per
  [`.context/rules/agent_ownership.md`](.context/rules/agent_ownership.md).
  Cross-role edits require a PM claim.
- **Analyst pre-flight gate**: any issue referencing a numbered prompt
  (`.github/prompts/NN-*.md`) must have a passing Pre-Flight Report
  before implementation begins. See [`AGENTS.md`](AGENTS.md) → "Analyst
  pre-flight gate".
- **Driving a PR to merge**: invoke
  [`.github/prompts/drive-pr-to-merge.md`](.github/prompts/drive-pr-to-merge.md)
  once per PR to wait for bot reviews, resolve them via
  `pr-resolve-all.md`, verify CI, and merge under branch protection.
- **Terraform conventions** (once `terraform/` lands): partition-aware via
  `data.aws_partition.current` (no hardcoded `arn:aws:` strings); pinned
  `terraform >= 1.6`, `aws >= 5.40`; `terraform fmt -recursive` clean.
- **Compliance artifacts must stay in sync**: the CSV (`controls/`) and
  SSP (`ssp/SSP.md`) reference the same 110 control IDs; CI guard in
  prompt 10 enforces this.

## Build / test / lint commands

```bash
# Template / repo structural verification
./test.sh

# Terraform (both roots)
terraform fmt -recursive -check terraform/
terraform -chdir=terraform/govcloud init -backend=false && terraform -chdir=terraform/govcloud validate
terraform -chdir=terraform/demo    init -backend=false && terraform -chdir=terraform/demo    validate

# Compliance guards
python3 scripts/check-controls-csv.py   # 110 rows, 14 families, addressed_by_repo tally
bash    scripts/check-ssp.sh            # 110 headers, 100 TODO stubs, 10 written
```

## CI and verification

Workflows live in [`.github/workflows/`](.github/workflows/):

| Workflow | Trigger | Purpose |
| --- | --- | --- |
| `terraform-ci.yml` | PR + push to `main` | `fmt -check`, matrix `init/validate/tflint/checkov/tfsec` for `govcloud` and `demo` roots. |
| `compliance-checks.yml` | PR + push to `main` | Mermaid lint, CSV schema (`controls/schema.json`), SSP TODO-count guard, CSV↔SSP sync (every `full` row has a written section). |
| `demo-plan.yml` | PR touching `terraform/demo/**` | Read-only OIDC plan against the demo account; posts plan summary as a PR comment. |
| `demo-deploy.yml` | `workflow_dispatch` (typed `DEPLOY`, `main` only) | Applies `terraform/demo`; smoke-tests the Function URL for the "NOT A CUI ENCLAVE" disclaimer string. |
| `demo-destroy.yml` | `workflow_dispatch` (typed `DESTROY`) + nightly cron `0 7 * * *` | Tears down the shared demo. Concurrency-grouped with deploy. |

Local equivalents of CI guards:

- `terraform fmt -recursive -check terraform/`
- `terraform -chdir=terraform/<root> validate`
- `python3 scripts/check-controls-csv.py`
- `bash scripts/check-ssp.sh`
- `./test.sh` (template structural checks; do not weaken)

Generators are the source of truth for compliance artifacts — never
hand-edit `controls/nist-800-171-mapping.csv` or the headers/TODO stubs
in `ssp/SSP.md`. Re-run `scripts/gen-controls-csv.py` and
`scripts/gen-ssp.py` instead. See [`scripts/README.md`](scripts/README.md).

## Next steps

The project is built incrementally by the numbered prompt series under
[`.github/prompts/`](.github/prompts/). Run them in the order documented
in [`.github/prompts/README.md`](.github/prompts/README.md). This file
should be updated whenever a new top-level directory or verification
command is introduced (per the doc-sync rule in
[`.context/rules/process_doc_maintenance.md`](.context/rules/process_doc_maintenance.md)
if present, or [`AGENTS.md`](AGENTS.md) §"Ongoing maintenance" otherwise).
