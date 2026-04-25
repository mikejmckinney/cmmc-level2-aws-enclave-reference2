# Coordination Board

> **Purpose**: Live claim board for parallel multi-agent work. Every role reads this before editing and appends a lock before starting. The **Project Manager** agent is the authoritative editor beyond self-claims.

## How to Use

1. **Before editing**: read this file and `rules/agent_ownership.md`. If any active lock overlaps your intended paths, stop and escalate to PM.
2. **Claim**: append a new lock block under "Active Locks" using the template below.
3. **Release**: when your task is done or handed off, move your block to "Recent History" with a result line. PM prunes history periodically.

## Task States

Every `task_*.md` file lives in exactly one of these states. Transitions are one-way (no skipping). The "Gate" column says what must be true to advance; the "Owner" column says which role performs the transition.

| State                | Gate to advance                                       | Owner of transition |
|----------------------|-------------------------------------------------------|---------------------|
| `analyzing`          | Analysis complete + Analyst handoff to Architect/PM   | Analyst             |
| `backlog`            | Architect plan exists + Judge plan-gate APPROVE       | PM                  |
| `planned`            | Role assigned + task file created + lock claimed      | PM                  |
| `assigned`           | Implementer starts work + sets `Status: in-progress`  | Implementer         |
| `in_progress`        | Implementation complete + tests added                 | Implementer         |
| `peer_review`        | QA coverage check + Critic subjective review          | QA / Critic         |
| `judge_review`       | Judge diff-gate APPROVE                               | Judge               |
| `approved`           | Branch merged to main                                 | PM                  |
| `merged`             | PM decides: done or stakeholder review                | PM                  |
| `stakeholder_review` | Feedback captured + PM routes to next iteration       | PM                  |

### Transition rules

- **No skipping**: a task in `in_progress` cannot jump to `judge_review` without passing through `peer_review`.
- **Reversible**: any reviewer (QA, Critic, Judge) may kick a task back to `in_progress` with `REQUEST_CHANGES`. Record the reason in the task file before the kickback.
- **Stakeholder review is optional**: after `merged`, PM decides whether to enter `stakeholder_review` or move the task directly to done (Recent History). Small fixes, dependency bumps, and maintenance tasks typically skip this state.
- **Stakeholder review is terminal**: `stakeholder_review` closes out the original task — once feedback is captured, the task file moves to Recent History. Any follow-up work becomes *new* `task_*.md` entries: routed to Analyst (entering `analyzing`) if assumptions need re-validation, or placed directly into `backlog` if the feedback is design-only and goes straight to Architect. New entries are created using `.context/state/feedback_template.md`.
- **Stuck detection**: any state other than `merged` or `stakeholder_review` held for > 24 hours is a "stuck" signal. PM should investigate on the next session or via the optional heartbeat workflow (`.github/workflows/agent-heartbeat.yml.template`).

## Lock Template

```markdown
## Lock: <task-id>
**Role**: <analyst|architect|frontend|backend|pm|qa|devops|docs|critic|judge>
**Session**: <branch name or agent session id>
**Claimed At**: <ISO-8601>
**Expected Duration**: <e.g., 30m, 2h>
**Paths**:
- <glob or file>
**Depends On**: <task-id or 'none'>
**Blocks**: <task-id or 'none'>
**State**: analyzing | backlog | planned | assigned | in_progress | peer_review | judge_review | approved | merged | stakeholder_review
```

## Active Locks

## Lock: pr-7
<!-- managed-for-pr:7 -->
**Role**: backend
**Session**: fix/pr7-tfsec-hardening
**Claimed At**: 2026-04-25T00:29:49Z
**Expected Duration**: TBD
**Paths**:
- terraform/demo/.tfsec/config.yml
- terraform/demo/main.tf
- terraform/govcloud/main.tf
- terraform/modules/cloudtrail/main.tf
- terraform/modules/config/main.tf
- terraform/modules/vpc/main.tf
- terraform/modules/vpc/variables.tf
**Depends On**: none
**Blocks**: none
**State**: in_progress

## Lock: pr-5
<!-- managed-for-pr:5 -->
**Role**: backend
**Session**: fix/pr5-fips-and-csv-reconcile
**Claimed At**: 2026-04-24T22:28:50Z
**Expected Duration**: TBD
**Paths**:
- controls/nist-800-171-mapping.csv
- scripts/check-ssp.sh
- scripts/gen-controls-csv.py
- terraform/modules/iam_baseline/main.tf
- terraform/modules/iam_baseline/variables.tf
- terraform/modules/iam_baseline/README.md
**Depends On**: none
**Blocks**: none
**State**: in_progress

## Lock: pr1-fix-critical-and-trivial
**Role**: devops
**Session**: branch `fix/pr1-critical-and-trivial`
**Claimed At**: 2026-04-24
**Expected Duration**: 1 session
**Paths**:
- `terraform/modules/kms/**`
- `terraform/modules/cloudtrail/main.tf`
- `terraform/govcloud/main.tf`
- `terraform/demo/main.tf`
- `.github/workflows/demo-plan.yml`
- `.github/prompts/03-terraform-shared-modules.md`
- `diagrams/network.md`
- `.context/state/coordination.md`
**Depends On**: PR #1 (recovery — base for branch); issue #3 (defines scope)
**Blocks**: none
**State**: in_progress

## Recent History

<!-- Completed/released locks go here for 1-2 days, then PM prunes. -->

## Blocked / Waiting

<!-- Tasks that cannot proceed until a dependency clears. PM maintains this section. -->

## PM Notes

<!-- PM uses this area for dispatch rationale, sequencing decisions, and cross-role conflict resolutions. -->
