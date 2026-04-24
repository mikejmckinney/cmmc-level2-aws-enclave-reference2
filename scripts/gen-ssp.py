#!/usr/bin/env python3
"""Generate ssp/SSP.md from the controls CSV.

10 controls get fully-written implementation statements (inline below);
the remaining 100 get TODO stubs in a parser-stable format.

Run from repo root:
    python3 scripts/gen-ssp.py
"""
from __future__ import annotations

import csv
from collections import defaultdict
from pathlib import Path
from textwrap import dedent

REPO_ROOT = Path(__file__).resolve().parent.parent
CSV_PATH = REPO_ROOT / "controls" / "nist-800-171-mapping.csv"
OUT = REPO_ROOT / "ssp" / "SSP.md"

# control_id -> (status, role, implementation, evidence)
WRITTEN: dict[str, tuple[str, str, str, str]] = {
    "3.1.1": (
        "Partial",
        "Cloud Security Engineering; IdP Administrators",
        "Account-level access enforces a minimum 14-character password policy and AWS IAM Access Analyzer is enabled, "
        "both via the `iam_baseline` Terraform module instantiated in `terraform/govcloud/main.tf`. Human users access "
        "the enclave through IAM Identity Center federated to the corporate IdP; only named, authenticated principals "
        "receive permission sets. Workload identities use IAM roles assumed by EC2/ECS/Lambda — no static IAM users "
        "are created by this configuration.",
        "`terraform/govcloud/main.tf` (`module.iam_baseline`); `terraform/modules/iam_baseline/main.tf` "
        "(`aws_iam_account_password_policy.this`, `aws_accessanalyzer_analyzer.account`); CloudTrail "
        "`AssumeRoleWithSAML` events; IAM Identity Center assignments report.",
    ),
    "3.1.2": (
        "Partial",
        "Cloud Security Engineering",
        "Authorized transactions are constrained by IAM permission boundaries and (when an organization is in use) "
        "Service Control Policies. The `DenyNonFipsEndpoints` managed policy created by `module.iam_baseline` is "
        "intended for attachment as a permission boundary in GovCloud (`var.attach_deny_non_fips = true`), denying "
        "any API call that did not traverse a FIPS endpoint or used TLS below 1.2. Workload roles are scoped to the "
        "specific actions and resources their function requires.",
        "`terraform/modules/iam_baseline/main.tf` (`aws_iam_policy.deny_non_fips`); CloudTrail `userIdentity` plus "
        "`requestParameters` showing endpoint host; IAM permission boundary attachments per role.",
    ),
    "3.3.1": (
        "Implemented",
        "Cloud Security Engineering; SecOps",
        "A multi-region CloudTrail trail captures all management events to a KMS-encrypted S3 bucket with Object Lock "
        "GOVERNANCE retention (default 7 years) and to a KMS-encrypted CloudWatch Logs group. The `cloudtrail` module "
        "additionally provisions metric filters for `RootAccountUsage`, `IAMPolicyChange`, `ConsoleSignInWithoutMFA`, "
        "and `KMSKeyDisableOrDelete` under the `CMMC/CloudTrail` namespace, ready for SNS-backed alarms.",
        "`terraform/modules/cloudtrail/main.tf` (`aws_cloudtrail.this`, `aws_s3_bucket_object_lock_configuration.trail`, "
        "`aws_cloudwatch_log_metric_filter.this`); S3 bucket name from `module.cloudtrail.log_bucket_name`; "
        "CloudWatch metric `CMMC/CloudTrail/RootAccountUsage`.",
    ),
    "3.3.2": (
        "Implemented",
        "SecOps",
        "Every CloudTrail record contains a `userIdentity` block (principal type, ARN, MFA flag, source IP, user "
        "agent). Combined with the named-principal model from control 3.1.1 (no shared accounts, federated SSO), this "
        "provides individual accountability for every API action. Trail integrity is protected by log-file validation "
        "digest files and by the Object-Locked S3 bucket.",
        "`terraform/modules/cloudtrail/main.tf` (`aws_cloudtrail.this.enable_log_file_validation = true`); sample "
        "CloudTrail event JSON with `userIdentity.arn`; S3 digest objects under `AWSLogs/<account>/CloudTrail-Digest/`.",
    ),
    "3.4.2": (
        "Partial",
        "Cloud Security Engineering",
        "AWS Config records configuration baselines for every supported resource via `module.config`, with delivery to "
        "a KMS-encrypted S3 bucket and global resource recording enabled in the primary region. The configuration "
        "supports an optional NIST 800-171 Conformance Pack via `var.config_conformance_pack_template_body`; clients "
        "supply the YAML body from `awslabs/aws-config-rules` so license terms remain explicit.",
        "`terraform/modules/config/main.tf` (`aws_config_configuration_recorder.this`, "
        "`aws_config_conformance_pack.nist_800_171`); Config delivery bucket from `module.config.delivery_bucket_name`.",
    ),
    "3.5.3": (
        "Partial",
        "IdP Administrators; Cloud Security Engineering",
        "AWS-side prerequisites for MFA — strong password policy, IAM Access Analyzer for over-permissioned roles, "
        "and the `DenyNonFipsEndpoints` permission boundary — are provisioned by `module.iam_baseline`. Multifactor "
        "authentication itself is enforced at the corporate IdP / IAM Identity Center; phishing-resistant factors "
        "(WebAuthn / FIDO2) are required for any role that has privileged access to the enclave account.",
        "`terraform/modules/iam_baseline/main.tf` (`aws_iam_account_password_policy.this`); IAM Identity Center MFA "
        "policy export; IdP factor-enforcement policy.",
    ),
    "3.13.1": (
        "Partial",
        "Cloud Network Engineering",
        "The enclave VPC has three subnet tiers (public, private, data) across three AZs in GovCloud. The data tier "
        "has no NAT route. Eight Interface VPC endpoints (SSM, SSMMessages, EC2Messages, KMS, Logs, Monitoring, STS, "
        "EC2) plus S3 and DynamoDB Gateway endpoints keep AWS API traffic on the AWS backbone. VPC Flow Logs deliver "
        "to a KMS-encrypted CloudWatch Logs group with the configured retention.",
        "`terraform/modules/vpc/main.tf` (`aws_subnet.{public,private,data}`, `aws_vpc_endpoint.{interface,s3,dynamodb}`, "
        "`aws_flow_log.this`); flow log group name from `module.vpc.flow_log_group_name`.",
    ),
    "3.13.8": (
        "Implemented",
        "Cloud Security Engineering",
        "All AWS API traffic is TLS by default; the `DenyNonFipsEndpoints` managed policy from `module.iam_baseline` "
        "(active in GovCloud via `attach_deny_non_fips = true`) denies any request without `aws:SecureTransport=true`. "
        "A companion statement (`DenyNonTLSv12`) denies S3 requests under TLS 1.2. The CloudTrail and AWS Config "
        "delivery buckets carry an additional `DenyInsecureTransport` bucket policy as defense-in-depth.",
        "`terraform/modules/iam_baseline/main.tf` (`aws_iam_policy.deny_non_fips`); `terraform/modules/cloudtrail/main.tf` "
        "(`data.aws_iam_policy_document.trail_bucket` -> `DenyInsecureTransport`); `terraform/modules/config/main.tf` "
        "(matching deny on Config delivery bucket).",
    ),
    "3.13.11": (
        "Implemented",
        "Cloud Security Engineering",
        "The GovCloud provider sets `use_fips_endpoint = true` (`terraform/govcloud/providers.tf`), routing every "
        "AWS API call through FIPS-validated endpoints. AWS KMS in GovCloud uses FIPS 140-2 validated HSMs; all data "
        "CMKs are KMS-managed (no imported key material) with annual rotation enabled by `module.kms`. The "
        "`DenyNonTLSv12` statement enforces TLS 1.2+ for S3 (FIPS-approved cipher suites only).",
        "`terraform/govcloud/providers.tf` (`use_fips_endpoint = true`); `terraform/modules/kms/main.tf` "
        "(`aws_kms_key.this.enable_key_rotation = true`); AWS KMS FIPS 140-2 module attestation in AWS Compliance "
        "Reports (Artifact).",
    ),
    "3.14.6": (
        "Implemented",
        "SecOps",
        "Three independent detection sources are wired by Terraform: (1) GuardDuty detector with all features enabled "
        "via `module.guardduty` (defaults: S3 events, EKS audit + runtime, EBS malware, RDS, Lambda); (2) CloudTrail "
        "metric filters from `module.cloudtrail` for high-signal actions; (3) VPC Flow Logs to CloudWatch from "
        "`module.vpc`. Findings publish every 15 minutes by default.",
        "`terraform/modules/guardduty/main.tf` (`aws_guardduty_detector.this`, `aws_guardduty_detector_feature.this`); "
        "`terraform/modules/cloudtrail/main.tf` (`aws_cloudwatch_log_metric_filter.this`); GuardDuty findings export "
        "via EventBridge to ticketing.",
    ),
}


