# 02 — Scaffold and architecture diagram

> Lays out the directory skeleton and produces the canonical Mermaid network
> diagram. Code lands in `03`–`10`.

## Context

`cmmc-level2-aws-enclave-reference` ships two parallel Terraform stacks
(GovCloud reference + commercial demo) plus compliance artifacts. Establish
the directory shape now so later prompts have somewhere to put files.

## Prerequisites

- `01-init-project.md` complete.

## Deliverables

- [ ] Create the directory skeleton (each dir has a `README.md` describing its
      purpose; empty dirs use `.gitkeep`):

  ```
  terraform/
    modules/                 # shared partition-aware modules (prompt 03)
      vpc/
      iam_baseline/
      kms/
      cloudtrail/
      guardduty/
      config/
    govcloud/                # GovCloud root (prompt 04)
    demo/                    # Commercial-AWS deployable demo (prompt 05)
  controls/                  # NIST 800-171 → AWS mapping CSV (prompt 06)
  ssp/                       # System Security Plan skeleton (prompt 07)
  diagrams/                  # Mermaid diagrams (this prompt)
  docs/
    demo-deploy.md           # filled in prompt 09
  ```

- [ ] Write `diagrams/network.md` containing a Mermaid `flowchart` (or
      `graph LR`) showing:
  - **CUI authorization boundary** (outer dotted box) enclosing everything
    in-scope.
  - **VPC** with three subnet tiers across two AZs:
    - Public subnets → only an Application Load Balancer (no EC2)
    - Private/app subnets → workloads, no public IPs
    - Data subnets → RDS / S3 VPC endpoint / EFS, no internet route
  - **Access patterns**: admin access via **AWS SSM Session Manager** only
    (no bastion, no inbound SSH); user access via ALB + IAM Identity Center
    (or Cognito) with MFA.
  - **VPC endpoints** (Interface): SSM, SSMMessages, EC2Messages, KMS,
    Logs, S3 (Gateway), STS — all FIPS where the partition supports it.
  - **Logging/monitoring plane** (separate logical box): CloudTrail (org
    trail → S3 with KMS + Object Lock), GuardDuty, AWS Config, Security Hub
    (optional), CloudWatch Logs.
  - **Identity plane**: IAM Identity Center / IAM, KMS keys (CMK per data
    class), with arrows showing who-encrypts-what.
  - **External boundary**: legend marking what crosses the boundary
    (admin laptops via SSM, end users via ALB, AWS service traffic via
    VPC endpoints).

- [ ] Add a second smaller Mermaid diagram in the same file showing the
      **deployment pipeline** for the demo: GitHub Actions → AWS OIDC →
      `terraform apply` against the demo account.

- [ ] In `diagrams/README.md`, document how to render the diagrams (VS Code
      Mermaid preview, or `mmdc` CLI) and the convention that any change to
      Terraform topology must update `network.md` in the same PR.

## Acceptance criteria

- All directories above exist with `README.md` or `.gitkeep`.
- `diagrams/network.md` renders as valid Mermaid (no parser errors).
- The diagram explicitly labels the **CUI authorization boundary**.
- `terraform/modules/*/`, `terraform/govcloud/`, `terraform/demo/` are empty
  except for `README.md` (the actual `.tf` files come in prompts `03`–`05`).

## Verification

```bash
# Validate Mermaid (if mmdc installed)
npx -y @mermaid-js/mermaid-cli -i diagrams/network.md -o /tmp/diagram.svg \
  || echo "install @mermaid-js/mermaid-cli to validate locally"

# Structure check
find terraform controls ssp diagrams -maxdepth 2 -type d | sort
```

## Do NOT

- Do NOT write any `.tf` files yet — only `README.md` placeholders.
- Do NOT inline-embed the diagram as a PNG; keep it as Mermaid source.
- Do NOT add Terraform examples to module READMEs that will conflict with
  prompt `03`'s implementation.

## Truth-hierarchy updates

- `.context/00_INDEX.md` → add a "Repository layout" section pointing at the
  new dirs.
- `AI_REPO_GUIDE.md` → update the structure tree.
