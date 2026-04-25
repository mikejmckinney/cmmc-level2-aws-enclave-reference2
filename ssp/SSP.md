# System Security Plan — CMMC L2 / NIST 800-171 r2 CUI Enclave (Reference)

> **Status:** Reference skeleton. 14 of 110 controls have fully-written
> implementation statements (those for which the Terraform in this
> repository materially implements the control). The remaining 96 are
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

### 3.1 Access Control (AC)

#### 3.1.1 — Limit system access to authorized users
**Implementation status:** Partial  
**Responsible role:** Cloud Security Engineering; IdP Administrators  
**Implementation:** Account-level access enforces a minimum 14-character password policy and AWS IAM Access Analyzer is enabled, both via the `iam_baseline` Terraform module instantiated in `terraform/govcloud/main.tf`. Human users access the enclave through IAM Identity Center federated to the corporate IdP; only named, authenticated principals receive permission sets. Workload identities use IAM roles assumed by EC2/ECS/Lambda — no static IAM users are created by this configuration.  
**Evidence:** `terraform/govcloud/main.tf` (`module.iam_baseline`); `terraform/modules/iam_baseline/main.tf` (`aws_iam_account_password_policy.this`, `aws_accessanalyzer_analyzer.account`); CloudTrail `AssumeRoleWithSAML` events; IAM Identity Center assignments report.

#### 3.1.2 — Limit access to authorized transactions
**Implementation status:** Partial  
**Responsible role:** Cloud Security Engineering  
**Implementation:** Authorized transactions are constrained by IAM permission boundaries and (when an organization is in use) Service Control Policies. The `DenyNonFipsEndpoints` managed policy created by `module.iam_baseline` is intended for attachment as a permission boundary in GovCloud (`var.attach_deny_non_fips = true`), denying any API call that did not traverse a FIPS endpoint or used TLS below 1.2. Workload roles are scoped to the specific actions and resources their function requires.  
**Evidence:** `terraform/modules/iam_baseline/main.tf` (`aws_iam_policy.deny_non_fips`); CloudTrail `userIdentity` plus `requestParameters` showing endpoint host; IAM permission boundary attachments per role.

#### 3.1.3 — Control CUI flow
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.1.4 — Separation of duties
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.1.5 — Least privilege
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.1.6 — Use non-privileged accounts
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.1.7 — Prevent non-privileged users from privileged functions
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.1.8 — Limit unsuccessful logon attempts
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.1.9 — Privacy / security notices
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.1.10 — Session lock
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.1.11 — Session termination
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.1.12 — Monitor and control remote access
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.1.13 — Cryptographic protection of remote access
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.1.14 — Route remote access via managed access points
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.1.15 — Authorize remote execution of privileged commands
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.1.16 — Authorize wireless access
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.1.17 — Protect wireless access
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.1.18 — Control mobile device connection
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.1.19 — Encrypt CUI on mobile devices
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.1.20 — Verify external connections
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.1.21 — Limit external system portable storage
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.1.22 — Control public information posting
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

### 3.2 Awareness and Training (AT)

#### 3.2.1 — Security awareness training
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.2.2 — Role-based training
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.2.3 — Insider threat training
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

### 3.3 Audit and Accountability (AU)

#### 3.3.1 — Create and retain audit logs
**Implementation status:** Implemented  
**Responsible role:** Cloud Security Engineering; SecOps  
**Implementation:** A multi-region CloudTrail trail captures all management events to a KMS-encrypted S3 bucket with Object Lock GOVERNANCE retention (default 7 years) and to a KMS-encrypted CloudWatch Logs group. The `cloudtrail` module additionally provisions metric filters for `RootAccountUsage`, `IAMPolicyChange`, `ConsoleSignInWithoutMFA`, and `KMSKeyDisableOrDelete` under the `CMMC/CloudTrail` namespace, ready for SNS-backed alarms.  
**Evidence:** `terraform/modules/cloudtrail/main.tf` (`aws_cloudtrail.this`, `aws_s3_bucket_object_lock_configuration.trail`, `aws_cloudwatch_log_metric_filter.this`); S3 bucket name from `module.cloudtrail.log_bucket_name`; CloudWatch metric `CMMC/CloudTrail/RootAccountUsage`.

#### 3.3.2 — Trace user actions
**Implementation status:** Implemented  
**Responsible role:** SecOps  
**Implementation:** Every CloudTrail record contains a `userIdentity` block (principal type, ARN, MFA flag, source IP, user agent). Combined with the named-principal model from control 3.1.1 (no shared accounts, federated SSO), this provides individual accountability for every API action. Trail integrity is protected by log-file validation digest files and by the Object-Locked S3 bucket.  
**Evidence:** `terraform/modules/cloudtrail/main.tf` (`aws_cloudtrail.this.enable_log_file_validation = true`); sample CloudTrail event JSON with `userIdentity.arn`; S3 digest objects under `AWSLogs/<account>/CloudTrail-Digest/`.

