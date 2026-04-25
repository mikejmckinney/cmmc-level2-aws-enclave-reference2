data "aws_partition" "current" {}

resource "aws_iam_account_password_policy" "this" {
  minimum_password_length        = var.minimum_password_length
  require_lowercase_characters   = true
  require_uppercase_characters   = true
  require_numbers                = true
  require_symbols                = true
  allow_users_to_change_password = true
  hard_expiry                    = false
  max_password_age               = var.max_password_age
  password_reuse_prevention      = var.password_reuse_prevention
}

resource "aws_accessanalyzer_analyzer" "account" {
  analyzer_name = var.access_analyzer_name
  type          = "ACCOUNT"
  tags          = var.tags
}

# DenyNonFipsEndpoints — enforce that AWS API calls land on FIPS-validated
# service endpoints. AWS does not expose endpoint hostnames as IAM condition
# keys, so we cannot literally match `*-fips.*.amazonaws.com`. The mechanism
# instead combines three independently-enforceable conditions:
#
#   1. aws:RequestedRegion ∈ var.fips_allowed_regions
#      GovCloud regions (us-gov-west-1, us-gov-east-1) serve FIPS-validated
#      endpoints by default for every service offered there. Restricting
#      RequestedRegion to GovCloud is the actual FIPS guarantee.
#   2. aws:SecureTransport = true (defense-in-depth: deny any plaintext call)
#   3. s3:TlsVersion >= 1.2 (defense-in-depth on the S3 data plane)
#
# Note on StringNotEqualsIfExists: when aws:RequestedRegion is absent from
# the request context (e.g. certain global-scope IAM/STS operations), the
# IfExists variant evaluates to TRUE and the Deny fires — calls without a
# region are blocked. This is intentional: GovCloud exposes all services
# through regional endpoints, so any call that omits the region key should
# be denied as unregionalized. If a future service or internal SDK call
# requires passing without a region key, add a targeted Allow statement in
# the workload role's identity policy (not here).
#
# Attach as a permission boundary on workload roles, or promote to an SCP
# at the org level. Intentionally narrow: it does NOT enforce per-service
# allow-lists — that is the workload role's job.
data "aws_iam_policy_document" "deny_non_fips" {
  count = var.attach_deny_non_fips ? 1 : 0

  statement {
    sid       = "DenyNonFipsRegions"
    effect    = "Deny"
    actions   = ["*"]
    resources = ["*"]
    condition {
      test     = "StringNotEqualsIfExists"
      variable = "aws:RequestedRegion"
      values   = var.fips_allowed_regions
    }
  }

  statement {
    sid       = "DenyPlaintextTransport"
    effect    = "Deny"
    actions   = ["*"]
    resources = ["*"]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    sid       = "DenyTlsBelow12"
    effect    = "Deny"
    actions   = ["*"]
    resources = ["*"]
    condition {
      test     = "NumericLessThan"
      variable = "s3:TlsVersion"
      values   = ["1.2"]
    }
  }
}

resource "aws_iam_policy" "deny_non_fips" {
  count       = var.attach_deny_non_fips ? 1 : 0
  name        = "DenyNonFipsEndpoints"
  description = "Restrict AWS API calls to FIPS-validated endpoints by (1) restricting aws:RequestedRegion to FIPS-by-default GovCloud regions, (2) denying plaintext transport, and (3) denying TLS<1.2 on S3. Calls lacking aws:RequestedRegion are also denied (StringNotEqualsIfExists semantics — intentional for GovCloud)."
  policy      = data.aws_iam_policy_document.deny_non_fips[0].json
  tags        = var.tags
}
