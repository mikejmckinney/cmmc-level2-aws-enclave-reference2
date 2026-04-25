#!/usr/bin/env python3
"""Generate controls/nist-800-171-mapping.csv from inline control catalog.

Source: NIST SP 800-171 Rev. 2 (https://csrc.nist.gov/pubs/sp/800/171/r2/upd1/final).
Control titles paraphrased; we deliberately do NOT copy NIST text verbatim.

Run from repo root:
    python3 scripts/gen-controls-csv.py
"""
from __future__ import annotations

import csv
from pathlib import Path

# Family code -> (long name, short prefix used in NIST IDs as 3.<N>.<n>)
FAMILIES = {
    "AC": ("Access Control", 1),
    "AT": ("Awareness and Training", 2),
    "AU": ("Audit and Accountability", 3),
    "CM": ("Configuration Management", 4),
    "IA": ("Identification and Authentication", 5),
    "IR": ("Incident Response", 6),
    "MA": ("Maintenance", 7),
    "MP": ("Media Protection", 8),
    "PS": ("Personnel Security", 9),
    "PE": ("Physical Protection", 10),
    "RA": ("Risk Assessment", 11),
    "CA": ("Security Assessment", 12),
    "SC": ("System and Communications Protection", 13),
    "SI": ("System and Information Integrity", 14),
}

# Per-control records. Tuple shape:
#   (control_id, family_code, control_name, description,
#    addressed_by_repo, aws_services, terraform_resources,
#    requires_client_config, organizational_control, notes)
#
# addressed_by_repo: full | partial | none
# Booleans expressed as "true"/"false" strings for CSV friendliness.