#### 3.3.3 — Review and update logged events
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.3.4 — Alert on audit logging failures
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.3.5 — Correlate audit records
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.3.6 — Audit reduction and report generation
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.3.7 — Authoritative time source
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.3.8 — Protect audit information from unauthorized modification
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.3.9 — Limit management of audit logging
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

### 3.4 Configuration Management (CM)

#### 3.4.1 — Establish baseline configurations
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.4.2 — Establish security configuration settings
**Implementation status:** Partial  
**Responsible role:** Cloud Security Engineering  
**Implementation:** AWS Config records configuration baselines for every supported resource via `module.config`, with delivery to a KMS-encrypted S3 bucket and global resource recording enabled in the primary region. The configuration supports an optional NIST 800-171 Conformance Pack via `var.config_conformance_pack_template_body`; clients supply the YAML body from `awslabs/aws-config-rules` so license terms remain explicit.  
**Evidence:** `terraform/modules/config/main.tf` (`aws_config_configuration_recorder.this`, `aws_config_conformance_pack.nist_800_171`); Config delivery bucket from `module.config.delivery_bucket_name`.

#### 3.4.3 — Track changes to systems
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.4.4 — Analyze security impact of changes
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.4.5 — Restrict access for changes
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.4.6 — Least functionality
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.4.7 — Restrict nonessential functions / ports
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.4.8 — Apply deny-by-exception for software
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.4.9 — Control user-installed software
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

### 3.5 Identification and Authentication (IA)

#### 3.5.1 — Identify users and devices
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.5.2 — Authenticate users and devices
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.5.3 — MFA for privileged accounts and network access
**Implementation status:** Partial  
**Responsible role:** IdP Administrators; Cloud Security Engineering  
**Implementation:** AWS-side prerequisites for MFA — strong password policy, IAM Access Analyzer for over-permissioned roles, and the `DenyNonFipsEndpoints` permission boundary — are provisioned by `module.iam_baseline`. Multifactor authentication itself is enforced at the corporate IdP / IAM Identity Center; phishing-resistant factors (WebAuthn / FIDO2) are required for any role that has privileged access to the enclave account.  
**Evidence:** `terraform/modules/iam_baseline/main.tf` (`aws_iam_account_password_policy.this`); IAM Identity Center MFA policy export; IdP factor-enforcement policy.

#### 3.5.4 — Replay-resistant authentication
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.5.5 — Prevent identifier reuse
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.5.6 — Disable inactive identifiers
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.5.7 — Enforce password complexity
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.5.8 — Prohibit password reuse
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.5.9 — Allow temporary passwords for system logons
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.5.10 — Cryptographically protect passwords
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.5.11 — Obscure feedback of authentication info
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

### 3.6 Incident Response (IR)

#### 3.6.1 — Establish incident handling capability
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.6.2 — Track, document, report incidents
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.6.3 — Test incident response capability
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

### 3.7 Maintenance (MA)

#### 3.7.1 — Perform system maintenance
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.7.2 — Control maintenance tools
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.7.3 — Sanitize equipment for off-site maintenance
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.7.4 — Check media for malicious code before maintenance
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.7.5 — Require MFA for nonlocal maintenance
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.7.6 — Supervise maintenance by personnel without authorization
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

### 3.8 Media Protection (MP)

#### 3.8.1 — Protect media containing CUI
**Implementation status:** Implemented  
**Responsible role:** Cloud Security Engineering; Workload Owners  
**Implementation:** CUI-bearing S3 buckets are provisioned via the `s3_cui` workload module (`terraform/modules/workloads/s3_cui/`), instantiated in `terraform/govcloud/main.tf` as `module.s3_cui`. The module enforces SSE-KMS at rest using the `data` CMK, blocks every public-access vector (`block_public_acls`, `block_public_policy`, `ignore_public_acls`, `restrict_public_buckets`), and applies a bucket policy that denies any `s3:PutObject` lacking the `data_classification = cui` request tag. AWS handles physical-media protection by contract; the module addresses the logical-media half of the control.  
**Evidence:** `terraform/modules/workloads/s3_cui/main.tf` (`aws_s3_bucket.cui`, `aws_s3_bucket_public_access_block.cui`, `aws_s3_bucket_server_side_encryption_configuration.cui`, `aws_s3_bucket_policy.cui`); `terraform/govcloud/main.tf` (`module.s3_cui`); CloudTrail `PutObject` events showing `requestParameters.x-amz-tagging` set on every successful upload.

