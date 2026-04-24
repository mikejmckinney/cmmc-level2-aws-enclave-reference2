# Context Pack Index

> **Purpose**: Entry point for AI agents to understand the project's
> direction, constraints, and current state.

## Project

`cmmc-level2-aws-enclave-reference` — a reference architecture and partial
Terraform implementation for a minimal **CUI enclave in AWS GovCloud**,
aligned to **CMMC 2.0 Level 2 / NIST SP 800-171 r2**, plus a deployable
commercial-AWS demo.

## Problem statement

CMMC 2.0 **Phase 2** begins **November 10, 2026**. Many DoD primes and
subs will need a Level 2 self-assessment (NIST SP 800-171 r2 over CUI
systems) to remain contract-eligible. Typical remediation timelines are
6–12 months end-to-end. Most Defense Industrial Base orgs are
under-prepared. This repo gives MSPs and DIBs a credible starting point:
a pre-baked CUI enclave reference, a control-mapping spreadsheet, an SSP
skeleton, and a clickable demo.

## Truth hierarchy

`.context/**` > `docs/**` > codebase. This **priority order** is enforced
when sources conflict; see [`AGENTS.md`](../AGENTS.md) §"Truth hierarchy"
for the conflict-resolution procedure.

## Key decisions

- **Two parallel Terraform stacks** sharing one set of partition-aware
  modules: `terraform/govcloud/` (validate-only, no GovCloud account here)
  and `terraform/demo/` (deployable to commercial AWS).
- **Apache-2.0** license; reference architecture, not legal advice.
- **OIDC-only** demo deploys; no long-lived AWS keys committed.
- **Compliance artifacts in sync**: the 110-control CSV and SSP skeleton
  share IDs and are CI-gated against drift.
- **Analyst pre-flight gate** applies to every numbered prompt
  (`.github/prompts/NN-*.md`) before implementation.

## Directory map

```
.context/
├── 00_INDEX.md          # this file
├── backlog.yaml         # machine-readable task list (not used in this project)
├── roadmap.md           # phase-by-phase plan mirroring the prompt series
├── rules/               # immutable constraints
│   ├── agent_ownership.md      # canonical role → owned paths map
│   ├── domain_code_quality.md  # SOLID/TDD/clean-code floor + Terraform thresholds
│   └── README.md
├── sessions/            # session history
│   └── latest_summary.md
├── state/               # active task tracking
│   ├── coordination.md
│   ├── feedback_template.md
│   ├── task_template.md
│   └── README.md
└── vision/              # design artifacts (network diagram lives in /diagrams once prompt 02 runs)
    └── README.md
```

## Agent reading order

1. [`AGENTS.md`](../AGENTS.md) — instructions, truth hierarchy, role selection
2. [`AI_REPO_GUIDE.md`](../AI_REPO_GUIDE.md) — repo structure and commands
3. This file
4. [`roadmap.md`](roadmap.md) — what to build next
5. [`rules/agent_ownership.md`](rules/agent_ownership.md) — what your role may edit
6. [`state/coordination.md`](state/coordination.md) — what's locked right now
7. [`.github/prompts/README.md`](../.github/prompts/README.md) — the prompt series
