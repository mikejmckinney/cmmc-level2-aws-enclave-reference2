# FAQ

> Project FAQ for `cmmc-level2-aws-enclave-reference`. For agent-facing
> instructions see [`AGENTS.md`](../AGENTS.md); for build commands see
> [`AI_REPO_GUIDE.md`](../AI_REPO_GUIDE.md).

## What is this repo?

A reference architecture and partial Terraform implementation for a
minimal CUI enclave in AWS GovCloud, aligned to CMMC 2.0 Level 2 / NIST
SP 800-171 r2. It also ships a parallel deployable demo in commercial
AWS so prospects and reviewers can poke at the architecture without
GovCloud access.

## Does this make my system CMMC-compliant?

No. This repo is a starting point — a credible scaffold, a control
mapping, and an SSP skeleton. CMMC compliance also requires
organizational controls (training, IR plans, personnel screening,
physical security), customer-specific Terraform work (workload modules,
SSO wiring, route tables to TGW/DX, log forwarding), and a real
assessment by a C3PAO. See [`README.md`](../README.md) → "What this repo
does NOT give you".

## Why GovCloud?

Most CUI workloads contractually require AWS GovCloud (US) due to
data-residency, FIPS 140-2/3 endpoint, and FedRAMP High control-set
requirements. The commercial demo exists only to showcase the *shape*
of the architecture; it is not a CUI-suitable environment.

## Can I deploy the demo to my own AWS account?

Yes. Once prompt 05 lands, `terraform/demo/` deploys to commercial AWS
(`us-east-1` by default) with a one-command bring-up and tear-down. The
deploy workflow added in prompt 09 uses GitHub Actions OIDC, not
long-lived keys. Cost is bounded by a nightly auto-destroy schedule and
a $25/month budget alarm.

## Why not deploy the GovCloud root from CI?

GovCloud accounts require US-person validation, separate billing, and
manual onboarding. This repo's maintainer doesn't have one. The
GovCloud root therefore stays `terraform validate`-clean only;
deploying it is the consumer's job. See
[`terraform/govcloud/README.md`](../terraform/govcloud/README.md) (added
in prompt 04) for the bring-up procedure.

## What about FedRAMP / IL4 / IL5?

Out of scope. CMMC L2 maps roughly to FedRAMP Moderate; this repo does
not attempt to overlay FedRAMP-specific paperwork or the higher Impact
Levels. Those would be separate projects.

## Why "Phase 2" deadline urgency?

CMMC 2.0 Phase 2 begins **November 10, 2026**. After that date, many DoD
primes and subs need a Level 2 self-assessment to remain
contract-eligible. Typical remediation timelines are 6–12 months.
Anyone starting after mid-2026 is at material risk of contract impact.
The full launch narrative (prompt 08) develops this in
[`README.md`](../README.md).

## Can I fork this and white-label it for my MSP practice?

Yes — Apache-2.0. Standard attribution rules apply. No warranty.
