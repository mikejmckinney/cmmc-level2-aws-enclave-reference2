# PR Issue Resolution — Systematic Verify-and-Fix

> **Usage**: Post one of these as a PR comment:
>   - `@claude follow .github/prompts/pr-resolve-all.md`
>   - `@copilot follow .github/prompts/pr-resolve-all.md`
>
> Both agents will read this file and execute the Phase 1–4 procedure below.
> Claude is wired via `.github/workflows/claude.yml`'s `claude-mention` job.
> Copilot follows the `@copilot follow <path>` rule documented in
> `.github/copilot-instructions.md`.
>
> **Phase 4** (auto-resolve bot-authored review threads) runs by default
> on every invocation of this prompt. The per-thread gate (allow-listed
> bot author + Phase 2 status `✅ Fixed` + verification green + thread
> not already resolved) is the only safety mechanism — there is no
> opt-in label. On the Copilot path, the GraphQL mutations may return
> `FORBIDDEN` because the Copilot cloud agent token lacks
> `pull-requests:write` in this repo; in that case, the relay-fallback
> job in `.github/workflows/agent-relay-reviews.yml` re-fires the
> mutations under `CLAUDE_PAT` after parsing the `⚠️ Errored` rows from
> the Phase 4 report table. See ADR-008 for the design.

---

You are resolving every open issue, suggestion, and TODO in this pull request. Your job is to find them all, verify each one, fix the valid ones, and produce a traceable audit trail. Do not guess — verify everything against the actual code.

> **How to run this prompt**: Read this entire file before starting. Execute
> Phase 1, then Phase 2. Execute Phase 4 **before** posting the Phase 3
> Resolution Report so Phase 3 can include the Phase 4 results. Do not
> interleave or skip phases. If your cumulative response would exceed
> GitHub's per-comment size limit, post sequential `Part 1/N`,
> `Part 2/N`, … comments rather than truncating. Apply the Rules section to
> every phase.

## Stable contract for callers

This prompt is invoked directly by humans/agents AND composed into other
prompts (notably `.github/prompts/drive-pr-to-merge.md`). The following
anchors are stable and **MUST** be preserved across edits to this file
so callers can detect success/failure without re-reading the whole
procedure each time.

If you change any of these, bump the version below and update every
caller in the same PR.

**Contract version**: `1.0`

**A. Phase 1 Index comment**
- Posted as a standalone PR comment before any fix commits.
- Heading: `## Issue/Suggestion Index`.
- Each row has a sequential `ISS-NN` ID.

**B. Phase 3 Resolution Report comment**
- Heading: `## Resolution Report` (followed by the Phase 3 sections in
  the example block in this file).
- Includes a per-item status table where every `ISS-NN` has one of the
  statuses defined in Phase 2 Step 5: `✅ Fixed`, `✅ Already resolved`,
  `⚠️ Needs clarification`, `⚠️ Partial fix`, `❌ Not reproducible`,
  `❌ Out of scope`.

**C. Phase 4 Thread auto-resolution table**
- Sub-heading inside the Phase 3 comment:
  `### Phase 4 — Thread auto-resolution`.
- Markdown table with **at minimum** these columns, in this order:
  `Thread | Thread ID | ISS | Author | Action | Notes`.
- `Action` column values are one of: `✅ Resolved`, `⚠️ Errored`,
  `⏭️ Skipped`, `🚫 Refused (human-authored)`.
- `Thread ID` is the GraphQL node ID (`PRRT_…`).

**D. Caller success criteria**
A caller (e.g. `drive-pr-to-merge.md`) treats this prompt as
**successful for one cycle** when **both**:
1. Every `ISS-NN` in the Phase 3 status table has a non-failing
   status (`✅ Fixed`, `✅ Already resolved`, `❌ Not reproducible`,
   or a documented `❌ Out of scope`). `⚠️ Needs clarification` and
   `⚠️ Partial fix` are escalation signals — the caller must abort
   the merge cycle, not retry.
2. Every Phase 4 row is `✅ Resolved`, `⏭️ Skipped`, or
   `🚫 Refused (human-authored)`. `⚠️ Errored` rows are
   acceptable only if the caller knows the relay-fallback workflow
   will retry them (see ADR-008).

