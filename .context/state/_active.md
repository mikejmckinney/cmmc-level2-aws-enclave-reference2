<!-- Schema (rewrite at every task boundary; max ~20 lines):
     Active Task | File | Role | Blockers | Next 1–3 actions.
     Anything else belongs in task_<slug>.md, not here.
     See .context/state/README.md "Cadence" for rules and a worked example. -->

# Active Task

**Active Task**: File tracking issue for 28 ISS items from PR #1 review; open new fix-PR
**File**: PR #1 (recovery — keep scoped to recovery only); new issue + branch TBD
**Role**: PM → DevOps/Backend (handoff after scope decision)
**Branch**: `recovery/phases-1-7-uncommitted-work` (recovery, no further changes); fix branch TBD
**Blockers**: User scope decision pending (recommended split posted to chat)
**Next 1–3 actions**:
1. File tracking issue listing the 28 ISS items (from PR #1 Phase 1 Index comment).
2. Add a comment on PR #1 stating that fixes are deferred to the new issue/PR; recovery PR is for the historical record only.
3. After scope decision, branch off `main` for the fix PR and execute Phase 2 of `pr-resolve-all.md` against the approved subset.
