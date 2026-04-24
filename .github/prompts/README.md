# Prompts Directory

Prompt files referenced from GitHub issues and PR comments.

## Before writing a new project prompt

Project prompts (like `NN-<stage>.md`) are validated by the **Analyst role**
before any implementation starts. Analyst applies the "15-minute test" from
[`.github/agents/analyst.agent.md`](../agents/analyst.agent.md) →
"Prompt Pre-Flight Validation":

> If the intended audience spent 15 minutes with the final deliverable,
> would they *experience* the outcome, or would they *read about* it?

Prompts that list deliverables without specifying the user outcome fail
pre-flight. The most common failure: describing 6 React pages instead of
describing what a user will be able to *do* with those pages.

Lead your prompt with **Client-facing outcomes** (concrete user actions)
and **Non-negotiables** (things that must be real, not mocked). File
lists come after, not before.

## Files here

- **Shared procedural prompts** (template-provided; e.g.) — `pr-resolve-all.md`,
  `repo-onboarding.md`, `copilot-onboarding.md`, `expand-backlog-entry.md`.
  These describe procedures, not deliverables, and don't require pre-flight.
- **Project prompts** (you add these) — `NN-<stage>.md`, one per issue.
  These require Analyst pre-flight before implementation.

## Project prompt series — `cmmc-level2-aws-enclave-reference`

Run in order. Each prompt declares its prerequisites; some can be
parallelized once their predecessor lands (noted below).

| #  | File | Purpose | Parallelizable with |
|----|------|---------|---------------------|
| 00 | [`00-initial_prompt.md`](00-initial_prompt.md) | Original seed brief from the user (do not modify) | — |
| 01 | [`01-init-project.md`](01-init-project.md) | De-templatize repo (README stub, AI_REPO_GUIDE, `.context/`, LICENSE, ownership map) | — |
| 02 | [`02-scaffold-and-architecture.md`](02-scaffold-and-architecture.md) | Directory skeleton + Mermaid network diagram | — |
| 03 | [`03-terraform-shared-modules.md`](03-terraform-shared-modules.md) | Six partition-aware modules (vpc, iam_baseline, kms, cloudtrail, guardduty, config) | — |
| 04 | [`04-terraform-govcloud-root.md`](04-terraform-govcloud-root.md) | GovCloud reference root (`validate`-clean, not applied) | 05 |
| 05 | [`05-terraform-demo-root.md`](05-terraform-demo-root.md) | Commercial-AWS deployable demo with workload + URL | 04 |
| 06 | [`06-controls-csv.md`](06-controls-csv.md) | NIST 800-171 → AWS mapping CSV (110 controls) | 07 |
| 07 | [`07-ssp-skeleton.md`](07-ssp-skeleton.md) | SSP markdown: 10 controls written, 100 TODO stubs | 06 |
| 08 | [`08-readme-and-launch-narrative.md`](08-readme-and-launch-narrative.md) | Full README rewrite with Nov 10 2026 deadline narrative | — |
| 09 | [`09-demo-deploy-workflow.md`](09-demo-deploy-workflow.md) | OIDC-based deploy / nightly destroy workflows for the demo | 10 |
| 10 | [`10-ci-and-compliance-checks.md`](10-ci-and-compliance-checks.md) | Terraform CI + CSV/SSP/Mermaid guard scripts | 09 |

Recommended execution waves:

1. **Wave 1**: `01`
2. **Wave 2**: `02`
3. **Wave 3**: `03`
4. **Wave 4** (parallel): `04`, `05`, `06`
5. **Wave 5** (parallel): `07`, `09`, `10`
6. **Wave 6**: `08` (uses outputs from `05`/`09`/`10` for the demo URL and CI badges)

Each numbered prompt above triggers the **Analyst pre-flight gate** per
[`AGENTS.md`](../../AGENTS.md) → "Analyst pre-flight gate". Do not start
implementation on a prompt-referenced issue until a Pre-Flight Report
with verdict **PASS** has been posted.