**E. Cycle counter**
The relay-comment fingerprint header carries the cycle number:
`📋 **Review Relay (cycle N/3)**`. Maximum 3 cycles per PR; cycle 4+
is an abort signal for callers.

## Phase 1: Build the Issue/Suggestion Index

Scan ALL of these sources for issues, suggestions, requested changes, and TODOs:

1. **PR description** — look for task lists, noted limitations, known issues, "TODO" or "FIXME" mentions.
2. **Review threads** — every unresolved review comment, including inline code comments and top-level review bodies. Pay attention to threads marked "Request changes."
3. **Commit messages** — scan for "TODO", "FIXME", "HACK", "WIP", or "known issue" language.
4. **Code diff** — scan the changed files for new `TODO`, `FIXME`, `HACK`, `XXX`, or `WORKAROUND` comments introduced in this PR.
5. **Linked issues** — if the PR description references GitHub issues (#NNN), read those issues for acceptance criteria that may not be fully met.
6. **CI/workflow failures** — if any checks failed, treat each distinct failure as an indexed item.

**For each item found, assign a sequential ID** (e.g., `ISS-01`, `ISS-02`, ...).

**Always post the index as a standalone PR comment before starting fixes**, regardless of item count. This comment must precede any fix commits and must be distinct from the Phase 3 Resolution Report. **If the PR has more than 10 items**, additionally proceed in batches of 5 to prevent token exhaustion and let the author course-correct early.

**If an item was already addressed** in a subsequent commit or resolved thread: mark it `✅ Already resolved` with a link to the resolving commit, and skip to the next item.

### Index Output Format

Post this as a PR comment before starting fixes:

```markdown
## Issue/Suggestion Index

| ID | Source | Summary | Status |
|----|--------|---------|--------|
| ISS-01 | [Review comment](link) | Missing null check on `user` param | 🔍 Pending |
| ISS-02 | [PR description](link) | TODO: add rate limiting | 🔍 Pending |
| ISS-03 | [Code comment](link) | FIXME in src/auth.ts:42 | 🔍 Pending |
| ISS-04 | [CI failure](link) | TypeScript build error | 🔍 Pending |
| ISS-05 | [Review comment](link) | Suggestion: extract helper fn | ✅ Already resolved in abc1234 |

**Total**: X items found, Y already resolved, Z to address.
Proceeding with fixes for remaining items.
```

## Phase 2: Verify, Fix, Validate Each Item

For each unresolved item, work through this sequence. Do not skip steps.

### Step 1 — Link
Provide a direct URL to where the issue was mentioned (review comment permalink, PR description section, file + line in the diff, or issue number).

### Step 2 — Verify
Confirm the issue actually exists in the current state of the branch. This means:
- For bugs/logic issues: read the relevant code and confirm the problem. If possible, describe a concrete scenario that would trigger it.
- For missing tests: confirm the behavior is untested by searching the test files.
- For style/refactor suggestions: confirm the code matches what the reviewer described.
- For CI failures: read the failure log and identify the root cause.
- If the issue is **not reproducible** (already fixed, reviewer was mistaken, or the code has changed): document why and mark it accordingly. Do not fabricate a fix for a non-issue.

### Step 3 — Fix
If the issue is valid, implement the fix:
- Make the smallest change that addresses the issue.
- Stay inside the files already touched by this PR when possible. If a fix requires changes to files outside the PR's scope, flag it and ask before proceeding.
- For refactor suggestions: apply only if the suggestion is clearly better. If it's a judgment call, implement it but note that the author may want to review.
- Include the exact file path and line numbers in your report.

### Step 4 — Validate
After each fix (or batch of fixes):
- Run the test suite. Report pass/fail counts.
- Run the linter. Report clean/error counts.
- Run the build/typecheck. Report success/failure.
- If the repo has an `AI_REPO_GUIDE.md`, use its commands as canonical. Otherwise, detect from `package.json`, `Makefile`, `pyproject.toml`, etc.
- If a verification command is not available or not applicable, say so explicitly rather than skipping silently.

### Step 5 — Status
Assign one of:
- `✅ Fixed` — issue was valid, fix implemented, verification passed.
- `✅ Already resolved` — issue was already addressed before this run.
- `⚠️ Needs clarification` — issue is ambiguous, or the right fix depends on a design decision the author should make. Describe what's unclear and suggest options.
- `⚠️ Partial fix` — fix addresses part of the issue but something remains. Explain what's left.
- `❌ Not reproducible` — the issue does not exist in the current code. Explain why.
- `❌ Out of scope` — fix requires changes to files/systems outside this PR. Describe what's needed so the author can file a follow-up.

## Phase 3: Resolution Report

After all items are processed, post a final summary comment:

```markdown
## Resolution Report

### Summary
- **Total items found**: X
- **Already resolved**: X
- **Fixed in this pass**: X
- **Needs clarification**: X
- **Not reproducible**: X
- **Out of scope**: X

### Verification
- Tests: ✅ X passed, ❌ X failed
- Lint: ✅ Clean / ❌ X errors
- Build: ✅ Success / ❌ Failed
- Typecheck: ✅ Clean / ❌ X errors

### Detail

---

#### ISS-01: Missing null check on `user` param
- **Source**: [Review comment](link)
- **Evidence**: `src/auth.ts:42` — `user` parameter is used without a null guard. If the session lookup returns null (expired session, deleted user), this throws an unhandled TypeError.
- **Fix**: Added null check with early return of 401 at `src/auth.ts:42-45`. Commit: `abc1234`.
- **Verification**: `npm test` — 47 passed, 0 failed. New test added in `tests/auth.test.ts:89`.
- **Status**: ✅ Fixed

---

#### ISS-02: TODO: add rate limiting
- **Source**: [PR description](link)
- **Evidence**: Confirmed — no rate limiting exists on the `/api/login` endpoint. The TODO in the PR description is a known deferred item.
- **Fix**: N/A — this is a follow-up item, not a bug in the current diff.
- **Verification**: N/A
- **Status**: ❌ Out of scope — recommend filing as a separate issue.

---

(continue for each item)
```

## Phase 4: Resolve bot-authored review threads

Phase 4 runs on every invocation of this prompt — Claude via `.github/workflows/agent-fix-reviews.yml`, Copilot via `@copilot follow` comments posted by `.github/workflows/agent-relay-reviews.yml` or by a human, and any agent invoked through a direct `@claude follow` / `@copilot follow` mention. If you are running this prompt, the gate below applies to you.

Resolve review threads whose backing item cleared Phase 2 with status `✅ Fixed` and whose top-level review comment was authored by an allow-listed bot. The point is to trim noise from CI-only reviewers after the fix has landed — never to silence a human. The per-thread gate below is the only safety mechanism.

### Allow-list (bot reviewers only)

**Normalization rule:** GitHub's REST and GraphQL APIs disagree on bot login formatting — REST returns `gemini-code-assist[bot]`, while GraphQL often returns the same identity as `gemini-code-assist` (no `[bot]` suffix). Before comparing, **strip any trailing `[bot]` from the login** and then compare case-insensitively against the normalized allow-list below. This is the canonical matching rule for Phase 4; apply it whichever API (REST or GraphQL) you sourced the login from. (`.github/workflows/agent-relay-reviews.yml` has separate bot-detection logic that matches on either a `[bot]` suffix **or** a literal allow-regex rather than stripping and normalizing — do not rely on that workflow's matcher as a reference for Phase 4.)