CONTROLS: list[tuple[str, str, str, str, str, str, str, str, str, str]] = [
    # ----- 3.1 Access Control (AC) — 22 -----
    ("3.1.1", "AC", "Limit system access to authorized users", "Restrict logical access to authorized users, processes, and devices.", "partial", "IAM;IAM Identity Center", "module.iam_baseline", "true", "false", "Repo provides password policy + Access Analyzer; client wires SSO and least-privilege roles. SSP-written."),
    ("3.1.2", "AC", "Limit access to authorized transactions", "Restrict authorized transactions and functions for authorized users.", "partial", "IAM", "module.iam_baseline", "true", "false", "DenyNonFipsEndpoints permission-boundary template provided. SSP-written."),
    ("3.1.3", "AC", "Control CUI flow", "Control approved authorizations for controlling CUI flow within the system.", "partial", "VPC;Security Groups;Network ACLs", "module.vpc", "true", "false", "Tiered subnets + endpoint SGs; client adds workload SGs / NACLs."),
    ("3.1.4", "AC", "Separation of duties", "Separate duties of individuals to reduce risk of malevolent activity.", "none", "IAM", "", "true", "true", "Organizational role design — outside Terraform."),
    ("3.1.5", "AC", "Least privilege", "Employ least privilege, including for specific security functions.", "partial", "IAM;IAM Access Analyzer", "module.iam_baseline", "true", "false", "Access Analyzer surfaces over-permissioned roles."),
    ("3.1.6", "AC", "Use non-privileged accounts", "Use non-privileged accounts when accessing non-security functions.", "none", "IAM Identity Center", "", "true", "true", "Operational practice; enforce via SSO permission sets."),
    ("3.1.7", "AC", "Prevent non-privileged users from privileged functions", "Prevent non-privileged users from executing privileged functions.", "partial", "IAM", "module.iam_baseline", "true", "false", "Use SCPs + permission boundaries."),
    ("3.1.8", "AC", "Limit unsuccessful logon attempts", "Limit unsuccessful logon attempts.", "none", "IAM Identity Center;IdP", "", "true", "false", "Configured at the IdP (Okta/Entra/IAM Identity Center)."),
    ("3.1.9", "AC", "Privacy / security notices", "Provide privacy and security notices consistent with applicable CUI rules.", "none", "", "", "true", "true", "Banner enforced at workstation / SSO portal layer."),
    ("3.1.10", "AC", "Session lock", "Use session lock with pattern-hiding displays.", "none", "", "", "true", "true", "Endpoint MDM responsibility."),
    ("3.1.11", "AC", "Session termination", "Terminate user sessions after a defined condition.", "none", "IAM Identity Center;ALB", "", "true", "false", "Session timeouts configured at IdP / app layer."),
    ("3.1.12", "AC", "Monitor and control remote access", "Monitor and control remote access sessions.", "partial", "Systems Manager;CloudTrail", "module.cloudtrail", "true", "false", "SSM Session Manager + CloudTrail logs sessions."),
    ("3.1.13", "AC", "Cryptographic protection of remote access", "Employ cryptographic mechanisms to protect remote access sessions.", "partial", "Systems Manager;ACM;KMS", "module.iam_baseline", "true", "false", "DenyNonFipsEndpoints + SSM TLS; client manages bastion certs."),
    ("3.1.14", "AC", "Route remote access via managed access points", "Route remote access via managed access control points.", "partial", "VPC;Systems Manager", "module.vpc", "true", "false", "VPC endpoints + SSM Session Manager as the bastion."),
    ("3.1.15", "AC", "Authorize remote execution of privileged commands", "Authorize remote execution of privileged commands and remote access to security-relevant info.", "none", "IAM;Systems Manager", "", "true", "false", "Configured per workload IAM role."),
    ("3.1.16", "AC", "Authorize wireless access", "Authorize wireless access prior to allowing such connections.", "none", "", "", "true", "true", "On-prem network policy."),
    ("3.1.17", "AC", "Protect wireless access", "Protect wireless access using authentication and encryption.", "none", "", "", "true", "true", "On-prem network policy (WPA3-Enterprise)."),
    ("3.1.18", "AC", "Control mobile device connection", "Control connection of mobile devices.", "none", "", "", "true", "true", "MDM responsibility."),
    ("3.1.19", "AC", "Encrypt CUI on mobile devices", "Encrypt CUI on mobile devices and mobile computing platforms.", "none", "", "", "true", "true", "Endpoint FDE policy."),
    ("3.1.20", "AC", "Verify external connections", "Verify and control connections to and use of external systems.", "partial", "VPC;Network Firewall", "module.vpc", "true", "false", "VPC endpoints reduce external exposure; client-controlled egress lists."),
    ("3.1.21", "AC", "Limit external system portable storage", "Limit use of portable storage devices on external systems.", "none", "", "", "true", "true", "MDM / DLP responsibility."),
    ("3.1.22", "AC", "Control public information posting", "Control CUI posted or processed on publicly accessible systems.", "partial", "S3;CloudFront;WAF", "", "true", "true", "Demo workload deliberately serves no CUI; client governs publishing."),

    # ----- 3.2 Awareness and Training (AT) — 3 -----
    ("3.2.1", "AT", "Security awareness training", "Ensure managers, system administrators, and users are aware of security risks.", "none", "", "", "true", "true", "Annual training program."),
    ("3.2.2", "AT", "Role-based training", "Ensure personnel are trained for assigned security duties.", "none", "", "", "true", "true", "Role-specific curricula."),
    ("3.2.3", "AT", "Insider threat training", "Provide security awareness training on recognizing and reporting insider threats.", "none", "", "", "true", "true", "Annual training topic."),

    # ----- 3.3 Audit and Accountability (AU) — 9 -----
    ("3.3.1", "AU", "Create and retain audit logs", "Create and retain system audit logs and records.", "full", "CloudTrail;CloudWatch Logs;S3", "module.cloudtrail", "false", "false", "Multi-region trail, KMS-encrypted, Object-Locked S3, CW Logs metric filters."),
    ("3.3.2", "AU", "Trace user actions", "Ensure actions of individual users can be uniquely traced.", "full", "CloudTrail;IAM", "module.cloudtrail;module.iam_baseline", "false", "false", "userIdentity in every CloudTrail record; named SSO principals."),
    ("3.3.3", "AU", "Review and update logged events", "Review and update logged events.", "partial", "CloudWatch Logs;Athena", "module.cloudtrail", "true", "false", "Repo provisions storage; client owns log review cadence."),
    ("3.3.4", "AU", "Alert on audit logging failures", "Alert in the event of an audit logging process failure.", "partial", "CloudWatch Alarms", "", "true", "false", "Wire alarms on CloudTrail/Config delivery failures in workload root."),
    ("3.3.5", "AU", "Correlate audit records", "Correlate audit record review for investigation and response.", "none", "Security Hub;OpenSearch", "", "true", "false", "SIEM integration is downstream of this repo."),
    ("3.3.6", "AU", "Audit reduction and report generation", "Provide audit record reduction and report generation.", "none", "Athena;QuickSight", "", "true", "false", "Reporting toolchain is client choice."),
    ("3.3.7", "AU", "Authoritative time source", "Provide a system capability to compare and synchronize internal clocks with an authoritative source.", "partial", "Amazon Time Sync Service", "", "false", "false", "AWS provides NTP; client EC2 AMIs must use it."),
    ("3.3.8", "AU", "Protect audit information from unauthorized modification", "Protect audit information and tools from unauthorized access, modification, and deletion.", "partial", "S3 Object Lock;KMS;IAM", "module.cloudtrail;module.kms", "true", "false", "Object Lock GOVERNANCE + KMS SSE + bucket policy deny-non-TLS; client must restrict CloudTrail:Stop/Delete via SCP."),
    ("3.3.9", "AU", "Limit management of audit logging", "Limit management of audit logging functionality to a subset of privileged users.", "none", "IAM;SCPs", "", "true", "false", "Use SCP to deny CloudTrail:Stop/Delete except for audit role."),

    # ----- 3.4 Configuration Management (CM) — 9 -----
    ("3.4.1", "CM", "Establish baseline configurations", "Establish and maintain baseline configurations and inventories.", "partial", "AWS Config;Systems Manager", "module.config", "true", "false", "Config recorder captures baselines; SSM Inventory for OS-level is client responsibility."),
    ("3.4.2", "CM", "Establish security configuration settings", "Establish and enforce security configuration settings.", "partial", "AWS Config;Conformance Packs", "module.config", "true", "false", "Optional NIST 800-171 conformance pack hook; client supplies YAML body. SSP-written."),
    ("3.4.3", "CM", "Track changes to systems", "Track, review, approve/disapprove, and audit changes.", "partial", "AWS Config;CloudTrail;Change Manager", "module.config;module.cloudtrail", "true", "false", "Repo captures change events; client owns CAB process."),
    ("3.4.4", "CM", "Analyze security impact of changes", "Analyze security impact of changes prior to implementation.", "none", "", "", "true", "true", "Change-management process."),
    ("3.4.5", "CM", "Restrict access for changes", "Define, document, approve, enforce physical and logical access restrictions for changes.", "none", "IAM;CodePipeline", "", "true", "false", "Implemented via CI/CD permission model."),
    ("3.4.6", "CM", "Least functionality", "Employ principle of least functionality (disable unnecessary services).", "partial", "Systems Manager Patch Manager", "module.vpc", "true", "false", "Minimal VPC endpoints; client hardens AMIs."),
    ("3.4.7", "CM", "Restrict nonessential functions / ports", "Restrict, disable, or prevent use of nonessential programs, functions, ports.", "partial", "Security Groups;NACLs", "module.vpc", "true", "false", "Default SGs deny all; client must justify open ports."),
    ("3.4.8", "CM", "Apply deny-by-exception for software", "Apply deny-by-exception (blacklisting) or permit-by-exception (whitelisting) for software.", "none", "Systems Manager Patch Manager", "", "true", "false", "Client policy."),
    ("3.4.9", "CM", "Control user-installed software", "Control and monitor user-installed software.", "none", "", "", "true", "true", "Endpoint MDM."),

    # ----- 3.5 Identification and Authentication (IA) — 11 -----
    ("3.5.1", "IA", "Identify users and devices", "Identify system users, processes, and devices.", "partial", "IAM;IAM Identity Center", "module.iam_baseline", "true", "false", "Named SSO users; client federates from IdP."),
    ("3.5.2", "IA", "Authenticate users and devices", "Authenticate the identities of users, processes, and devices.", "partial", "IAM Identity Center", "module.iam_baseline", "true", "false", "MFA enforced at IdP."),
    ("3.5.3", "IA", "MFA for privileged accounts and network access", "Use multifactor authentication for privileged and network access for non-privileged accounts.", "partial", "IAM Identity Center", "module.iam_baseline", "true", "false", "Repo readies the foundation; MFA enforced at IdP. SSP-written."),
    ("3.5.4", "IA", "Replay-resistant authentication", "Employ replay-resistant authentication mechanisms.", "partial", "IAM Identity Center;TLS 1.2+", "module.iam_baseline", "true", "false", "AWS APIs use SigV4; IdP must enforce phishing-resistant MFA."),
    ("3.5.5", "IA", "Prevent identifier reuse", "Prevent reuse of identifiers for a defined period.", "none", "IAM Identity Center", "", "true", "false", "IdP / HR offboarding policy."),
    ("3.5.6", "IA", "Disable inactive identifiers", "Disable identifiers after a defined period of inactivity.", "none", "IAM Identity Center", "", "true", "false", "IdP automation."),
    ("3.5.7", "IA", "Enforce password complexity", "Enforce a minimum password complexity and change of characters when new passwords are created.", "partial", "IAM", "module.iam_baseline;aws_iam_account_password_policy.this", "false", "false", "Min length 14, all character classes; covered by SSP §3.5.3 write-up."),
    ("3.5.8", "IA", "Prohibit password reuse", "Prohibit password reuse for a specified number of generations.", "partial", "IAM", "module.iam_baseline;aws_iam_account_password_policy.this", "false", "false", "password_reuse_prevention = 24; covered by SSP §3.5.3 write-up."),
    ("3.5.9", "IA", "Allow temporary passwords for system logons", "Allow temporary password use for system logons with immediate change to permanent.", "none", "IAM Identity Center", "", "true", "false", "IdP behavior."),
    ("3.5.10", "IA", "Cryptographically protect passwords", "Store and transmit only cryptographically protected passwords.", "partial", "IAM;Secrets Manager", "module.kms", "true", "false", "AWS hashes IAM passwords; client uses Secrets Manager for app secrets."),
    ("3.5.11", "IA", "Obscure feedback of authentication info", "Obscure feedback of authentication information.", "none", "", "", "true", "true", "Endpoint behavior."),

    # ----- 3.6 Incident Response (IR) — 3 -----
    ("3.6.1", "IR", "Establish incident handling capability", "Establish operational incident-handling capability.", "none", "Security Hub;EventBridge", "", "true", "true", "IR plan + on-call rotation."),
    ("3.6.2", "IR", "Track, document, report incidents", "Track, document, and report incidents to designated officials.", "none", "Security Hub", "", "true", "true", "Ticketing + DoD reporting per DFARS 7012."),
    ("3.6.3", "IR", "Test incident response capability", "Test the organizational incident response capability.", "none", "", "", "true", "true", "Annual tabletop exercises."),

    # ----- 3.7 Maintenance (MA) — 6 -----
    ("3.7.1", "MA", "Perform system maintenance", "Perform maintenance on organizational systems.", "none", "Systems Manager Patch Manager", "", "true", "true", "Patch program."),
    ("3.7.2", "MA", "Control maintenance tools", "Provide effective controls on tools, techniques, and personnel for maintenance.", "none", "Systems Manager", "", "true", "true", "Approved-tools list."),
    ("3.7.3", "MA", "Sanitize equipment for off-site maintenance", "Ensure equipment removed for off-site maintenance is sanitized of CUI.", "none", "", "", "true", "true", "AWS handles physical media; CUI in S3/EBS protected by KMS."),
    ("3.7.4", "MA", "Check media for malicious code before maintenance", "Check media containing diagnostic and test programs for malicious code.", "none", "", "", "true", "true", "Cloud-native: minimal media handling."),
    ("3.7.5", "MA", "Require MFA for nonlocal maintenance", "Require multifactor authentication to establish nonlocal maintenance sessions.", "partial", "Systems Manager;IAM Identity Center", "", "true", "false", "SSM Session Manager + SSO MFA."),
    ("3.7.6", "MA", "Supervise maintenance by personnel without authorization", "Supervise maintenance activities of personnel without required access authorization.", "none", "", "", "true", "true", "Process control."),

    # ----- 3.8 Media Protection (MP) — 9 -----
    ("3.8.1", "MP", "Protect media containing CUI", "Protect (physically control and securely store) system media containing CUI.", "full", "S3;EBS;KMS", "module.kms;module.s3_cui", "true", "false", "AWS handles physical media; KMS encrypts logical media; s3_cui adds public-access block + classification-tag PutObject guard. SSP-written."),
    ("3.8.2", "MP", "Limit access to media", "Limit access to CUI on system media to authorized users.", "full", "S3 Bucket Policies;IAM;KMS", "module.kms;module.s3_cui", "true", "false", "KMS key policies + S3 bucket policies; s3_cui denies untagged uploads and tag removal. SSP-written."),
    ("3.8.3", "MP", "Sanitize media before disposal", "Sanitize or destroy system media containing CUI before disposal or release.", "none", "", "", "false", "false", "AWS-attested via FedRAMP / SOC reports."),
    ("3.8.4", "MP", "Mark media with CUI markings", "Mark media with necessary CUI markings and distribution limitations.", "none", "", "", "true", "true", "Tagging convention; default_tags include DataClassification."),
    ("3.8.5", "MP", "Control access to media outside controlled areas", "Control access to media containing CUI and maintain accountability.", "none", "", "", "true", "true", "Process control."),
    ("3.8.6", "MP", "Cryptographic protection of CUI on transport media", "Implement cryptographic mechanisms to protect CUI on digital media during transport.", "full", "KMS;S3;Snowball Edge", "module.kms;module.s3_cui", "true", "false", "FIPS-validated KMS in GovCloud; s3_cui denies any non-TLS request bucket-wide; Snowball uses FIPS modules. SSP-written."),
    ("3.8.7", "MP", "Control use of removable media", "Control the use of removable media on system components.", "none", "", "", "true", "true", "Endpoint MDM / DLP."),
    ("3.8.8", "MP", "Prohibit use of portable storage without identifiable owner", "Prohibit use of portable storage devices when no identifiable owner.", "none", "", "", "true", "true", "Endpoint MDM."),
    ("3.8.9", "MP", "Protect backups", "Protect the confidentiality of backup CUI at storage locations.", "full", "AWS Backup;S3;KMS", "module.kms;module.s3_cui", "true", "false", "KMS-encrypted backup target with versioning + non-current-version lifecycle via s3_cui; client wires AWS Backup vaults onto it. SSP-written."),

    # ----- 3.9 Personnel Security (PS) — 2 -----
    ("3.9.1", "PS", "Screen personnel before authorizing access", "Screen individuals prior to authorizing access to systems containing CUI.", "none", "", "", "true", "true", "HR background-check policy."),
    ("3.9.2", "PS", "Protect CUI during personnel actions", "Ensure CUI and systems are protected during and after personnel actions.", "none", "IAM Identity Center", "", "true", "true", "Offboarding automation."),

    # ----- 3.10 Physical Protection (PE) — 6 -----
    ("3.10.1", "PE", "Limit physical access", "Limit physical access to organizational systems and equipment to authorized individuals.", "none", "", "", "false", "false", "AWS data centers — see SOC reports."),
    ("3.10.2", "PE", "Protect and monitor physical facility", "Protect and monitor the physical facility and support infrastructure.", "none", "", "", "false", "false", "AWS data centers."),
    ("3.10.3", "PE", "Escort visitors", "Escort visitors and monitor visitor activity.", "none", "", "", "true", "true", "Office facility policy."),
    ("3.10.4", "PE", "Maintain physical access audit logs", "Maintain audit logs of physical access.", "none", "", "", "false", "false", "AWS data centers."),
    ("3.10.5", "PE", "Control and manage physical access devices", "Control and manage physical access devices.", "none", "", "", "true", "true", "Office facility policy."),
    ("3.10.6", "PE", "Enforce safeguarding measures at alternate work sites", "Enforce safeguarding measures for CUI at alternate work sites.", "none", "", "", "true", "true", "WFH policy."),

    # ----- 3.11 Risk Assessment (RA) — 3 -----
    ("3.11.1", "RA", "Periodically assess risk", "Periodically assess risk to organizational operations.", "none", "", "", "true", "true", "Annual risk assessment."),
    ("3.11.2", "RA", "Scan for vulnerabilities", "Scan for vulnerabilities periodically and when new vulnerabilities are identified.", "partial", "Inspector;ECR Image Scanning", "", "true", "false", "Enable Inspector in workload root."),
    ("3.11.3", "RA", "Remediate vulnerabilities", "Remediate vulnerabilities in accordance with risk assessments.", "none", "Systems Manager Patch Manager", "", "true", "true", "Patching SLA per severity."),

    # ----- 3.12 Security Assessment (CA) — 4 -----
    ("3.12.1", "CA", "Assess security controls periodically", "Periodically assess the security controls.", "none", "AWS Config;Audit Manager", "", "true", "true", "Annual self-assessment + C3PAO every 3 years."),
    ("3.12.2", "CA", "Develop and implement plans of action", "Develop and implement plans of action to correct deficiencies.", "none", "", "", "true", "true", "POA&M tracking."),
    ("3.12.3", "CA", "Monitor security controls continuously", "Monitor security controls on an ongoing basis.", "partial", "AWS Config;Security Hub;CloudTrail", "module.config;module.cloudtrail", "true", "false", "Config + CloudTrail provide continuous data."),
    ("3.12.4", "CA", "Develop, document, and update SSPs", "Develop, document, and periodically update System Security Plans.", "partial", "", "", "true", "true", "Repo includes ssp/ skeleton; client maintains."),

    # ----- 3.13 System and Communications Protection (SC) — 16 -----
    ("3.13.1", "SC", "Monitor and control communications at boundaries", "Monitor, control, and protect communications at external and key internal boundaries.", "partial", "VPC;Network Firewall;Security Groups", "module.vpc", "true", "false", "Tiered subnets + endpoint SGs + flow logs; client adds AWS Network Firewall if needed. SSP-written."),
    ("3.13.2", "SC", "Apply architecture and design principles for security", "Employ architectural designs and engineering principles that promote effective security.", "partial", "VPC;KMS;IAM", "module.vpc;module.kms;module.iam_baseline", "true", "false", "Reference architecture is the deliverable."),
    ("3.13.3", "SC", "Separate user functionality from system management", "Separate user functionality from system management functionality.", "partial", "IAM;VPC", "module.vpc", "true", "false", "Workload roles separate from admin roles."),
    ("3.13.4", "SC", "Prevent unauthorized information transfer via shared resources", "Prevent unauthorized and unintended information transfer via shared system resources.", "partial", "Dedicated Tenancy;KMS", "module.kms", "true", "false", "AWS Nitro provides hardware isolation; client picks tenancy."),
    ("3.13.5", "SC", "Implement subnetworks for publicly accessible components", "Implement subnetworks for publicly accessible system components separated from internal networks.", "partial", "VPC", "module.vpc", "true", "false", "Public/private/data subnet tiers; client owns workload placement. Covered by SSP §3.13.1."),
    ("3.13.6", "SC", "Deny network communications by default", "Deny network communications by default and allow by exception.", "partial", "Security Groups;NACLs", "module.vpc", "true", "false", "Default SGs deny all; client adds workload allows."),
    ("3.13.7", "SC", "Prevent split tunneling", "Prevent remote devices from simultaneously connecting and bypassing security.", "none", "", "", "true", "true", "VPN client config."),
    ("3.13.8", "SC", "Cryptographic protection of CUI in transit", "Implement cryptographic mechanisms to prevent unauthorized disclosure of CUI in transit.", "full", "IAM;ACM;TLS 1.2+", "module.iam_baseline;aws_iam_policy.deny_non_fips", "false", "false", "DenyNonFipsEndpoints + DenyNonTLSv12 enforce TLS 1.2+ FIPS."),
    ("3.13.9", "SC", "Terminate network connections at end of session", "Terminate network connections at end of session or after a defined period.", "none", "ALB;NLB", "", "true", "false", "Idle timeout per workload."),
    ("3.13.10", "SC", "Establish and manage cryptographic keys", "Establish and manage cryptographic keys for cryptography in the system.", "partial", "KMS", "module.kms", "true", "false", "CMKs with annual rotation; client must define rotation/destruction procedures. Covered by SSP §3.13.11."),
    ("3.13.11", "SC", "Employ FIPS-validated cryptography for CUI", "Employ FIPS-validated cryptography to protect the confidentiality of CUI.", "full", "KMS;use_fips_endpoint", "module.iam_baseline;module.kms", "false", "false", "GovCloud provider use_fips_endpoint=true; KMS uses FIPS 140-2 modules."),
    ("3.13.12", "SC", "Prohibit remote activation of collaborative computing devices", "Prohibit remote activation of collaborative computing devices and provide indication.", "none", "", "", "true", "true", "Endpoint config."),
    ("3.13.13", "SC", "Control mobile code", "Control and monitor the use of mobile code.", "none", "", "", "true", "true", "Browser / endpoint policy."),
    ("3.13.14", "SC", "Control VoIP technologies", "Control and monitor the use of VoIP technologies.", "none", "", "", "true", "true", "Comms platform policy."),
    ("3.13.15", "SC", "Protect authenticity of communications sessions", "Protect the authenticity of communications sessions.", "partial", "IAM;TLS 1.2+", "module.iam_baseline", "true", "false", "SigV4 + TLS; app-layer mutual auth is workload concern."),
    ("3.13.16", "SC", "Protect confidentiality of CUI at rest", "Protect the confidentiality of CUI at rest.", "partial", "KMS;S3 SSE-KMS;EBS Encryption", "module.kms;module.cloudtrail", "true", "false", "KMS CMKs + SSE-KMS for repo-managed buckets; client must set on workload buckets. Covered by SSP §3.13.11."),

    # ----- 3.14 System and Information Integrity (SI) — 7 -----
    ("3.14.1", "SI", "Identify, report, correct system flaws", "Identify, report, and correct system flaws in a timely manner.", "partial", "Systems Manager Patch Manager;Inspector;Config", "module.config", "true", "false", "Config + Patch Manager + Inspector pipeline."),
    ("3.14.2", "SI", "Protect from malicious code", "Provide protection from malicious code at designated locations.", "partial", "GuardDuty;EBS Malware Protection", "module.guardduty", "true", "false", "GuardDuty malware protection; endpoint EDR client-owned."),
    ("3.14.3", "SI", "Monitor security alerts and advisories", "Monitor system security alerts and advisories and take action.", "partial", "Security Hub;EventBridge", "", "true", "false", "Subscribe to AWS bulletins; route to ticketing."),
    ("3.14.4", "SI", "Update malicious code protection", "Update malicious code protection mechanisms when new releases are available.", "partial", "GuardDuty", "module.guardduty", "false", "false", "GuardDuty signatures update automatically."),
    ("3.14.5", "SI", "Periodic and real-time scans", "Perform periodic scans of the system and real-time scans of files from external sources.", "partial", "GuardDuty;Inspector", "module.guardduty", "true", "false", "GuardDuty continuous; Inspector scheduled."),
    ("3.14.6", "SI", "Monitor for attacks and unauthorized use", "Monitor systems including inbound/outbound communications for attacks.", "full", "GuardDuty;CloudTrail;VPC Flow Logs", "module.guardduty;module.cloudtrail;module.vpc", "false", "false", "Three-source detection: GuardDuty + CloudTrail + Flow Logs."),
    ("3.14.7", "SI", "Identify unauthorized use", "Identify unauthorized use of organizational systems.", "partial", "GuardDuty;CloudTrail metric filters", "module.guardduty;module.cloudtrail", "true", "false", "Metric filters surface unusual access; client tunes alerts."),
]

