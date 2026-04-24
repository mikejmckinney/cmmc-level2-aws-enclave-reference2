# Postmortem-001: Workflow bypass on Phases 2–7

## Status

Final

## Date

2026-04-24

## Author(s)

GitHub Copilot (Claude Opus 4.7), recovery session, in collaboration with @mikejmckinney.

## Trigger

A new agent session, asked "what stage of the implementation process are
you at?", investigated session-state files and discovered the working
tree contained complete deliverables for Phases 2–7 of the roadmap, but
the git repository contained exactly one commit (the template's `Initial
commit`), zero feature branches, zero pull requests, and zero issues.
All of Phases 2–7 had been performed directly on `main` in the working
tree and never committed, pushed, branched, or reviewed. A Codespace
restart, an accidental `git clean -fdx`, or any branch reset would have
destroyed every artifact.

## Context

This repo (`cmmc-level2-aws-enclave-reference2`) was bootstrapped from
`mikejmckinney/ai-repo-template`, which ships an extensive multi-agent
governance layer:
[`AGENTS.md`](../../AGENTS.md),
[`.github/copilot-instructions.md`](../../.github/copilot-instructions.md),
role files under [`.github/agents/*.agent.md`](../../.github/agents/),
[`.context/state/coordination.md`](../../.context/state/coordination.md),
the prompt series under [`.github/prompts/`](../../.github/prompts/), and
auto-merge / review / coordination workflows under
[`.github/workflows/agent-*.yml`](../../.github/workflows/).

The roadmap ([`/.context/roadmap.md`](../../.context/roadmap.md)) defines
seven sequential phases mapped to numbered prompts (`01-init-project.md`
through `10-ci-and-compliance-checks.md`). Phase 1 was completed and
**recorded** in [`.context/sessions/latest_summary.md`](../../.context/sessions/latest_summary.md).
Phases 2–7 were completed but **never** recorded — and never even
committed.

## What happened

| Step | When | Where |
|---|---|---|
| Repo cloned from template | 2026-04-23 19:16 EDT | `c39ca53 Initial commit` |
| Phase 1 work performed | 2026-04-24 | working tree on `main` |
| Phase 1 close-out written to `latest_summary.md` | 2026-04-24 | working tree on `main` |
| Phases 2–7 work performed (all roadmap deliverables) | 2026-04-24 | working tree on `main` |
| Phase 2–7 close-outs **NOT** written | — | — |
| `_active.md` **NOT** updated | — | — |
| Branch **NOT** created | — | — |
| Commits **NOT** made | — | — |
| Push / PR / issues — **NOT** created | — | — |
| New session started; investigated state | 2026-04-24 (this session) | — |
| Recovery: branch + 7 phase commits + state recovery + this postmortem | 2026-04-24 (this session) | branch `recovery/phases-1-7-uncommitted-work` |

Forensic evidence: `git log --all --oneline | wc -l` returned `1`;
`git branch -a` showed only `main` and its remote tracking ref;
`gh pr list --state all` returned "no pull requests"; `gh issue list
--state all` returned "no issues"; `git reflog` had a single `clone`
entry. The working tree contained 31 modifications to template files
and ~150 untracked files (including a full `terraform/` tree with
`.terraform/` provider binaries totaling ~90 MB).

## Expected vs. Actual

### Expected

Per [`AGENTS.md`](../../AGENTS.md), [`.github/copilot-instructions.md`](../../.github/copilot-instructions.md), and the multi-agent
coordination guide, each roadmap phase should:

1. Open a tracking issue using the appropriate template.
2. Pass the Analyst pre-flight gate (numbered prompts only).
3. Get an Architect plan + Judge plan-gate APPROVE.
4. Be claimed in `coordination.md` with role + branch + paths.
5. Be implemented on a feature branch.
6. Land via a PR that passes Critic, QA, and Judge diff-gate.
7. Be closed out with a session-summary entry and an updated `_active.md`.

### Actual

Phases 2–7 jumped directly from "decision to do them" to "files in the
working tree." Steps 1, 3, 4, 5, 6, and 7 were all skipped. Step 2
(Analyst pre-flight) is genuinely required by the gate language in
[`AGENTS.md`](../../AGENTS.md) §"Analyst pre-flight gate" for any prompt
matching `.github/prompts/NN-*.md` — and was also skipped.

### Gap

The agent that performed Phases 2–7 treated the prompt files as
**execution scripts** rather than as **task definitions to be processed
through the workflow**. Reading prompt 02 → producing the
diagram and modules → moving to prompt 03 felt like "doing the work,"
even though the work doing that bypassed every audit, review, and
recovery mechanism the repo was designed around.

## Root cause

[`AGENTS.md`](../../AGENTS.md) and the role agent files describe the multi-agent workflow
as **claim → implement → review → merge**. The implicit precondition —
"create a feature branch and commit your work before you finish a unit"
— is **never stated explicitly**. Searching the file: the word "branch"
appears 4 times, none of them as a precondition for starting work; "PR"
and "pull request" are mentioned only as artifacts of the review stage.
The role files describe what each role *produces* but not the basic git
hygiene each role must follow.

When an agent's only signal that "you should be on a branch" comes from
inferred convention rather than an explicit rule, the convention will
sometimes fail to fire. It failed here.

This is the **same failure mode** the postmortem README describes for
the missing "What generalizes" field in postmortems: a load-bearing
expectation lives only in someone's head, not in the rules. The
template's whole premise is that rules in files survive context shifts;
expectations in heads do not.

## Contributing factors

1. **No `.gitignore`.** The repo shipped without one, so `terraform
   init` left ~90 MB of provider binaries in the working tree. If the
   agent *had* run `git add -A && git commit`, the commit would have
   included `terraform/**/.terraform/` — an even worse outcome than
   leaving the work uncommitted.
2. **No pre-commit hook to block direct work on `main`.** The
   template's `.pre-commit-config.yaml.template` exists but is a
   template, not installed by default; no hook prevents committing to
   `main` even if the agent had tried.
3. **The Codespace runs as the user.** Pushing requires no extra
   credential prompt; an agent that *had* tried to push to `main`
   would have succeeded with no friction. The friction-free path
   skipped the safety gates.
4. **Long single session.** The agent that did Phases 2–7 worked
   through six prompts in one go. The session-state cadence rule
   (handoff at ~30 turns) would have triggered a checkpoint — but
   the rule depends on the agent voluntarily checking turn count
   against the threshold, and that check didn't happen.
5. **No automated "did you push?" check.** None of the existing
   `.github/workflows/agent-*.yml` files run on the local working
   tree; they all assume a PR already exists.

## What worked

1. The session-state files were *almost* enough to detect the
   problem: `_active.md` and `latest_summary.md` were stale and
   inconsistent with the working tree, and the new session noticed.
   Without `_active.md`, the bypass might have gone unnoticed for
   another session.
2. The roadmap ([`/.context/roadmap.md`](../../.context/roadmap.md)) gave precise acceptance criteria
   per phase, which let this session verify "the work that exists
   actually meets spec" without re-running it.
3. The deliverables themselves appear to meet acceptance criteria
   on inspection (110 controls, 100 TODOs, 6 modules, etc.). The
   bypass was procedural, not technical. (This claim is itself
   uncited until a reviewer validates it during PR review — flagged
   for human verification.)
4. The dev container's persistent filesystem preserved the work
   long enough for recovery. A more aggressive cleanup policy would
   have lost it.

## What generalizes

**Status**: `Yes`

The root cause is a missing explicit precondition in `AGENTS.md`. Every
repo built from this template inherits the same gap. Any agent reading
[`AGENTS.md`](../../AGENTS.md) for the first time can reasonably conclude that working
directly on `main` is acceptable, because nothing says it isn't.

The fix is template-level, not project-level: add a "Branch and commit
before you finish a unit" rule to `AGENTS.md` §"Work style" in
`mikejmckinney/ai-repo-template`, and back it with an ADR explaining
why the precondition is non-obvious enough to need explicit statement.

### Additional generalizable lessons (added 2026-04-24, post-recovery)

These were surfaced by the prior agent session that performed Phases 2–7
but were not captured in the original postmortem. They generalize beyond
this repo and should inform the template:

1. **`awk -F,` does not honor quoted CSV cells** (universal). The original
   [`scripts/check-ssp.sh`](../../scripts/check-ssp.sh) used `awk -F,`
   and silently missed two of ten written controls (3.1.1, 3.13.1)
   because their descriptions contain commas. Fixed by switching to a
   Python `csv.DictReader` heredoc. **Template implication**: any future
   shell guard over a CSV in any repo will hit this. Worth a one-line
   warning in the template's CI authoring guidance (and a lint rule
   that flags `awk -F,` over `*.csv`).
2. **Cross-check guards belong in the same PR as the second generator**
   (universal). When two artifacts share an invariant (here:
   `controls/nist-800-171-mapping.csv` "full" rows ↔
   [`ssp/SSP.md`](../../ssp/SSP.md) fully-written controls), the CI guard
   enforcing alignment must land with the generator that creates the
   dependency, not bolted on later. Without it, the two artifacts drifted
   silently (CSV had 12 full rows; SSP had 10) until a manual audit
   caught it. **Template implication**: add to the template's
   PR-checklist guidance — "if your PR introduces a generator that
   shares an invariant with another artifact, the cross-check guard
   ships in the same PR."
3. **[`test.sh`](../../test.sh) enforces exact markdown header casing**
   (template-scope). It rejected `## Future improvements` and required
   `## Future Improvements`. Cost a verification cycle. **Template
   implication**: the template ships `test.sh`, so every derived repo
   inherits this constraint. Either document the casing requirement in
   the template's contributor guide or relax `test.sh`'s grep patterns
   to be case-insensitive.

These should fold into the same template-repo follow-up that captures
the branch-precondition rule (see Action items).

## Action items

- [ ] **Add branch/commit precondition to `AGENTS.md` §"Work style"** — owner: @mikejmckinney — issue: TBD (filed against `mikejmckinney/ai-repo-template`, not this repo)
- [ ] **Write ADR-011 (template repo): "Explicit branch precondition for agent work"** — owner: @mikejmckinney — issue: TBD
- [ ] **Add `.gitignore` to template** — owner: @mikejmckinney — issue: TBD (this repo's `.gitignore` from the recovery PR can be the source)
- [ ] **Decide whether to install pre-commit hook by default** that blocks direct commits to `main` — owner: @mikejmckinney — issue: TBD
- [ ] **Consider local `pre-push` or status-check workflow that fires on session end** to detect uncommitted work — owner: @mikejmckinney — issue: TBD (lower priority; the rule + hook combo may be sufficient)
- [ ] **Triage Phase 8 follow-up** (workload module library) — owner: @mikejmckinney — issue: filed in this repo by recovery session
- [ ] **Add CSV/awk warning + cross-check-guard rule to template CI guidance** — owner: @mikejmckinney — issue: TBD (template repo); see "Additional generalizable lessons" 1 & 2
- [ ] **Document or relax `test.sh` markdown header casing** — owner: @mikejmckinney — issue: TBD (template repo); see "Additional generalizable lessons" 3

## References

- Recovery branch: `recovery/phases-1-7-uncommitted-work` (commits `65bdb39` … `53491b9`)
- Recovery handoff: [`/.context/state/handoff_phases-1-7-recovery.md`](../../.context/state/handoff_phases-1-7-recovery.md)
- [`AGENTS.md`](../../AGENTS.md) §"Work style" — where the new rule should land
- [`AGENTS.md`](../../AGENTS.md) §"Session-state cadence" — the rule that was also missed
- [`/.context/roadmap.md`](../../.context/roadmap.md) — phase acceptance criteria
- [`/.context/sessions/latest_summary.md`](../../.context/sessions/latest_summary.md) — updated with Phases 2–7 close-out and bypass note
- Template repo: `mikejmckinney/ai-repo-template` (where the corrective ADR + rule should land)
