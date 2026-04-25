#!/usr/bin/env bash
# Validate ssp/SSP.md structure against controls/nist-800-171-mapping.csv.
#
# Checks:
#   1. Number of `#### 3.x.y` headers in SSP == number of data rows in CSV (110)
#   2. Exactly 100 stubs with `Implementation status: TODO`
#   3. Every CSV row with `addressed_by_repo=full` has a non-TODO SSP entry
#   4. CSV `addressed_by_repo` value matches SSP `Implementation status:` per
#      control (full↔Full, partial↔Partial, none↔TODO|Not applicable). Catches
#      drift where the CSV claims more coverage than the SSP narrative supports.
#   5. (csv-ssp-sync runs in the workflow as a separate job)
set -euo pipefail

cd "$(dirname "$0")/.."

CSV=controls/nist-800-171-mapping.csv
SSP=ssp/SSP.md

[ -f "$CSV" ] || { echo "FAIL: missing $CSV"; exit 1; }
[ -f "$SSP" ] || { echo "FAIL: missing $SSP"; exit 1; }

csv_count=$(tail -n +2 "$CSV" | wc -l | tr -d ' ')
ssp_count=$(grep -cE '^#### 3\.[0-9]+\.[0-9]+ ' "$SSP" || true)
if [ "$csv_count" != "$ssp_count" ]; then
  echo "FAIL: CSV row count ($csv_count) != SSP header count ($ssp_count)"
  exit 1
fi

todo_count=$(grep -cE '^\*\*Implementation status:\*\* TODO$' "$SSP" || true)
if [ "$todo_count" != "100" ]; then
  echo "FAIL: expected 100 TODO stubs, got $todo_count"
  exit 1
fi

# Rule 3 — every CSV `full` row must have a non-TODO SSP entry.
# Use Python csv to handle quoted cells (descriptions contain commas).
full_ids=$(python3 - <<'PY'
import csv
with open("controls/nist-800-171-mapping.csv") as fh:
    print(" ".join(r["control_id"] for r in csv.DictReader(fh) if r["addressed_by_repo"] == "full"))
PY
)

fail=0
full_count=0
for cid in $full_ids; do
  full_count=$((full_count + 1))
  block=$(awk -v id="$cid" '
    $0 ~ "^#### " id " " {found=1; n=0}
    found && n<6 {print; n++}
    found && n>=6 {exit}
  ' "$SSP")
  if echo "$block" | grep -qE '^\*\*Implementation status:\*\* TODO$'; then
    echo "FAIL: control $cid is addressed_by_repo=full in CSV but TODO in SSP"
    fail=1
  fi
done

if [ "$fail" != "0" ]; then
  exit 1
fi

# Rule 4 — Detect CSV/SSP overclaim & contradiction. Catches drift where the
# CSV claims more coverage than the SSP narrative supports (or vice versa).
# Allowed combinations:
#   CSV full    → SSP Full | Implemented            (rejects: Partial, TODO, Not applicable)
#   CSV partial → SSP Partial | TODO                (rejects: Full, Implemented, Not applicable — partial-but-written stubs are OK as TODO)
#   CSV none    → SSP TODO  | Not applicable        (rejects: Full, Implemented, Partial)
# `Implemented` is accepted as a synonym for `Full` for backwards-compat with
# the original SSP vocabulary; new entries should prefer `Full`.
mismatches=$(python3 - 2>&1 <<'PY'
import csv, re, sys

allowed = {
    "full":    {"Full", "Implemented"},
    "partial": {"Partial", "TODO"},
    "none":    {"TODO", "Not applicable"},
}

with open("ssp/SSP.md") as fh:
    ssp = fh.read()

ssp_status = {}
current = None
for line in ssp.splitlines():
    m = re.match(r"^#### (3\.\d+\.\d+) ", line)
    if m:
        current = m.group(1)
        continue
    if current and line.startswith("**Implementation status:**"):
        m2 = re.match(r"^\*\*Implementation status:\*\*\s*([^\\]+?)\\?\s*$", line)
        val = m2.group(1).strip() if m2 else line.replace("**Implementation status:**", "").strip().rstrip("\\").strip()
        ssp_status[current] = val
        current = None

bad = []
with open("controls/nist-800-171-mapping.csv") as fh:
    for row in csv.DictReader(fh):
        cid = row["control_id"]
        csv_v = row["addressed_by_repo"]
        ssp_v = ssp_status.get(cid)
        if ssp_v is None:
            bad.append(f"{cid}: missing SSP entry")
            continue
        ok = allowed.get(csv_v, set())
        if ssp_v not in ok:
            bad.append(f"{cid}: CSV={csv_v} but SSP=\"{ssp_v}\" (expected one of: {sorted(ok)})")

for line in bad:
    print(line)
sys.exit(1 if bad else 0)
PY
) || mismatch_fail=1

if [ "${mismatch_fail:-0}" != "0" ]; then
  echo "FAIL: CSV addressed_by_repo / SSP Implementation status drift detected:"
  echo "$mismatches"
  exit 1
fi

echo "OK: $csv_count headers, $todo_count TODO stubs, $full_count fully-written controls present"