Normalized allow-list (match with `[bot]` stripped and compared case-insensitively):

- `gemini-code-assist`
- `copilot-pull-request-reviewer`
- `copilot` (the Copilot SWE agent; REST returns `Copilot`, GraphQL returns `copilot`)
- `chatgpt-codex-connector`
- `codex` (the shorter form Codex sometimes emits)
- `claude` — **only when the thread's root comment was authored directly by the `claude[bot]` / `claude` identity** (e.g., Claude's auto-review workflow posted the review). If a human opened the thread and `claude[bot]` merely replied (for example because the human wrote `@claude fix this` mid-thread), the root author is the human and Phase 4 must leave the thread open. The per-thread gate below already enforces "root author is allow-listed" — this bullet is a reminder that the root-author test is what keeps human-initiated dialogues from being silenced.

Worked example: a GraphQL-returned author `gemini-code-assist` → strip `[bot]` (no-op) → lowercase → matches `gemini-code-assist` ✅. A REST-returned author `gemini-code-assist[bot]` → strip `[bot]` → `gemini-code-assist` → lowercase → matches ✅.

Threads opened by any other login — including humans, unknown bots, and GitHub Actions user accounts — **must be left open**, even if the corresponding Phase 2 item was fixed.

### Per-thread gate

Resolve a thread only when **all** of the following hold:

1. The thread's root comment was authored by an allow-listed bot.
2. The Phase 2 status for the matching `ISS-NN` item is `✅ Fixed` (never `⚠️`, `❌`, `Already resolved`, or `Needs clarification`).
3. Phase 2 verification passed — tests, lint, build, and typecheck were all green for the batch that contained the fix.
4. The thread is not already resolved (`isResolved == false`).

Note: do **not** skip threads solely because they are `isOutdated`. Phase 4 runs **after** the fix commit is pushed, and a thread's commented line is frequently moved or replaced by that commit, which flips `isOutdated` to `true`. Condition 2 (Phase 2 marked the item `✅ Fixed`) is what guarantees the concern was actually addressed; `isOutdated` is just a side-effect of the fix and is not a blocker. `agent-auto-merge.yml` blocks on `isResolved == false` without considering `isOutdated`, so leaving outdated-but-fixed bot threads unresolved would defeat the entire purpose of Phase 4.

If any condition fails, skip the thread and record why in the Phase 4 log. Do not attempt to resolve threads you did not fix in this run.

### Resolve procedure

For each eligible thread:

1. **Fetch the thread node ID** via the GraphQL `pullRequest.reviewThreads` query. The REST review-comments endpoint does not return the node ID required by `resolveReviewThread`, so GraphQL is mandatory here. Example:

   ```graphql
   query($owner:String!, $repo:String!, $num:Int!) {
     repository(owner:$owner, name:$repo) {
       pullRequest(number:$num) {
         reviewThreads(first:100) {
           nodes {
             id
             isResolved
             isOutdated
             comments(first:1) {
               nodes { author { login } path line databaseId }
             }
           }
         }
       }
     }
   }
   ```

   Paginate if the PR has more than 100 threads.

