# 06 — NIST 800-171 controls mapping CSV

> Produces `controls/nist-800-171-mapping.csv`: all 110 controls × this
> repo's coverage. Drives the SSP skeleton (prompt `07`) and the
> compliance check (prompt `10`).

## Context

NIST SP 800-171 r2 has 110 security requirements across 14 families
(AC, AT, AU, CM, IA, IR, MA, MP, PE, PS, RA, CA, SC, SI). For a CMMC L2
assessment, every one needs an answer; the answers fall into three buckets
this CSV must distinguish.

## Prerequisites

- `04-terraform-govcloud-root.md` (so the `addressed_by_repo` column is grounded)
- `05-terraform-demo-root.md` (so the demo column is grounded)

## Deliverables

- [ ] `controls/nist-800-171-mapping.csv` with **exactly these columns** in
      this order:

  | column | type | description |
  |---|---|---|
  | `control_id` | e.g., `3.1.1` | Authoritative ID from NIST SP 800-171 r2 |
  | `family` | e.g., `Access Control` | Long family name |
  | `family_code` | e.g., `AC` | Two-letter family code |
  | `control_name` | string | Short title from NIST |
  | `description` | string | One-sentence paraphrase (NOT a copy of NIST text — too long for CSV) |
  | `addressed_by_repo` | enum: `full`, `partial`, `none` | Does the GovCloud root config materially address this? |
  | `aws_services` | semicolon-separated | e.g., `IAM;IAM Identity Center` |
  | `terraform_resources` | semicolon-separated | e.g., `module.iam_baseline;aws_iam_account_password_policy` |
  | `requires_client_config` | bool | Does the client/customer have remaining technical work? |
  | `organizational_control` | bool | Is this fundamentally a policy/process control (training, IR plan, etc.)? |
  | `notes` | string | Caveats, gaps, references; no commas-in-quotes hell — use `;` for in-cell separators |

- [ ] Exactly 110 data rows + 1 header row.
- [ ] Coverage targets (rough — exact counts may shift; document final
      tallies in `controls/README.md`):
  - `addressed_by_repo = full`: ~10–15 (the ones the SSP fully writes up)
  - `addressed_by_repo = partial`: ~30–40 (Terraform helps, client must finish)
  - `addressed_by_repo = none`: remainder
  - `organizational_control = true`: ~25–30 (AT.* family, IR.* plans, PS.*, etc.)
- [ ] `controls/README.md` documenting:
  - Source of truth (NIST SP 800-171 r2 — link)
  - Column definitions (mirror table above)
  - How to update (when Terraform changes, re-evaluate `addressed_by_repo`)
  - Final tallies per `addressed_by_repo` value
- [ ] `controls/schema.json` — JSON Schema describing the CSV row shape; used
      by the CI check in prompt `10`

## Acceptance criteria

- File parses as valid CSV (`python -c "import csv; list(csv.DictReader(open('controls/nist-800-171-mapping.csv')))"` exits 0)
- Header row matches the column list above exactly (order + names)
- Row count == 110 (excluding header)
- All `control_id` values are unique and match the regex `^3\.\d{1,2}\.\d{1,2}$`
- All 14 family codes present: `AC, AT, AU, CM, IA, IR, MA, MP, PE, PS, RA, CA, SC, SI`
- Every `terraform_resources` cell that names a module references one that
  actually exists under `terraform/modules/` or `terraform/govcloud/`

## Verification

```bash
python3 - <<'PY'
import csv, re
rows = list(csv.DictReader(open("controls/nist-800-171-mapping.csv")))
assert len(rows) == 110, f"expected 110 rows, got {len(rows)}"
ids = [r["control_id"] for r in rows]
assert len(set(ids)) == 110, "duplicate control_id"
assert all(re.match(r"^3\.\d{1,2}\.\d{1,2}$", i) for i in ids), "bad control_id format"
fams = {r["family_code"] for r in rows}
assert fams == set("AC AT AU CM IA IR MA MP PE PS RA CA SC SI".split()), fams
print("OK", {k: sum(1 for r in rows if r["addressed_by_repo"]==k) for k in ("full","partial","none")})
PY
```

## Do NOT

- Do NOT copy NIST control text verbatim into the CSV (paraphrase).
- Do NOT mark a control `full` unless prompt `07`'s SSP writes a complete
  implementation statement for it.
- Do NOT use commas inside cells without quoting (prefer `;` separators).
- Do NOT invent Terraform resource names that don't exist; cross-check
  against `terraform/modules/` and `terraform/govcloud/`.

## Truth-hierarchy updates

- `controls/README.md` canonical for the mapping.
- `AI_REPO_GUIDE.md` → "Compliance artifacts" section pointing at the CSV
  and SSP.
