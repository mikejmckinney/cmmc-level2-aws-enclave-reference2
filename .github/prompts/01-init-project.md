# 01 — Initialize project from template

> **Run this first.** De-templatizes the repo so the CMMC content has a clean home.
> Subsequent prompts (`02`–`10`) assume this is done.

## Context

This repo was created from `mikejmckinney/ai-repo-template`. Several files still
contain `TEMPLATE_PLACEHOLDER` markers and must be replaced with content for the
real project: **`cmmc-level2-aws-enclave-reference`** — a reference architecture
for a minimal CUI enclave in AWS GovCloud, plus a deployable commercial-AWS demo.

Read [`AGENTS.md`](../../AGENTS.md) and [`.github/copilot-instructions.md`](../copilot-instructions.md)
before starting. Follow the procedure in
[`.github/prompts/repo-onboarding.md`](repo-onboarding.md) and
[`.github/prompts/copilot-onboarding.md`](copilot-onboarding.md) where applicable.

## Prerequisites

- None. This is the first prompt in the series.

## Deliverables

- [ ] Scan and list every file containing `TEMPLATE_PLACEHOLDER`; replace each
      with project-specific content (do NOT just delete the marker).
- [ ] Replace `README.md` with a project-specific stub (a short paragraph + a
      `TODO: full launch narrative ships in prompt 08` note is fine — `08`
      writes the real one).
- [ ] Regenerate `AI_REPO_GUIDE.md` from this repo's real assets per
      `repo-onboarding.md`.
- [ ] Update `.context/00_INDEX.md` with the project summary, problem statement
      (CMMC 2.0 Level 2 / NIST SP 800-171 r2 in AWS GovCloud), and key
      decisions (partition-aware Terraform, parallel `govcloud/` and `demo/`
      roots, SSP skeleton, 110-control CSV).
- [ ] Update `.context/roadmap.md` with phases that mirror the prompt series:
      Phase 1 init → Phase 2 architecture → Phase 3 Terraform shared modules
      → Phase 4 GovCloud root + Demo root (parallel) → Phase 5 controls CSV
      + SSP (parallel) → Phase 6 launch narrative → Phase 7 demo deploy
      workflow → Phase 8 CI.
- [ ] Extend `.context/rules/agent_ownership.md` with rows for project paths:
      `terraform/**` (Backend role or new Infra role — keep template
      governance rows intact), `controls/**` (Docs), `ssp/**` (Docs),
      `diagrams/**` (Architect), `.github/workflows/demo-*.yml` (DevOps).
- [ ] Replace `PLEASE_UPDATE_THIS/URL` in `.github/ISSUE_TEMPLATE/config.yml`
      with `mikejmckinney/cmmc-level2-aws-enclave-reference2` (detect via
      `git remote -v`).
- [ ] Add `LICENSE` (Apache-2.0) and a `## Disclaimer` section in `README.md`:
      *"This repository is a reference architecture, not legal or compliance
      advice. It does not by itself make any system CMMC-compliant. No warranty.
      Do not place real CUI in the demo environment."*
- [ ] Customize `docs/FAQ.md`: drop template entries, add CMMC-specific Qs
      (What does this repo *not* do? Is this a turnkey enclave? Why GovCloud?
      Can I deploy the demo to my own AWS account? What about FedRAMP?).

## Acceptance criteria

- `grep -R "TEMPLATE_PLACEHOLDER" .` returns no results.
- `grep -R "PLEASE_UPDATE_THIS" .` returns no results.
- `AI_REPO_GUIDE.md` accurately describes this repo's structure (not the template's).
- `LICENSE` exists and is Apache-2.0.
- `README.md` includes the disclaimer paragraph verbatim above.
- `./test.sh` still passes.

## Verification

```bash
grep -R "TEMPLATE_PLACEHOLDER\|PLEASE_UPDATE_THIS" . || echo "clean"
test -f LICENSE && head -1 LICENSE
./test.sh
```

## Do NOT

- Do NOT delete the template-governance roles (Analyst / Architect / PM / QA /
  DevOps / Docs / Judge / Critic) from `.context/rules/agent_ownership.md` —
  they are load-bearing for the multi-agent workflow.
- Do NOT touch `.github/prompts/00-initial_prompt.md` or any other prompt file
  in this series.
- Do NOT start Terraform, CSV, or SSP work — that's prompts `02`–`10`.

## Truth-hierarchy updates

- `.context/00_INDEX.md`, `.context/roadmap.md`, `.context/rules/agent_ownership.md`
- `AI_REPO_GUIDE.md`
- `README.md`, `LICENSE`, `docs/FAQ.md`, `.github/ISSUE_TEMPLATE/config.yml`