HEADERS = [
    "control_id",
    "family",
    "family_code",
    "control_name",
    "description",
    "addressed_by_repo",
    "aws_services",
    "terraform_resources",
    "requires_client_config",
    "organizational_control",
    "notes",
]


def main() -> None:
    # Sanity checks at generation time so the build fails before writing.
    assert len(CONTROLS) == 110, f"expected 110 controls, got {len(CONTROLS)}"
    ids = [c[0] for c in CONTROLS]
    assert len(set(ids)) == 110, "duplicate control_id"
    fams = {c[1] for c in CONTROLS}
    assert fams == set(FAMILIES.keys()), f"family mismatch: {fams ^ set(FAMILIES.keys())}"

    out = Path(__file__).resolve().parent.parent / "controls" / "nist-800-171-mapping.csv"
    out.parent.mkdir(parents=True, exist_ok=True)

    with out.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.writer(fh, quoting=csv.QUOTE_MINIMAL)
        writer.writerow(HEADERS)
        for cid, fam_code, name, desc, addressed, services, resources, client, org, notes in CONTROLS:
            family_name = FAMILIES[fam_code][0]
            writer.writerow([
                cid, family_name, fam_code, name, desc,
                addressed, services, resources, client, org, notes,
            ])

    # Print tallies for the generator's caller to verify.
    tallies = {k: sum(1 for c in CONTROLS if c[4] == k) for k in ("full", "partial", "none")}
    org_count = sum(1 for c in CONTROLS if c[8] == "true")
    print(f"Wrote {out} ({len(CONTROLS)} rows)")
    print(f"  addressed_by_repo: {tallies}")
    print(f"  organizational_control=true: {org_count}")


if __name__ == "__main__":
    main()
