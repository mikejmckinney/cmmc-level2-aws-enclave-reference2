#!/usr/bin/env bash
# Validate ssp/SSP.md structure against controls/nist-800-171-mapping.csv.
#
# Checks:
#   1. Number of `#### 3.x.y` headers in SSP == number of data rows in CSV (110)
#   2. Exactly 100 stubs with `Implementation status: TODO`
#   3. Every CSV row with `addressed_by_repo=full` has a non-TODO SSP entry
#   4. (csv-ssp-sync runs in the workflow as a separate job)
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

echo "OK: $csv_count headers, $todo_count TODO stubs, $full_count fully-written controls present"
