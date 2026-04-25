# Drive PR to Merge — Single-invocation review/resolve/merge driver

> **Usage**: Post one of these as a PR comment:
>   - `@claude follow .github/prompts/drive-pr-to-merge.md`
>   - `@copilot follow .github/prompts/drive-pr-to-merge.md`
>
> The agent will execute Phases 0–6 below to drive the PR end-to-end:
> wait for bot reviews → resolve them via `pr-resolve-all.md` → loop
> until quiescent → verify CI → merge under branch protection →
> close out. **You invoke this once per PR.**
>
> This prompt **composes with** `.github/prompts/pr-resolve-all.md`
> (Phase 2 below delegates to it). It does **not** duplicate that
> procedure. The contract between the two prompts is the
> "Stable contract for callers" section in `pr-resolve-all.md` —
> see that section before changing either file.

---

## When to use this

- You authored or rebased a PR and want it driven to merge after bot review.
- The PR is ready: passes local verification, has no known blockers,
  and you've already added any human reviewers you want on it.
- Branch protection on the target branch is configured (this prompt
  uses `gh pr merge --auto`, which **requires** branch protection to
  enforce CI/approval gates).

## When NOT to use this

- The PR has open human review comments — this prompt explicitly
  refuses to merge in that case (Phase 4.5).
- The PR is a draft.
- The PR head is from a fork — the merge step uses tokens that must
  not be exposed on cross-repo PRs.
- You want to inspect the resolve step's output before merging — use
  `pr-resolve-all.md` directly instead.

## Hard rules (apply to every phase)

1. **Never bypass branch protection.** Use `gh pr merge --auto` so
   protected-branch checks still gate the merge.
2. **Never use `--no-verify`** on git operations.
3. **Never resolve human-authored review threads.** Phase 4 of
   `pr-resolve-all.md` is allow-listed to bot identities only;
   re-using its allow-list here is mandatory.
4. **Never merge a PR that has unresolved human review comments.**
   Phase 4.5 below enforces this.
5. **Fork guard**: refuse to operate on cross-repository PRs.
   Run `gh pr view <n> --json isCrossRepository` and abort if true.
6. **Loop bound**: maximum 3 resolve cycles per PR. If the same set of
   findings appears twice in a row, abort and post an escalation
   comment instead of looping further.
7. **Idempotency**: re-invoking this prompt on an already-merged PR
   must detect that in Phase 0 and exit cleanly.

---

## Phase 0 — Preconditions

Run, in order, and abort with a single PR comment if any check fails:

1. `gh pr view <n> --json state,isDraft,isCrossRepository,mergeable,baseRefName,headRefName,labels`
2. **Abort if** `state != "OPEN"` (already merged or closed — exit
   cleanly, this is the idempotency contract).
3. **Abort if** `isDraft == true` (not ready for merge).
4. **Abort if** `isCrossRepository == true` (fork guard, Hard rule 5).
5. **Abort if** branch protection on the base branch cannot be
   verified — `gh api "repos/:owner/:repo/branches/<base>/protection"`
   should return a protection object. If it 404s, post a comment
   warning that auto-merge will not enforce gates and stop. (The
   maintainer can re-invoke after enabling protection.)

If all checks pass, post a one-line "🚀 Driving PR #N to merge" comment
and continue.

## Phase 1 — Wait for bot reviews

The goal is **quiescence**: no new bot review activity for a bounded
window, AND at least one bot has reviewed the latest commit.

**Bot allow-list** (mirrors `pr-resolve-all.md` Phase 4):
- `copilot-pull-request-reviewer[bot]`
- `gemini-code-assist[bot]`
- `chatgpt-codex-connector[bot]`
- `copilot-swe-agent[bot]` (relay-only)
- Any additional bot identity already covered by
  `.github/workflows/agent-relay-reviews.yml`.

**Polling pattern** (use `gh pr view <n> --json reviews,comments`):

1. Record `headRefOid` (the latest commit SHA).
2. Track the timestamp of the most recent bot review or bot review
   comment that references `headRefOid`.
3. Quiescence is reached when **both**:
   - At least one allow-listed bot has reviewed the current
     `headRefOid`, AND
   - No new bot review or comment has appeared in the last 5 minutes.
4. Hard timeout: **15 minutes** total wall-clock time in Phase 1.
   - If at timeout there is at least one bot review on the current
     SHA, proceed to Phase 2 with what's there.
   - If at timeout there is **zero** bot review on the current SHA,
     post an escalation comment explaining no bot reviewed within
     15 minutes and stop. Do **not** merge a PR with no bot review.

Polling cadence: every 60 seconds. Do not busy-loop.

## Phase 2 — Resolve via `pr-resolve-all.md`

Delegate to the canonical resolve procedure:

> **Action**: Execute `.github/prompts/pr-resolve-all.md` Phases 1–4
> against the current PR. Capture the resulting Resolution Report
> comment.

This relies on the "Stable contract for callers" section in
`pr-resolve-all.md`. Specifically, after Phase 2 completes:

- Read the most recent comment with the heading
  `## Resolution Report` posted by the agent.
- Inside it, locate the `### Phase 4 — Thread auto-resolution`
  sub-section.

