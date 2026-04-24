# 07 — System Security Plan (SSP) skeleton

> Produces `ssp/SSP.md`: a markdown SSP with all 110 controls listed, 5–10
> fully written, the rest as `TODO:` stubs. Pairs with the CSV from prompt `06`.

## Context

A System Security Plan is the assessor-facing document that says, for each
NIST 800-171 control, *"here is how this system implements the requirement."*
Most consultancies sell SSP authoring as a service; this skeleton seeds the
work and demonstrates what "good" looks like for the controls Terraform
actually implements.

## Prerequisites

- `06-controls-csv.md` complete (CSV is the canonical control list).

## Deliverables

- [ ] `ssp/SSP.md` with this structure:

  ```markdown
  # System Security Plan — <System Name>

  ## 1. System Identification
  ## 2. System Environment           (link to diagrams/network.md)
  ## 3. System Boundary              (CUI authorization boundary description)
  ## 4. Roles and Responsibilities   (TODO stubs)
  ## 5. Control Implementation Statements
     ### 3.1 Access Control (AC)
     #### 3.1.1 — <name>
     **Implementation status:** Implemented | Partial | Planned
     **Responsible role:** ...
     **Implementation:** <prose, 2–6 sentences>
     **Evidence:** <terraform paths, CloudTrail event names, screenshots, etc.>
     ...
  ## 6. Plan of Action and Milestones (POA&M)  (TODO link)
  ## 7. Appendix A — Inherited Controls (AWS shared responsibility)
  ## 8. Appendix B — Glossary
  ```

- [ ] **Fully written** implementation statements for these 10 controls
      (chosen because the Terraform actually implements them):

  | Control | Why fully written |
  |---|---|
  | `3.1.1` Limit system access to authorized users | iam_baseline + IAM Identity Center reference |
  | `3.1.2` Limit access to authorized transactions/functions | IAM policy structure + permission boundary |
  | `3.3.1` Create/retain audit logs | cloudtrail module |
  | `3.3.2` Ensure individual accountability | CloudTrail + IAM identity in events |
  | `3.4.2` Establish baseline configurations | AWS Config + conformance pack |
  | `3.5.3` Use multifactor authentication | iam_baseline password policy + IAM Identity Center MFA |
  | `3.13.1` Monitor/control communications at boundaries | vpc module subnets + SG defaults + flow logs |
  | `3.13.8` Implement cryptographic mechanisms in transit | ALB TLS + VPC endpoints (TLS) |
  | `3.13.11` Use FIPS-validated cryptography | FIPS endpoints + KMS (FIPS 140-2/3 in GovCloud) |
  | `3.14.6` Monitor system for attacks | guardduty module |

  Each must include: implementation status, responsible role, prose
  implementation (2–6 sentences citing **specific** Terraform paths or AWS
  services), and evidence (file paths, event names, console screens).

- [ ] **Stubs** for the remaining 100 controls in this exact format so the
      CI guard in prompt `10` can count them:

  ```
  #### 3.x.y — <name>
  **Implementation status:** TODO
  **Responsible role:** TODO
  **Implementation:** TODO — see controls/nist-800-171-mapping.csv for current Terraform coverage notes.
  **Evidence:** TODO
  ```

- [ ] `ssp/README.md` explaining: SSP purpose, who maintains it, the
      "10 written / 100 TODO" status, how to expand a stub, and a note that
      the SSP must stay in sync with the CSV.

## Acceptance criteria

- All 110 control IDs from the CSV appear as `#### 3.x.y` headers in `SSP.md`,
  in numeric order within each family, families in CSV order
- Exactly 10 controls have `Implementation status:` value other than `TODO`
- Exactly 100 controls have `Implementation status: TODO`
- Each fully-written control cites at least one concrete `terraform/...` path
- No `TODO` appears outside the 100 stub blocks (i.e., section 1–4 and 6–8
  are filled in with at least placeholder content, not the literal word `TODO`)

## Verification

```bash
# Header count matches CSV
csv_count=$(tail -n +2 controls/nist-800-171-mapping.csv | wc -l)
ssp_count=$(grep -cE '^#### 3\.[0-9]+\.[0-9]+ ' ssp/SSP.md)
[ "$csv_count" = "$ssp_count" ] || { echo "mismatch: CSV=$csv_count SSP=$ssp_count"; exit 1; }

# Exactly 100 TODOs
todo_count=$(grep -cE '^\*\*Implementation status:\*\* TODO$' ssp/SSP.md)
[ "$todo_count" = "100" ] || { echo "expected 100 TODO stubs, got $todo_count"; exit 1; }

echo "SSP structure OK"
```

## Do NOT

- Do NOT mark a control `Implemented` if the Terraform doesn't actually
  configure it; downgrade to `Partial` or `Planned`.
- Do NOT paste NIST control text verbatim — paraphrase.
- Do NOT invent evidence (CloudTrail event names, file paths) — verify
  against the actual Terraform.
- Do NOT change the stub format; the CI guard in prompt `10` parses it.

## Truth-hierarchy updates

- `ssp/README.md` canonical for the SSP.
- `controls/nist-800-171-mapping.csv` and `ssp/SSP.md` must agree on
  control IDs and on which 10 are fully addressed.