def main() -> None:
    rows = list(csv.DictReader(CSV_PATH.open()))
    assert len(rows) == 110

    # Group by family preserving the order they appear in the CSV.
    by_family: dict[str, list[dict]] = defaultdict(list)
    family_order: list[tuple[str, str]] = []
    for r in rows:
        key = (r["family_code"], r["family"])
        if key not in family_order:
            family_order.append(key)
        by_family[r["family_code"]].append(r)

    OUT.parent.mkdir(parents=True, exist_ok=True)

    written = sum(1 for r in rows if r["control_id"] in WRITTEN)
    assert written == 10, f"expected 10 written controls, got {written}"

    parts: list[str] = []
    parts.append(dedent("""\
        # System Security Plan — CMMC L2 / NIST 800-171 r2 CUI Enclave (Reference)

        > **Status:** Reference skeleton. 10 of 110 controls have fully-written
        > implementation statements (those for which the Terraform in this
        > repository materially implements the control). The remaining 100 are
        > parser-stable `TODO` stubs that an implementing organization fills in
        > as part of authorization. The Implementation column in
        > [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv)
        > stays in sync with this document.

        ## 1. System Identification

        | Field | Value |
        |---|---|
        | System name | *Replace with the assessor-facing system name* |
        | System owner | *Org / role* |
        | System owner contact | *email / phone* |
        | Authorizing official | *Org / role* |
        | System type | Major application — CUI enclave |
        | Environment | AWS GovCloud (US-West) |
        | Authorization boundary | See §3 |
        | CUI categories handled | *List per CUI Registry — e.g. CTI, ITAR-related technical data* |

        ## 2. System Environment

        See the architecture diagrams in
        [`diagrams/network.md`](../diagrams/network.md). The environment comprises:

        - A single AWS GovCloud account in `us-gov-west-1` provisioned by
          [`terraform/govcloud/`](../terraform/govcloud/).
        - A 3-AZ VPC with public, private, and data subnet tiers
          (`terraform/modules/vpc/`).
        - Foundational services: CloudTrail, AWS Config, GuardDuty, KMS,
          IAM Access Analyzer, IAM Identity Center.
        - **No workloads** — those are deployed on top of this foundation by
          the organization's workload Terraform.

        ## 3. System Boundary

        The CUI authorization boundary is the GovCloud account itself plus
        any trusted-network connection to it (Direct Connect / Transit
        Gateway). All resources tagged `DataClassification = "CUI"` (default
        tag in `terraform/govcloud/providers.tf`) are inside the boundary.
        Resources in the linked commercial AWS account are **out of boundary**
        and may not store, process, or transmit CUI; the demo workload in
        [`terraform/demo/`](../terraform/demo/) is illustrative only and
        carries an explicit "NOT A CUI ENCLAVE" disclaimer.

        ## 4. Roles and Responsibilities

        | Role | Responsibility |
        |---|---|
        | Cloud Security Engineering | Maintain Terraform modules, enforce baselines, review IAM Access Analyzer findings. |
        | SecOps | Triage GuardDuty findings, manage incident response, monitor CloudTrail metric filters. |
        | Cloud Network Engineering | Maintain VPC topology, peering, on-prem routing. |
        | IdP Administrators | Manage federation, MFA enforcement, IAM Identity Center permission sets. |
        | Audit & Compliance | Maintain SSP, POA&M, evidence collection, assessor liaison. |
        | Workload owners | Apply boundary controls (SGs, KMS keys) to their resources; *not* covered by this SSP. |

        ## 5. Control Implementation Statements

    """))

    for fam_code, fam_name in family_order:
        parts.append(f"### {_section_for_family(fam_code)} {fam_name} ({fam_code})\n\n")
        for r in by_family[fam_code]:
            cid = r["control_id"]
            name = r["control_name"]
            parts.append(f"#### {cid} — {name}\n")
            if cid in WRITTEN:
                status, role, impl, evidence = WRITTEN[cid]
                parts.append(f"**Implementation status:** {status}  \n")
                parts.append(f"**Responsible role:** {role}  \n")
                parts.append(f"**Implementation:** {impl}  \n")
                parts.append(f"**Evidence:** {evidence}\n\n")
            else:
                parts.append("**Implementation status:** TODO\n")
                parts.append("**Responsible role:** TODO  \n")
                parts.append(
                    "**Implementation:** TODO — see "
                    "[`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) "
                    "for current Terraform coverage notes.  \n"
                )
                parts.append("**Evidence:** TODO\n\n")

    parts.append(dedent("""\
        ## 6. Plan of Action and Milestones (POA&M)

        Maintained outside this repository in the organization's GRC tooling.
        At minimum, a POA&M entry should exist for every control whose
        Implementation status is `Partial` or `Planned`, with a target
        remediation date and responsible role.

        ## 7. Appendix A — Inherited Controls (AWS shared responsibility)

        The following controls are inherited from AWS GovCloud's authorized
        boundary (see AWS's FedRAMP High and DoD IL5 attestations in AWS
        Artifact). The system inherits implementation; the organization is
        responsible for *consuming* the inherited control correctly.

        - **3.10.1, 3.10.2, 3.10.4 — Physical Protection** — AWS data center
          physical access controls.
        - **3.8.3 — Media sanitization** — AWS handles disposal of physical
          media per NIST SP 800-88.
        - **3.13.4 — Shared resource isolation** — AWS Nitro hardware isolation
          when Dedicated Tenancy or Nitro instances are used.

        ## 8. Appendix B — Glossary

        | Term | Definition |
        |---|---|
        | CUI | Controlled Unclassified Information per 32 CFR Part 2002. |
        | CMMC | Cybersecurity Maturity Model Certification (DoD). |
        | DFARS 7012 | DFARS clause 252.204-7012 — Safeguarding CDI and Cyber Incident Reporting. |
        | FIPS 140 | NIST cryptographic module validation standard (140-2 / 140-3). |
        | KMS | AWS Key Management Service — managed CMKs. |
        | SSP | System Security Plan — this document. |
        | POA&M | Plan of Action and Milestones. |
    """))

    OUT.write_text("".join(parts), encoding="utf-8")
    print(f"Wrote {OUT}")


def _section_for_family(fam_code: str) -> str:
    # 3.1, 3.2, ... section numbers.
    return {
        "AC": "3.1", "AT": "3.2", "AU": "3.3", "CM": "3.4", "IA": "3.5",
        "IR": "3.6", "MA": "3.7", "MP": "3.8", "PS": "3.9", "PE": "3.10",
        "RA": "3.11", "CA": "3.12", "SC": "3.13", "SI": "3.14",
    }[fam_code]


if __name__ == "__main__":
    main()
