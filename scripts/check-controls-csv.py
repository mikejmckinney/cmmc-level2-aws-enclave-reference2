#!/usr/bin/env python3
"""Validate controls/nist-800-171-mapping.csv against schema and rules.

Exits non-zero with a clear message on first failure; prints a one-line
OK summary on success.

Run from repo root:
    python3 scripts/check-controls-csv.py
"""
from __future__ import annotations

import csv
import json
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
CSV_PATH = REPO_ROOT / "controls" / "nist-800-171-mapping.csv"
SCHEMA_PATH = REPO_ROOT / "controls" / "schema.json"

EXPECTED_FAMILY_CODES = {
    "AC", "AT", "AU", "CM", "IA", "IR", "MA", "MP",
    "PE", "PS", "RA", "CA", "SC", "SI",
}
ID_RE = re.compile(r"^3\.\d{1,2}\.\d{1,2}$")
EXPECTED_HEADERS = [
    "control_id", "family", "family_code", "control_name", "description",
    "addressed_by_repo", "aws_services", "terraform_resources",
    "requires_client_config", "organizational_control", "notes",
]


def fail(msg: str) -> None:
    print(f"FAIL: {msg}", file=sys.stderr)
    sys.exit(1)


def main() -> None:
    if not CSV_PATH.exists():
        fail(f"missing {CSV_PATH.relative_to(REPO_ROOT)}")
    if not SCHEMA_PATH.exists():
        fail(f"missing {SCHEMA_PATH.relative_to(REPO_ROOT)}")

    with CSV_PATH.open() as fh:
        reader = csv.DictReader(fh)
        if reader.fieldnames != EXPECTED_HEADERS:
            fail(f"header mismatch.\n  expected: {EXPECTED_HEADERS}\n  got:      {reader.fieldnames}")
        rows = list(reader)

    if len(rows) != 110:
        fail(f"expected 110 rows, got {len(rows)}")

    ids = [r["control_id"] for r in rows]
    if len(set(ids)) != 110:
        dupes = sorted({i for i in ids if ids.count(i) > 1})
        fail(f"duplicate control_id(s): {dupes}")

    bad_ids = [i for i in ids if not ID_RE.match(i)]
    if bad_ids:
        fail(f"control_id values do not match {ID_RE.pattern}: {bad_ids[:5]}")

    fams = {r["family_code"] for r in rows}
    if fams != EXPECTED_FAMILY_CODES:
        fail(f"family_code mismatch.\n  missing: {EXPECTED_FAMILY_CODES - fams}\n  unexpected: {fams - EXPECTED_FAMILY_CODES}")

    # JSON Schema validation per row.
    try:
        from jsonschema import Draft7Validator
    except ImportError:
        fail("jsonschema not installed; run `pip install jsonschema`")

    schema = json.loads(SCHEMA_PATH.read_text())
    validator = Draft7Validator(schema)
    errors: list[str] = []
    for i, row in enumerate(rows, start=2):  # start=2: row 1 is header
        for err in validator.iter_errors(row):
            errors.append(f"  row {i} ({row.get('control_id', '?')}): {err.message}")
    if errors:
        fail("schema validation failed:\n" + "\n".join(errors[:20]))

    tallies = {k: sum(1 for r in rows if r["addressed_by_repo"] == k) for k in ("full", "partial", "none")}
    print(
        f"OK: {len(rows)} rows, {len(EXPECTED_FAMILY_CODES)} families, "
        f"addressed_by_repo={tallies}"
    )


if __name__ == "__main__":
    main()