#### 3.8.2 — Limit access to media
**Implementation status:** Implemented  
**Responsible role:** Cloud Security Engineering; Workload Owners  
**Implementation:** Read access is gated at three layers: (1) the `data` KMS key policy restricts `kms:Decrypt` to named workload roles; (2) the `s3_cui` bucket policy denies `s3:PutObject` without the classification tag and denies `s3:DeleteObjectTagging` outright (so an uploaded object's classification cannot be erased); (3) the public-access block on the bucket forbids any anonymous or wildcard cross-account principal.  
**Evidence:** `terraform/modules/workloads/s3_cui/main.tf` (`aws_s3_bucket_policy.cui`, statements `DenyPutObjectWithoutClassificationTag` and `DenyTagRemoval`); `terraform/modules/kms/main.tf` (key policy); CloudTrail `AccessDenied` events when the tag guard fires.

#### 3.8.3 — Sanitize media before disposal
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.8.4 — Mark media with CUI markings
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.8.5 — Control access to media outside controlled areas
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.8.6 — Cryptographic protection of CUI on transport media
**Implementation status:** Implemented  
**Responsible role:** Cloud Security Engineering  
**Implementation:** All `s3:*` calls against the CUI bucket and its access-log target bucket are denied unless `aws:SecureTransport = true`, via the `DenyInsecureTransport` statements in both bucket policies. In the GovCloud partition the underlying KMS CMK is FIPS 140-2 / 140-3 validated, so transport encryption AND data key encryption both clear the CMMC L2 cryptographic-module bar. Snowball Edge (used for offline transport) ships with FIPS-validated crypto modules and remains the documented out-of-band path.  
**Evidence:** `terraform/modules/workloads/s3_cui/main.tf` (`aws_s3_bucket_policy.cui` + `aws_s3_bucket_policy.access_logs`, statements `DenyInsecureTransport`); `terraform/modules/kms/main.tf` (`aws_kms_key.this`); AWS FIPS endpoint documentation; Snowball Edge security overview.

#### 3.8.7 — Control use of removable media
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.8.8 — Prohibit use of portable storage without identifiable owner
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.8.9 — Protect backups
**Implementation status:** Implemented  
**Responsible role:** Cloud Security Engineering; Workload Owners  
**Implementation:** The `s3_cui` module enables versioning on the CUI bucket so accidental overwrites and deletes leave a recoverable prior version, and applies a non-current-version expiration lifecycle (default 90 days) so version history does not accumulate unbounded. All current and non-current versions are encrypted with the `data` CMK via SSE-KMS. AWS Backup vaults wired by the consumer onto `module.s3_cui.bucket_arn` inherit the same KMS protection. Object Lock for WORM retention is documented as a Production override and is the consumer's choice when the use case demands it.  
**Evidence:** `terraform/modules/workloads/s3_cui/main.tf` (`aws_s3_bucket_versioning.cui`, `aws_s3_bucket_lifecycle_configuration.cui` rule `cui-lifecycle`); `terraform/modules/workloads/s3_cui/README.md` §"Production overrides" (Object Lock, AWS Backup wiring); client-supplied AWS Backup plan ARN.

### 3.9 Personnel Security (PS)

#### 3.9.1 — Screen personnel before authorizing access
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.9.2 — Protect CUI during personnel actions
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

### 3.10 Physical Protection (PE)

#### 3.10.1 — Limit physical access
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.10.2 — Protect and monitor physical facility
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.10.3 — Escort visitors
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.10.4 — Maintain physical access audit logs
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.10.5 — Control and manage physical access devices
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.10.6 — Enforce safeguarding measures at alternate work sites
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

### 3.11 Risk Assessment (RA)

#### 3.11.1 — Periodically assess risk
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.11.2 — Scan for vulnerabilities
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.11.3 — Remediate vulnerabilities
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

### 3.12 Security Assessment (CA)

#### 3.12.1 — Assess security controls periodically
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.12.2 — Develop and implement plans of action
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.12.3 — Monitor security controls continuously
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.12.4 — Develop, document, and update SSPs
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

### 3.13 System and Communications Protection (SC)

#### 3.13.1 — Monitor and control communications at boundaries
**Implementation status:** Partial  
**Responsible role:** Cloud Network Engineering  
**Implementation:** The enclave VPC has three subnet tiers (public, private, data) across three AZs in GovCloud. The data tier has no NAT route. Eight Interface VPC endpoints (SSM, SSMMessages, EC2Messages, KMS, Logs, Monitoring, STS, EC2) plus S3 and DynamoDB Gateway endpoints keep AWS API traffic on the AWS backbone. VPC Flow Logs deliver to a KMS-encrypted CloudWatch Logs group with the configured retention.  
**Evidence:** `terraform/modules/vpc/main.tf` (`aws_subnet.{public,private,data}`, `aws_vpc_endpoint.{interface,s3,dynamodb}`, `aws_flow_log.this`); flow log group name from `module.vpc.flow_log_group_name`.

#### 3.13.2 — Apply architecture and design principles for security
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.13.3 — Separate user functionality from system management
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.13.4 — Prevent unauthorized information transfer via shared resources
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.13.5 — Implement subnetworks for publicly accessible components
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.13.6 — Deny network communications by default
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.13.7 — Prevent split tunneling
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.13.8 — Cryptographic protection of CUI in transit
**Implementation status:** Implemented  
**Responsible role:** Cloud Security Engineering  
**Implementation:** All AWS API traffic is TLS by default; the `DenyNonFipsEndpoints` managed policy from `module.iam_baseline` (active in GovCloud via `attach_deny_non_fips = true`) denies any request without `aws:SecureTransport=true`. A companion statement (`DenyNonTLSv12`) denies S3 requests under TLS 1.2. The CloudTrail and AWS Config delivery buckets carry an additional `DenyInsecureTransport` bucket policy as defense-in-depth.  
**Evidence:** `terraform/modules/iam_baseline/main.tf` (`aws_iam_policy.deny_non_fips`); `terraform/modules/cloudtrail/main.tf` (`data.aws_iam_policy_document.trail_bucket` -> `DenyInsecureTransport`); `terraform/modules/config/main.tf` (matching deny on Config delivery bucket).

#### 3.13.9 — Terminate network connections at end of session
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.13.10 — Establish and manage cryptographic keys
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.13.11 — Employ FIPS-validated cryptography for CUI
**Implementation status:** Implemented  
**Responsible role:** Cloud Security Engineering  
**Implementation:** The GovCloud provider sets `use_fips_endpoint = true` (`terraform/govcloud/providers.tf`), routing every AWS API call through FIPS-validated endpoints. AWS KMS in GovCloud uses FIPS 140-2 validated HSMs; all data CMKs are KMS-managed (no imported key material) with annual rotation enabled by `module.kms`. The `DenyNonTLSv12` statement enforces TLS 1.2+ for S3 (FIPS-approved cipher suites only).  
**Evidence:** `terraform/govcloud/providers.tf` (`use_fips_endpoint = true`); `terraform/modules/kms/main.tf` (`aws_kms_key.this.enable_key_rotation = true`); AWS KMS FIPS 140-2 module attestation in AWS Compliance Reports (Artifact).

#### 3.13.12 — Prohibit remote activation of collaborative computing devices
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.13.13 — Control mobile code
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.13.14 — Control VoIP technologies
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.13.15 — Protect authenticity of communications sessions
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.13.16 — Protect confidentiality of CUI at rest
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

### 3.14 System and Information Integrity (SI)

#### 3.14.1 — Identify, report, correct system flaws
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.14.2 — Protect from malicious code
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.14.3 — Monitor security alerts and advisories
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.14.4 — Update malicious code protection
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.14.5 — Periodic and real-time scans
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

#### 3.14.6 — Monitor for attacks and unauthorized use
**Implementation status:** Implemented  
**Responsible role:** SecOps  
**Implementation:** Three independent detection sources are wired by Terraform: (1) GuardDuty detector with all features enabled via `module.guardduty` (defaults: S3 events, EKS audit + runtime, EBS malware, RDS, Lambda); (2) CloudTrail metric filters from `module.cloudtrail` for high-signal actions; (3) VPC Flow Logs to CloudWatch from `module.vpc`. Findings publish every 15 minutes by default.  
**Evidence:** `terraform/modules/guardduty/main.tf` (`aws_guardduty_detector.this`, `aws_guardduty_detector_feature.this`); `terraform/modules/cloudtrail/main.tf` (`aws_cloudwatch_log_metric_filter.this`); GuardDuty findings export via EventBridge to ticketing.

#### 3.14.7 — Identify unauthorized use
**Implementation status:** TODO
**Responsible role:** TODO  
**Implementation:** TODO — see [`controls/nist-800-171-mapping.csv`](../controls/nist-800-171-mapping.csv) for current Terraform coverage notes.  
**Evidence:** TODO

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