2. **Post an audit-trail reply** on the thread before resolving, so the resolution is traceable without digging through workflow logs. Use `addPullRequestReviewThreadReply` (GraphQL) or the REST `POST /repos/{owner}/{repo}/pulls/{num}/comments/{comment_id}/replies` endpoint. Reply body format:

   ```
   Resolved by <agent> in <SHORT_SHA> (ISS-NN).
   If this wasn't addressed correctly, re-open the thread.
   ```

   Substitute:
   - `<agent>` — the agent that ran this procedure. **Always backtick-wrap any literal `@`-handle** in the reply body (write `` `@copilot` ``, `` `@claude` ``, `` `@copilot follow ...` `` — not the raw `@copilot` / `@claude` strings). An un-escaped handle in a thread reply is parsed by GitHub as a real mention and re-triggers the bot (Copilot cloud agent on `@copilot`; `.github/workflows/claude.yml`'s `claude-mention` job on `@claude`), which then re-fixes everything you just fixed and posts duplicate Resolution Reports. The top-level trigger comment (`@copilot follow ...` / `@claude follow ...`) stays un-backticked — that's the intended dispatch; the audit reply must not re-dispatch. Use `claude (agent-fix-reviews)` when invoked by `.github/workflows/agent-fix-reviews.yml`, `copilot (via agent-relay-reviews)` when invoked by an `` `@copilot follow` `` comment from `.github/workflows/agent-relay-reviews.yml`, `` claude (`@claude` mention) `` / `` copilot (`@copilot` mention) `` when invoked by a direct human mention, or your own agent name if invoked by other tooling.
   - `<SHORT_SHA>` — the resolving commit SHA (first 7 chars).
   - `ISS-NN` — the ID from your Phase 1 index.

   If you know your fix-cycle number (e.g. the Claude path exposes cycle `N/3`), append `, cycle N/3` after the `ISS-NN` for additional traceability. Omit it if unknown.

3. **Fire the `resolveReviewThread` mutation** with the thread node ID:

   ```graphql
   mutation($id:ID!) {
     resolveReviewThread(input:{threadId:$id}) { thread { id isResolved } }
   }
   ```

   Confirm `isResolved: true` in the response. If the mutation fails, leave the thread open and log the error — do not retry silently.

### Phase 4 report

Because Phase 4 runs **before** Phase 3 posts the Resolution Report (see "How to run this prompt" at the top of this file), include the following section within the Phase 3 Resolution Report itself, listing every thread considered. Do not post Phase 4 as a separate comment. The `Thread ID` column is **required** — it is the GraphQL node ID (`PRRT_…`) that the relay-fallback job in `agent-relay-reviews.yml` parses to retry mutations on the Copilot path; omitting it breaks the fallback.

```markdown
### Phase 4 — Thread auto-resolution

| Thread | Thread ID | ISS | Author | Action | Notes |
|--------|-----------|-----|--------|--------|-------|
| [link](#) | PRRT_kwDOExampleA | ISS-01 | gemini-code-assist[bot] | ✅ Resolved | Fixed in abc1234 |
| [link](#) | PRRT_kwDOExampleB | ISS-02 | copilot-pull-request-reviewer[bot] | ⚠️ Errored | addPullRequestReviewThreadReply returned FORBIDDEN |
| [link](#) | PRRT_kwDOExampleC | ISS-03 | human-reviewer | ⏭️ Skipped | Human-authored — left open |
| [link](#) | PRRT_kwDOExampleD | ISS-04 | gemini-code-assist[bot] | ⏭️ Skipped | Phase 2 status was "Needs clarification" |
```

Use `⚠️ Errored` when the per-thread gate passed but the GraphQL mutation failed (e.g. `FORBIDDEN`). On the Copilot path, the relay-fallback job will pick up `⚠️ Errored` rows by Thread ID, post the audit reply under `CLAUDE_PAT`, and fire `resolveReviewThread`. Use `⏭️ Skipped` only when the per-thread gate failed (human author, status not `✅ Fixed`, etc.) — that signals the fallback to leave the thread alone.

### Safety rules

- **Never resolve a human-authored thread**, even if you fixed what they asked for. Humans expect to click Resolve themselves.
- **Never resolve a thread whose Phase 2 item is not `✅ Fixed`.** "Not reproducible" and "Out of scope" still warrant human acknowledgement.
- **Never resolve a thread without first posting the audit reply.** The reply is the paper trail; resolution without it leaves reviewers guessing.
- **Never include a live `@`-handle in the audit reply body.** Backtick-wrap every `@copilot` / `@claude` / `@copilot follow ...` / `@claude follow ...` reference in the reply so GitHub treats it as code, not a mention. An un-wrapped handle re-dispatches the bot (Copilot cloud agent + `.github/workflows/claude.yml`'s `claude-mention` job both listen for raw `@`-strings anywhere in a PR comment or review reply body) and produces duplicate fix runs. The **top-level trigger comment** that invoked `pr-resolve-all.md` in the first place stays un-backticked — that one is supposed to dispatch.
- **Do not resolve threads from a previous fix cycle.** Scope Phase 4 to items fixed in the current run only — the `ISS-NN` IDs from this run's Phase 1 index are your scope.

## Rules

- **Do not fabricate issues.** Only index things that are explicitly mentioned in the sources listed in Phase 1, or concrete problems you can verify in the code.
- **Do not make drive-by changes.** Fix only what's indexed. If you notice something else while working, note it at the bottom of the report under "Additional Observations" but do not fix it without asking.
- **Do not mark something fixed without verification.** Every `✅ Fixed` must have a passing test/lint/build result.
- **Preserve existing behavior.** Fixes should not change functionality beyond what's needed to resolve the indexed issue.
- **If you run out of context or token budget**: Post what you have so far with a clear "Batch 1 of N complete — proceeding with next batch" marker. Do not silently truncate.
- **If `AI_REPO_GUIDE.md` exists**, read it first for canonical test/lint/build commands and repo conventions.
