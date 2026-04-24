# Rules

> Immutable constraints for `cmmc-level2-aws-enclave-reference`. Architect
> owns this directory (see
> [`agent_ownership.md`](agent_ownership.md)). Add a new rule file here
> when a constraint applies repo-wide; document deliberate exceptions
> with an ADR under [`docs/decisions/`](../../docs/decisions/).

## Current rules

| File | Owner | What it constrains |
|---|---|---|
| [`agent_ownership.md`](agent_ownership.md) | PM | Which role may edit which paths. Load-bearing for the multi-agent workflow. |
| [`domain_code_quality.md`](domain_code_quality.md) | Architect | Hard rules H1–H8 (TDD, no silent error swallowing, etc.) and Soft rules S1–S6 with project-specific Terraform/HCL thresholds. |

## Project-specific rule candidates (not yet written)

These would be worth adding once the corresponding code lands; track as
follow-ups, not blockers:

- `domain_terraform.md` — required provider pins, required tags
  (`Environment`, `DataClassification`, `Compliance`), required
  `data.aws_partition.current` usage, ban on hardcoded region/account/ARN
- `domain_compliance.md` — CSV/SSP sync invariants, control-ID format,
  evidence-citation requirements for SSP "Implemented" entries
- `domain_secrets.md` — explicit ban on long-lived AWS keys in workflows
  or `terraform.tfvars` (OIDC-only)
