# 10 — CI and compliance checks

> Adds the always-on guardrails: terraform fmt/validate/tflint/checkov/tfsec
> on both stacks, mermaid lint, CSV schema check, SSP TODO-count guard.
> Keeps the prompts `01`–`09` work from drifting.

## Context

The repo's value depends on its artifacts staying internally consistent:
the CSV agrees with the SSP, the SSP agrees with the Terraform, the
Terraform parses, the diagram renders. CI enforces all of that on every PR.

## Prerequisites

- All prior prompts (`01`–`09`) ideally complete; CI can be authored
  earlier but the guard scripts need the artifacts to exist to be
  meaningful.

## Deliverables

- [ ] `.github/workflows/terraform-ci.yml`
  - Triggers: `pull_request`, `push` to `main`
  - Matrix: `stack: [govcloud, demo]`
  - Steps per stack: `terraform fmt -check -recursive` →
    `terraform init -backend=false` → `terraform validate` →
    `tflint --recursive` → `checkov -d . --framework terraform --soft-fail`
    → `tfsec . --soft-fail`
  - Also runs `terraform fmt -check -recursive` on `terraform/modules/`
  - Caches `.terraform/` per stack

- [ ] `.github/workflows/compliance-checks.yml`
  - Triggers: `pull_request`, `push` to `main`
  - Jobs:
    1. **mermaid-lint** — `npx -y @mermaid-js/mermaid-cli` renders every
       `.md` containing a Mermaid block under `diagrams/`; fails on parse error
    2. **csv-schema** — runs `scripts/check-controls-csv.py` (provided here)
       which validates `controls/nist-800-171-mapping.csv` against
       `controls/schema.json` and the rules from prompt `06` acceptance
       criteria (110 rows, unique IDs, all 14 families, ID format)
    3. **ssp-todo-guard** — runs `scripts/check-ssp.sh` (provided here)
       which asserts: header count == CSV row count, exactly 100 `TODO`
       statuses, every CSV `addressed_by_repo=full` row has a non-TODO
       SSP entry
    4. **csv-ssp-sync** — asserts the set of control IDs in the CSV equals
       the set of `#### 3.x.y` headers in `ssp/SSP.md`

- [ ] `scripts/check-controls-csv.py` — implements the row count, unique-id,
      family-set, regex, and JSON-schema checks; exits non-zero on failure;
      prints a one-line OK summary on success
- [ ] `scripts/check-ssp.sh` — implements the SSP guards above using
      `grep`/`awk` (no Python dep)
- [ ] `scripts/README.md` — documents both scripts and how to run locally

- [ ] Update root `README.md` (prompt `08` writes the rest) to add CI
      badges for `terraform-ci` and `compliance-checks`

## Acceptance criteria

- `actionlint .github/workflows/*.yml` clean
- Both new workflows run successfully on a clean PR against the artifacts
  produced by prompts `01`–`09`
- `scripts/check-controls-csv.py` and `scripts/check-ssp.sh` runnable
  standalone (`./scripts/check-ssp.sh` exits 0 against valid SSP, exits
  non-zero with a clear message against a known-bad fixture)
- CI total runtime < 5 min on a cold cache (modules are small)

## Verification

```bash
actionlint .github/workflows/terraform-ci.yml \
            .github/workflows/compliance-checks.yml

# Run guards locally
python3 scripts/check-controls-csv.py
bash scripts/check-ssp.sh

# Mermaid lint
for f in diagrams/*.md; do
  npx -y @mermaid-js/mermaid-cli -i "$f" -o "/tmp/$(basename "$f").svg" || exit 1
done
```

## Do NOT

- Do NOT make `checkov` / `tfsec` hard-fail on the GovCloud root — it's a
  reference scaffold and some checks legitimately don't apply (document
  skips in `terraform/govcloud/README.md`).
- Do NOT make the demo deploy workflow (prompt `09`) a required check;
  it's manual-dispatch only.
- Do NOT skip the `csv-ssp-sync` check — it's the only thing that catches
  drift between the two compliance artifacts.
- Do NOT install heavy linters via `apt`; use marketplace actions
  (`hashicorp/setup-terraform`, `terraform-linters/setup-tflint`,
  `bridgecrewio/checkov-action`, `aquasecurity/tfsec-action`).

## Truth-hierarchy updates

- `scripts/README.md` documents the guard scripts.
- `AI_REPO_GUIDE.md` → "CI and verification" section listing the two
  workflows and their guards (this is the one place doc maintenance is
  triggered by adding/removing a CI check).
- `README.md` (prompt `08`) → CI badges.
