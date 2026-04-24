# cmmc-level2-aws-enclave-reference

> A reference architecture and partial Terraform implementation for a
> minimal **CUI enclave in AWS GovCloud**, aligned to **CMMC 2.0 Level 2 /
> NIST SP 800-171 r2** — plus a deployable commercial-AWS demo so
> prospects, MSPs, and DIB primes can poke the architecture without
> GovCloud access.

[![terraform-ci](https://github.com/mikejmckinney/cmmc-level2-aws-enclave-reference/actions/workflows/terraform-ci.yml/badge.svg)](.github/workflows/terraform-ci.yml)
[![compliance-checks](https://github.com/mikejmckinney/cmmc-level2-aws-enclave-reference/actions/workflows/compliance-checks.yml/badge.svg)](.github/workflows/compliance-checks.yml)

## Live demo

**Demo URL**: `TODO(demo-url)` — populated after the first
`demo-deploy.yml` run. See [`docs/demo-deploy.md`](docs/demo-deploy.md)
for the bootstrap procedure.

> ⚠️ **Demo only — NOT a CUI environment.** The commercial-AWS demo
> illustrates the architecture's *shape* (VPC, KMS, CloudTrail, IAM
> baseline, workload behind a Function URL). It is not in GovCloud, it
> does not handle CUI, and it must never receive real CUI data. The
> workload page renders a "NOT A CUI ENCLAVE" disclaimer for the same
> reason. The demo is also torn down nightly by
> [`demo-destroy.yml`](.github/workflows/demo-destroy.yml).

## The Phase 2 deadline math

CMMC 2.0 enters **Phase 2** approximately one year after the CMMC Final
Rule effective date of **December 16, 2024** (DoD CMMC program office;
see 32 CFR Part 170, published in the Federal Register on October 15,
2024 — 89 FR 83092). At that point, **Level 2 self-assessment** becomes
a contract requirement for many DoD primes and their subcontractors
handling CUI.

Typical CMMC L2 remediation runs **6–12 months** end-to-end:

1. Gap assessment against NIST 800-171 r2 (4–8 weeks)
2. SSP authoring + POA&M (4–8 weeks)
3. Technical control implementation (3–6 months)
4. Internal pre-assessment + remediation (4–8 weeks)
5. C3PAO assessment scheduling and scoring (4–12 weeks)

**Therefore: organizations starting after May 2026 are at material risk
of contract impact** — ineligibility for new DoD awards, descoping at
re-compete, or restricted FCI/CUI handling on existing contracts.

This repo exists to compress steps 1–3 for the "minimal AWS enclave"
shape that fits a large fraction of small-to-midsize DIB workloads.

## What this repo gives you

- A Mermaid network diagram of a CMMC-L2-aligned enclave
  ([`diagrams/network.md`](diagrams/network.md)).
- Six partition-aware Terraform modules
  ([`terraform/modules/`](terraform/modules/)): `vpc`, `kms`,
  `iam_baseline`, `cloudtrail`, `guardduty`, `config`. All pin
  `terraform >= 1.6` and `aws >= 5.40`. All resolve `arn:aws:...` vs
  `arn:aws-us-gov:...` via `data.aws_partition.current`.
- A GovCloud reference root that `terraform validate`s clean
  ([`terraform/govcloud/`](terraform/govcloud/)) with FIPS endpoints,
  default tags including `DataClassification=CUI`, and `Deny non-FIPS`
  IAM guardrails.
- A live, deployable commercial-AWS demo
  ([`terraform/demo/`](terraform/demo/)) with a Lambda + Function URL
  workload, single-region CloudTrail, and KMS keys for logs/data.
- A 110-control **NIST SP 800-171 r2 → AWS** mapping CSV
  ([`controls/nist-800-171-mapping.csv`](controls/nist-800-171-mapping.csv))
  with a JSON Schema and tally guards: **10 full, 44 partial, 56 none**.
- An SSP skeleton ([`ssp/SSP.md`](ssp/SSP.md)) with **10 of 110
  controls fully written** and the remaining 100 as `TODO` stubs aligned
  to the CSV.
- CI that enforces all of the above
  ([`.github/workflows/`](.github/workflows/)): Terraform fmt/validate/
  tflint/checkov/tfsec, Mermaid lint, CSV schema, SSP guard, CSV↔SSP
  cross-check.

## What this repo does NOT give you

- It is **not a turnkey CMMC L2 enclave.** Client-specific work is
  required (account boundary, identity provider integration, data
  classification policy, workload modules). See
  [`terraform/govcloud/README.md`](terraform/govcloud/README.md) →
  "What you must supply".
- It does **not address organizational controls**: training, incident
  response plans, personnel screening, physical security, governance.
- It does **not constitute legal or compliance advice.** Engage a C3PAO
  or qualified consultant before submitting an assessment.
- It does **not deploy to GovCloud automatically.** The GovCloud root is
  `validate`-only by design; `apply` is left to the operator with their
  own backend, account, and review process.
- The demo URL is **not a CUI environment** under any circumstance.

## Quick start

### Demo (commercial AWS)

```bash
cd terraform/demo
terraform init -backend-config=backend.hcl       # see backend.tf.example
terraform apply -var="state_bucket=<your-bucket>"
# OR
make demo-up
```

After apply, visit the `demo_url` output. Tear down with `make demo-down`
or wait for the nightly `demo-destroy.yml` run (07:00 UTC).

### GovCloud reference (validate only)

```bash
cd terraform/govcloud
terraform init -backend=false
terraform validate
```

To actually apply this against your own GovCloud account, copy
`backend.tf.example` → `backend.tf`, copy `terraform.tfvars.example` →
`terraform.tfvars`, and run a real `terraform plan` / `apply` under your
own change-control process.

## Repository layout

```
terraform/
├── modules/{vpc,kms,iam_baseline,cloudtrail,guardduty,config}/
├── govcloud/   # GovCloud reference root — validate-clean, not applied
└── demo/       # Commercial-AWS deployable demo + Lambda Function URL
controls/       # NIST 800-171 CSV + JSON Schema + README
ssp/            # SSP.md (110 sections, 10 written) + README
diagrams/       # Mermaid diagrams (network + demo pipeline)
scripts/        # gen-controls-csv.py, gen-ssp.py, check-*.{py,sh}
docs/           # FAQ, ADRs, demo-deploy guide, postmortems
.github/
├── prompts/    # Numbered prompt series used to build this repo
└── workflows/  # terraform-ci, compliance-checks, demo-{plan,deploy,destroy}
```

> **`terraform/demo/` is a minimal Lambda Function URL placeholder**, not
> a faithful implementation of the architecture in
> [`diagrams/network.md`](diagrams/network.md). The diagram shows the
> intended production shape (ALB → ECS/Fargate → RDS/EFS/S3 across tiered
> subnets); the demo deploys only the surrounding controls (CloudTrail,
> Config, GuardDuty, KMS, VPC + endpoints, IAM baseline) plus a single
> Lambda so the workload-tier wiring exists end-to-end without the cost
> of a full app stack. A production enclave fork would replace the Lambda
> with the ALB + ECS + RDS stack from the diagram. The demo also serves
> a `Demo only — NOT a CUI enclave` disclaimer string from the Function
> URL.

## For MSPs and consultants

Fork the repo, then:

1. Replace `terraform/govcloud/` with your client's account topology
   (multi-account / Control Tower / etc.). Keep the modules.
2. White-label the README and `ssp/SSP.md` cover.
3. Drive the `controls/` CSV from your existing assessment tool, or
   keep it and let the generator (`scripts/gen-controls-csv.py`) be the
   source of truth. Re-run `scripts/check-controls-csv.py` and
   `scripts/check-ssp.sh` in CI.
4. Treat the SSP `TODO` stubs as a backlog. Fill them per client.

The license (Apache-2.0) permits commercial reuse with attribution.

## For DIBs (in-house)

Recommended sequence:

1. Run a **gap assessment** against NIST 800-171 r2 (use the CSV as a
   starting checklist).
2. Stand up a **dev account** in GovCloud and `terraform plan` the
   `terraform/govcloud/` root against it. Triage what fails to plan in
   your environment (often: SCP, identity, networking pre-reqs).
3. **Fill the SSP** TODOs that match your environment, removing controls
   you handle outside AWS (organizational/physical).
4. Engage a **C3PAO** to scope an assessment 9–12 months before your
   target contract date.
5. Phase the technical implementation against the assessment timeline.

## Limitations

- GovCloud root is `validate`-clean, not `apply`-tested by this repo's
  maintainer.
- Only 10 of 110 SSP controls are fully written; the rest are TODO
  stubs for the implementing org.
- Technical controls only — no organizational/physical control coverage.
- Demo is single-region, single-account, no NAT, no real workload data.

## Future Improvements

- Workload module library (RDS-with-CUI patterns, S3 data-classification,
  ECS task definitions with KMS envelope encryption).
- FedRAMP Moderate / High overlay alongside the NIST 800-171 CSV.
- Multi-account / Control Tower / org-trail automation.
- Expanding the 10 written SSP controls toward full coverage.

## FAQ

See [`docs/FAQ.md`](docs/FAQ.md).

## Disclaimer

This repository is a **reference architecture, not legal or compliance
advice.** It does not by itself make any system CMMC-compliant. There is
no warranty. **Do not place real CUI in the demo environment.** The
commercial-AWS demo URL is not in GovCloud and is not configured for
CUI handling.

## License

Apache-2.0. See [`LICENSE`](LICENSE). Reference-only — see disclaimer
above before relying on any artifact in this repo for an assessment.