**Caller success for this cycle** (per the contract):
- Every `ISS-NN` in the Phase 3 status table is `✅ Fixed`,
  `🔁 Already resolved`, `⏭️ Deferred`, or `❌ Won't fix`. Any
  `❓ Cannot reproduce` triggers escalation, not retry.
- Every Phase 4 row is `✅ Resolved`, `⏭️ Skipped`, `🚫 Refused
  (human-authored)`, or `⚠️ Errored` (the relay-fallback workflow
  will retry errored rows).

If the cycle is not successful, abort with an escalation comment
listing the failing rows. Do not merge.

## Phase 3 — Re-check loop

After Phase 2 commits land, bots will often review again. Loop:

```text
cycle = 1
while cycle <= 3:
    re-run Phase 1 (wait for bot reviews on the new headRefOid)
    if no new actionable findings since last cycle:
        break    # quiescent, proceed to Phase 4
    if findings == previous cycle findings:
        # same findings twice in a row = stuck
        abort with escalation comment
    re-run Phase 2 (pr-resolve-all)
    cycle += 1

if cycle > 3:
    abort with escalation comment
```

The cycle counter is the same one tracked in `pr-resolve-all.md`'s
relay-comment fingerprint header (`cycle N/3`).

## Phase 4 — CI verification

Run `gh pr checks <n>`. All required status checks must be `pass`,
`success`, or `neutral`. Any `failure` or `error` aborts with an
escalation comment.

If any check is still `pending` or `in_progress`, wait up to 10
minutes (poll every 60 s). Past 10 minutes, abort with a comment
naming the slow check.

## Phase 4.5 — Human-comment guard (Hard rule 4)

Enumerate review threads on the PR:

```bash
gh api graphql -f query='
  query($n: Int!) {
    repository(owner:"...", name:"...") {
      pullRequest(number: $n) {
        reviewThreads(first: 100) {
          nodes {
            id
            isResolved
            comments(first: 1) { nodes { author { login } } }
          }
        }
      }
    }
  }' -F n=<n>
```

For each thread where `isResolved == false`:
- If the root comment author is in the bot allow-list (Phase 1) and
  Phase 4 marked it `✅ Resolved`, that's fine — it's the auto-resolve
  result.
- If the root comment author is **not** in the bot allow-list, that's
  a human-authored unresolved thread. **Abort.** Post an escalation
  comment listing the unresolved human threads and stop.

## Phase 5 — Merge

```bash
gh pr merge <n> --squash --auto --delete-branch
```

Notes:
- `--auto` means GitHub waits for required checks before merging,
  preserving branch protection. **Do not** use `--merge` without
  `--auto` — that would bypass gates if checks haven't completed.
- `--delete-branch` removes the head branch on merge.
- If `--auto` is rejected (e.g. status checks already complete),
  fall back to `gh pr merge <n> --squash --delete-branch` —
  branch protection still gates this; the only difference is timing.

If the merge command errors:
- `mergeable_state == blocked` — abort and report the blocker.
- Permission errors — abort and request human intervention.
- Anything else — abort, do not retry blindly.

## Phase 6 — Post-merge cleanup

After merge succeeds:

1. Post a final PR comment summarizing what shipped:
   - Issues closed.
   - Cycle count used.
   - Any deferred items.
2. Update `.context/sessions/latest_summary.md` per the AGENTS.md
   close-out cadence (3–5 line entry: what shipped, what was harder
   than expected, what generalizes).
3. If there were deferred items, file follow-up issues.

---

## Worked example

Maintainer comments on PR #42:

> `@copilot follow .github/prompts/drive-pr-to-merge.md`

Agent:
1. Phase 0: PR is open, not draft, not a fork, base branch is
   protected. ✅ Posts "🚀 Driving PR #42 to merge".
2. Phase 1: Polls for 4 minutes, sees gemini + copilot reviews on
   the current SHA, no new activity in 5 minutes. ✅ Quiescent.
3. Phase 2: Invokes `pr-resolve-all.md`. Posts the Index, fixes
   3 findings, posts the Resolution Report with all 3 ISS rows
   `✅ Fixed` and 3 Phase 4 rows `✅ Resolved`. ✅ Cycle 1 success.
4. Phase 3: Bots review the fix commit. One new gemini comment
   appears (medium severity). Cycle 2 runs `pr-resolve-all` again,
   fixes it, all green. ✅ Cycle 2 success. No new findings → exit
   loop.
5. Phase 4: All 12 required checks `pass`.
6. Phase 4.5: Zero unresolved human threads.
7. Phase 5: `gh pr merge 42 --squash --auto --delete-branch` →
   merged, branch deleted.
8. Phase 6: Posts close-out comment, updates
   `.context/sessions/latest_summary.md`.

---

## Anti-patterns (don't do these)

- **Don't fold `pr-resolve-all.md` into this file.** Composition
  is intentional. See the issue #9 plan refinement.
- **Don't bypass Phase 4.5.** A human review comment is a stop sign,
  not a hint.
- **Don't use `--merge` or `--rebase` without `--auto`** unless you
  have explicitly verified all required checks are already green.
- **Don't loop past cycle 3.** Escalate to a human instead.
- **Don't disable branch protection to "make the merge easier."**
  If branch protection is missing, fix that in a separate PR first.
