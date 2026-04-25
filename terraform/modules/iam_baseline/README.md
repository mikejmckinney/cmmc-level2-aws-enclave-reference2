# iam_baseline

Account-level IAM hardening for the CUI enclave.

## What it creates

- **Account password policy** (`aws_iam_account_password_policy`) — minimum 14 chars, complexity required, 90-day max age, 24-password reuse prevention.
- **IAM Access Analyzer** (account scope) — surfaces external/cross-account access.
- **DenyNonFipsEndpoints managed policy** *(optional, default on)* — three-statement Deny policy that enforces FIPS-validated endpoints:
  1. `DenyNonFipsRegions` — `aws:RequestedRegion` must be in `var.fips_allowed_regions` (default: `us-gov-west-1`, `us-gov-east-1`). GovCloud regions serve FIPS-validated endpoints by default for every service; this is the primary enforcement mechanism.
  2. `DenyPlaintextTransport` — `aws:SecureTransport=true` (defense-in-depth).
  3. `DenyTlsBelow12` — `s3:TlsVersion >= 1.2` (defense-in-depth on the S3 data plane).

  Uses `StringNotEqualsIfExists` for the region check, so calls that omit `aws:RequestedRegion` are also denied (all GovCloud services use regional endpoints). Intended to be attached as a permission boundary on workload roles or promoted to an SCP at the org level. **Set `attach_deny_non_fips = false` in the demo root** because commercial AWS endpoints will trip the deny.

## Controls satisfied (NIST SP 800-171 r2)

| Control | How |
|---|---|
| 3.5.3 | MFA enforcement is downstream of this module (root account / IdP). Password policy + Access Analyzer are prerequisites. |
| 3.5.7 | Password complexity (`minimum_password_length >= 14`, all character classes required). |
| 3.5.8 | Password reuse prevention (`password_reuse_prevention = 24`). |
| 3.13.8 | DenyNonFipsEndpoints enforces TLS in transit (`aws:SecureTransport`) and region-based FIPS endpoint selection. |
| 3.13.11 | DenyTlsBelow12 enforces FIPS-validated TLS 1.2+ for S3. Combined with GovCloud's FIPS endpoints (enforced by DenyNonFipsRegions), satisfies FIPS 140-2 in transit. |

## Variables

See `variables.tf`. Key knobs:

- `minimum_password_length` (default `14`, validated `>= 14`)
- `max_password_age` (default `90`)
- `password_reuse_prevention` (default `24`)
- `attach_deny_non_fips` (default `true`; set `false` for commercial demo)
- `fips_allowed_regions` (default `["us-gov-west-1", "us-gov-east-1"]`)

## Outputs

`password_policy_id`, `access_analyzer_arn`, `deny_non_fips_policy_arn` (null when disabled), `partition`.
