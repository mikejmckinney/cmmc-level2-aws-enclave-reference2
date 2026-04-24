# System Security Plan

[`SSP.md`](./SSP.md) is the canonical artifact: the assessor-facing
description of how this enclave implements each of the 110 NIST SP 800-171 r2
security requirements.

## Status

- **10** controls have fully-written implementation statements
  (`Implementation status: Implemented` or `Partial`).
- **100** controls are parser-stable `TODO` stubs.

The 10 written controls are exactly those for which the Terraform in this
repository materially implements the requirement; see prompt
[`07-ssp-skeleton.md`](../.github/prompts/07-ssp-skeleton.md) for the
selection rationale.

## Who maintains this

The system owner. SSP authoring is the customer's responsibility; the
skeleton in this repo is reference scaffolding, not a turnkey artifact.
Plan to:

- Spend ~1–2 weeks of a security engineer's time filling in the 100 stubs.
- Re-run [`scripts/gen-ssp.py`](../scripts/gen-ssp.py) any time you regenerate
  the controls CSV (the SSP keys off it).
- Track every `Partial` and `Planned` status in the POA&M.

## How to expand a stub

Each stub follows this exact format (the format is parsed by the CI guard
in [`.github/prompts/10-ci-and-compliance-checks.md`](../.github/prompts/10-ci-and-compliance-checks.md)):

```markdown
#### 3.x.y — <name>
**Implementation status:** TODO
**Responsible role:** TODO
**Implementation:** TODO — see controls/nist-800-171-mapping.csv for current Terraform coverage notes.
**Evidence:** TODO
```

To expand:

1. Replace `Implementation status: TODO` with `Implemented`, `Partial`, or `Planned`.
2. Replace `Responsible role: TODO` with the role from §4 of `SSP.md`.
3. Replace the `Implementation: TODO …` line with 2–6 sentences citing the **specific** Terraform paths or AWS services that implement the control.
4. Replace `Evidence: TODO` with concrete artifacts: `terraform/...` paths, CloudTrail event names, AWS Console screens, AWS Artifact reports.

If you change `Implementation status` away from `TODO` for a control, also
update [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv)
(`addressed_by_repo` column) so the two artifacts stay aligned. The CI
guard in prompt 10 enforces the row-count and stub-count invariants.

## Regenerating

```bash
python3 scripts/gen-ssp.py
```

This rewrites `SSP.md` from scratch using the CSV + the inline `WRITTEN`
table inside the script. **Do not hand-edit `SSP.md`** to add new written
controls — instead, add the entry to `WRITTEN` in the script and re-run.
That keeps the "10 written / 100 TODO" invariant under version control.
