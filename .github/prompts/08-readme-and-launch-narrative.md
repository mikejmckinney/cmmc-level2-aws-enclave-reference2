# 08 — README and launch narrative

> Replace the project-stub README with the real launch document. This is
> the page prospects, MSPs, and DIBs will read first.

## Context

CMMC 2.0 Phase 2 begins **November 10, 2026** (per Greypike analysis), at
which point Level 2 self-assessment becomes a contract requirement for many
DoD primes and subs. Remediation timelines (gap assessment → SSP → POA&M →
control implementation → assessment) routinely take 6–12 months. Anyone
starting after mid-2026 is already late. This README must make that math
unmissable.

## Prerequisites

- Prompts `01`–`07` complete.
- Prompts `09` (demo deploy URL) and `10` (CI badges) ideally complete, but
  this README can be drafted with placeholders and the URLs/badges added in
  a small follow-up commit.

## Deliverables

Replace `README.md` with sections in this order:

- [ ] **Headline + 1-sentence pitch**
      *"A reference architecture and partial Terraform implementation for a
      minimal CUI enclave in AWS GovCloud, aligned to CMMC 2.0 Level 2 /
      NIST SP 800-171 r2."*

- [ ] **Live demo** — link to the deployed commercial-AWS demo URL (from
      prompt `05`/`09`); badge for CI status; loud
      "**Demo only — not a CUI environment**" caption

- [ ] **The Phase 2 deadline math** — short section:
  - Phase 2 starts **November 10, 2026** (cite Greypike — use placeholder
    `TODO(citation): <Greypike report URL>` if exact source not yet on hand)
  - Typical CMMC L2 remediation: 6–12 months end-to-end
  - Therefore: organizations starting after **May 2026** are at material
    risk of contract impact
  - Cost of delay: ineligibility for new DoD awards, descoping from
    existing contracts at re-compete, FCI/CUI handling restrictions

- [ ] **What this repo gives you** — bulleted:
  - Mermaid network diagram of a CMMC-L2-aligned enclave (`diagrams/network.md`)
  - Six partition-aware Terraform modules (`terraform/modules/`)
  - GovCloud root that `terraform validate`s clean (`terraform/govcloud/`)
  - A live, deployable commercial-AWS demo (`terraform/demo/`)
  - 110-control NIST 800-171 → AWS mapping CSV (`controls/`)
  - SSP skeleton with 10 controls fully written (`ssp/SSP.md`)

- [ ] **What this repo does NOT give you** — equally explicit:
  - It is not a turnkey enclave; client-specific work is required (see
    `terraform/govcloud/README.md` "What you must supply")
  - It does not address organizational controls (training, IR plans,
    personnel screening, physical security)
  - It does not constitute legal or compliance advice
  - It does not deploy or apply to GovCloud automatically

- [ ] **Quick start** — both stacks, with a single command each
- [ ] **Repository layout** — short tree
- [ ] **For MSPs/consultants** — short section on how to fork, customize,
      and white-label
- [ ] **For DIBs** — short section on what to do next (run a gap
      assessment, fill the SSP TODOs, engage a C3PAO)
- [ ] **Limitations**, **Future improvements**, **FAQ** (link to `docs/FAQ.md`)
- [ ] **Disclaimer** — same paragraph added in prompt `01`
- [ ] **License** — Apache-2.0 (link to `LICENSE`)

## Acceptance criteria

- README is 200–500 lines (substantive, not a wall of text)
- "November 10, 2026" appears at least once
- "Greypike" appears at least once with a citation marker (URL or
  `TODO(citation)` placeholder)
- Live demo URL or `TODO(demo-url)` placeholder present
- All five hard sections (deadline math, what you get, what you don't,
  quick start, disclaimer) are present
- No `TEMPLATE_PLACEHOLDER` strings remain
- Markdown lints clean (`markdownlint README.md`, optional)

## Verification

```bash
grep -q "November 10, 2026" README.md
grep -q -i "greypike" README.md
grep -q "Apache-2.0\|Apache License" LICENSE
grep -q "NOT a CUI" README.md  # case sensitivity — adjust as needed
wc -l README.md  # expect 200-500
```

## Do NOT

- Do NOT overstate compliance — the repo is a reference, not an
  attestation.
- Do NOT invent a Greypike URL; mark it `TODO(citation)` if unknown.
- Do NOT bury the deadline math below the fold; it's the value prop.
- Do NOT remove the disclaimer paragraph from prompt `01`.

## Truth-hierarchy updates

- `README.md` is canonical for project marketing/quick-start.
- `docs/FAQ.md` should be in sync (any FAQs in README that contradict it
  → fix `docs/FAQ.md` in the same PR).
- `AI_REPO_GUIDE.md` → "Project pitch" link to README.
