# Handoff: phases-1-7-recovery

> Recovery handoff for the workflow-bypass incident on 2026-04-24.
> The receiving role is whoever picks up after the recovery PR merges
> (likely PM for stakeholder review, or an implementer for Phase 8).

**Task ID**: phases-1-7-recovery
**From role**: pm (recovery) — original work was Copilot acting in DevOps + Docs scope
**To role**: pm / next session
**Date**: 2026-04-24
**Branch**: `recovery/phases-1-7-uncommitted-work`

## Decisions made (and why)

- **Recover, don't redo** — Phase 1–7 deliverables on disk meet their stated acceptance criteria; redoing them would waste ~7 phases of work and produce no better artifact. Source: [`.context/roadmap.md`](../roadmap.md) acceptance bullets per phase.
- **One logical commit per phase, not one giant commit** — preserves bisect/revert capability and gives the recovery PR a structure a reviewer can actually read. Source: PR best-practice in [`docs/guides/agent-best-practices.md`](../../docs/guides/agent-best-practices.md) → "Issue and PR Granularity."
- **Use the user's git identity for the commits** — these are the user's contributions; Copilot is co-authored via trailer, not primary author. Source: standard git practice; matches how Copilot suggestions are normally attributed in IDE-driven work.
- **Add `.gitignore` first** — without it, `terraform init` had already populated `~90 MB` of provider binaries that would have been accidentally staged. Source: `git ls-files --others --exclude-standard | grep .terraform` showed the leak before the gitignore commit.
- **Postmortem-001 generalizes** — the root cause (no explicit "create a branch and commit before you start" precondition in `AGENTS.md`) applies to *any* repo using this template, not just this project. Source: scanned [`AGENTS.md`](../../AGENTS.md) — no occurrence of "branch" as a precondition for implementation work.
- **No source-file edits to "fix" anything in phases 1–7** — recovery scope is metadata only; if a reviewer finds a real bug in (say) a Terraform module, it's a separate PR. Source: [`AGENTS.md`](../../AGENTS.md) §"Work style" → "no drive-by refactors."

## Files touched

| File | Change |
|------|--------|
| `.gitignore` | New — Terraform/Python/OS exclusions |
| 7 × phase commits | See `git log main..HEAD --oneline` on the branch |
| `.context/state/_active.md` | Rewrite — reflects recovery PR as active task |
| `.context/sessions/latest_summary.md` | Append — Phases 2–7 entry + workflow-bypass note |
| `.context/roadmap.md` | Mark Phases 1–7 ✅ shipped 2026-04-24 |
| `.context/state/handoff_phases-1-7-recovery.md` | This file |
| `docs/postmortems/postmortem-001-workflow-bypass.md` | New — full postmortem |
| `docs/postmortems/README.md` | Index row for postmortem-001 |

## Open questions / blockers

1. **Phase 1–7 deliverables have had zero review** — Judge diff-gate, Critic, QA never ran. The recovery PR itself can be the review vehicle, but reviewers should treat each phase commit as a separate review unit, not skim the aggregate diff.
2. **Should the Phase 1–7 work be re-run through the role-based workflow retroactively?** I argue **no** — the artifacts meet acceptance criteria; the cost of re-running outweighs the audit benefit. The postmortem records the bypass; future phases follow the proper workflow. PM decides.
3. **Does the postmortem's "branch precondition" rule belong in `AGENTS.md` or in a new ADR?** I recommend ADR (so the rationale is preserved) plus a short rule in `AGENTS.md` §"Work style" pointing to it. See postmortem-001 action items.

## Recommended next step

Review the recovery PR commit-by-commit, merge it, then PM decides between (a) opening the proposed ADR-011 for the branch-precondition rule, or (b) deferring to Phase 8 triage.

## Source links (for the receiver)

- [`docs/postmortems/postmortem-001-workflow-bypass.md`](../../docs/postmortems/postmortem-001-workflow-bypass.md) — full postmortem with action items
- [`.context/roadmap.md`](../roadmap.md) — phases now marked ✅
- [`AGENTS.md`](../../AGENTS.md) §"Session-state cadence" — the rule that was missed
- [`AGENTS.md`](../../AGENTS.md) §"Work style" — where the proposed branch-precondition rule would land
- Recovery branch commit log: `git log main..recovery/phases-1-7-uncommitted-work --oneline`

## Verification commands run

- `git log --all --oneline` → only `c39ca53 Initial commit` on `main` before recovery — pass (confirmed bypass)
- `gh pr list --state all` and `gh issue list --state all` → both empty — pass (confirmed bypass)
- `git ls-files --others --exclude-standard | grep .terraform` → 0 results after `.gitignore` commit — pass (confirmed leak plugged)
- `./test.sh` — **pending after final commits** (Phase F of recovery plan)
