# Latest Session Summary

> Most recent agent session summary. Roles append a short entry here at
> task close-out per [`AGENTS.md`](../../AGENTS.md) → "Session-state cadence".

## 2026-04-24 — Phase 1 init (DevOps + Docs)

**Shipped**: De-templatized the repo per
[`.github/prompts/01-init-project.md`](../../.github/prompts/01-init-project.md):
project-stub README, regenerated AI_REPO_GUIDE, fresh `.context/` content
(00_INDEX, roadmap, vision, rules/README, this file), Apache-2.0 LICENSE,
project-specific FAQ and docs/README, extended
`.context/rules/agent_ownership.md` with rows for `terraform/**`,
`controls/**`, `ssp/**`, `diagrams/**`, `.github/workflows/demo-*.yml`,
fixed `.github/ISSUE_TEMPLATE/config.yml` owner/repo, updated
`.github/agents/{backend,frontend,qa}.agent.md` globs, set Terraform/HCL
thresholds in `.context/rules/domain_code_quality.md`.

**Harder than expected**: the template's `TEMPLATE_PLACEHOLDER` marker is
referenced both as stub-content scaffolding AND as load-bearing
mechanism documentation in `AGENTS.md`, `.github/copilot-instructions.md`,
`scripts/verify-env.sh`, and the docs.agent.md role file. Strict-zero
removal would break template re-detection. Mechanism references kept
intact; only stub-content markers removed.

**Generalizes**: any "scrub all instances of marker X" prompt needs to
distinguish marker-as-content from marker-as-implementation. Worth
folding into the next revision of the template's onboarding prompt.

**Next**: prompt 02 (architecture + Mermaid network diagram).

## 2026-04-24 — Phases 2–7 implementation (workflow bypass; not committed)

**Shipped (in working tree only — never committed, never reviewed)**: All
remaining roadmap phases per `.github/prompts/02–10`:

- Phase 2: `diagrams/network.md` (Mermaid) + scaffold dirs.
- Phase 3: six partition-aware modules under `terraform/modules/`
  (vpc, iam_baseline, kms, cloudtrail, guardduty, config).
- Phase 4: `terraform/govcloud/` (validate-only) and `terraform/demo/`
  (deployable, with Lambda disclaimer page).
- Phase 5: `controls/nist-800-171-mapping.csv` (110 controls + schema)
  and `ssp/SSP.md` (10 written / 100 TODO) plus generator/checker scripts.
- Phase 6: `.github/workflows/{demo-plan,demo-deploy,demo-destroy,
  terraform-ci,compliance-checks}.yml` and `docs/demo-deploy.md`.
- Phase 7: launch-narrative `README.md` overwriting the Phase 1 stub.

**What went wrong**: the agent session that performed Phases 2–7 worked
directly on `main` in the working tree and never created a branch,
commit, push, PR, or issue. Verified after the fact: only one commit on
`main` (`c39ca53 Initial commit`); zero branches; zero PRs; zero issues.
There was also no `.gitignore`, so `terraform init` left ~90 MB of
provider binaries staged for accidental commit.

**Generalizes**: yes — see `docs/postmortems/postmortem-001-workflow-bypass.md`.
Root cause: AGENTS.md describes the multi-agent workflow as "claim →
implement → review → merge" but never states the precondition "create a
feature branch and commit before you start." Agents inferred from the
absence that working on `main` was acceptable.

**Recovery**: this session reconstructed the work into a branch
(`recovery/phases-1-7-uncommitted-work`) with one logical commit per
phase, opened a PR, wrote the postmortem, and filed a Phase 8 follow-up
issue. Session-state cadence rule was also missed; this entry plus
`.context/state/handoff_phases-1-7-recovery.md` are the corrective.

**Next**: merge the recovery PR, then resume normal cadence —
stakeholder review of phases 1–7 (per `coordination.md` state machine)
or proceed to Phase 8 once the follow-up issue is triaged.

## 2026-04-24 — Recovery PR review-resolution + missing-lessons capture

**Shipped (this session, no source changes)**:
- Posted Phase 1 Issue/Suggestion Index on PR #1 (28 unique items: 14 bot
  review comments, 4 CI failures, 10 deterministic tfsec findings).
- Decision: keep PR #1 scoped to *recovery only*; file a separate
  tracking issue + new PR for the 28 items so the recovery record stays
  clean and the remediation gets its own review cycle.
- Captured four lessons from the prior Phases 2–7 session that were
  missing from the recovery records (see "Generalizes" below).
- Added [`/memories/repo/lessons.md`](../../../memories/repo/lessons.md)
  with the same four lessons for future agents in this repo.

**Harder than expected**: bot reviewers (gemini-code-assist,
copilot-pull-request-reviewer, chatgpt-codex-connector) only post a
sample of findings per PR. The deterministic local sweep (tfsec)
surfaced 10 additional items the bots missed, including a CRITICAL SG
egress and 4 HIGH IAM-wildcard findings. Don't trust the bot review
surface as complete — always run the deterministic toolchain locally.

**Generalizes (these were missing from postmortem-001 / handoff /
the prior `latest_summary.md` entries)**:

1. **`awk -F,` does not honor quoted CSV cells.**
   [`scripts/check-ssp.sh`](../../scripts/check-ssp.sh) originally
   missed two of ten written controls (3.1.1, 3.13.1) because their
   descriptions contain commas. Fixed by switching to a Python
   `csv.DictReader` heredoc. Anyone writing future shell guards over
   the controls CSV will hit this again unless the lesson is recorded.
2. **Cross-check guards belong in the same PR as the second generator.**
   When two artifacts share an invariant (here: CSV "full" rows ↔ SSP
   fully-written controls), the CI guard enforcing alignment must land
   with the generator that creates the dependency, not bolted on later.
   The CSV initially produced 12 full rows while the SSP had 10;
   re-aligned 5↑/7↓ and added the `csv-ssp-sync` job in
   [`.github/workflows/compliance-checks.yml`](../../.github/workflows/compliance-checks.yml).
3. **[`test.sh`](../../test.sh) enforces exact markdown header casing.**
   It rejected `## Future improvements` and required
   `## Future Improvements`. When adding a required section to a doc,
   match the `test.sh` grep patterns exactly.
4. **Intentional `TODO()` breadcrumbs in README** —
   `TODO(citation): <Greypike report URL>` (Phase 2 deadline citation)
   and `TODO(demo-url)` (filled after first `demo-deploy.yml` run).
   Do NOT scrub these without resolving the underlying need.

**Next**: open the tracking issue with the 28 ISS items and a new
fix-PR scoped to the items the user approves for inclusion.
