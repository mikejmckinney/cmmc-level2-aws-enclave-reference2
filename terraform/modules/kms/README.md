# `kms` module

Creates one KMS Customer Managed Key (CMK) per logical data class declared
in `var.keys`. Each key has annual rotation enabled, a partition-aware
default policy, and an `alias/<prefix>-<name>` alias.

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `name_prefix` | string | — | Alias prefix; aliases are `alias/<prefix>-<key>` |
| `keys` | map(object) | — | Logical key name → `{ description, deletion_window?, additional_users?, additional_admins? }` |
| `tags` | map(string) | `{}` | Applied to every key |

## Outputs

`key_arns`, `key_ids`, `alias_names`, `partition`.

## Default key policy

Every key gets:

1. **Root account permissions** (`kms:*`) — required so an account admin
   can never lose access (AWS guidance).
2. **Optional admin / user statements** — added only when
   `additional_admins` / `additional_users` are non-empty.
3. **`DenyOutsidePartition` deny statement** — denies all KMS operations
   when `aws:ResourceAccount` doesn't match this account. Defense-in-depth
   against cross-account / cross-partition references.

## NIST SP 800-171 r2 controls this module helps satisfy

| Control | Why |
|---|---|
| 3.13.10 — Establish and manage cryptographic keys | KMS CMKs with rotation, scoped policies |
| 3.13.11 — Use FIPS-validated cryptography | KMS in GovCloud is FIPS 140-2 validated; commercial KMS is FIPS 140-2 validated as of 2025 |
| 3.13.16 — Protect confidentiality of CUI at rest | Provides the keys consumed by S3, RDS, EBS, EFS, CloudWatch Logs, etc. |

## Gaps the consumer must fill

- Key grants for cross-account access (intentional out-of-scope).
- KMS multi-region keys (only single-region keys are created here).
- External key store (XKS) integration.
- Per-service key policies for non-default principals (consumer wires via
  `additional_users` / `additional_admins`).
