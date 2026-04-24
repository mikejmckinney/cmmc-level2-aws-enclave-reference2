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

# DenyNonFipsEndpoints — deny any AWS API call that did NOT go through a
# FIPS endpoint. Attach to permission boundaries / SCPs in GovCloud.
data "aws_iam_policy_document" "deny_non_fips" {
  count = var.attach_deny_non_fips ? 1 : 0

  statement {
    sid       = "DenyNonFipsEndpoints"
    effect    = "Deny"
    actions   = ["*"]
    resources = ["*"]
    condition {
      test     = "StringNotEqualsIfExists"
      variable = "aws:SecureTransport"
      values   = ["true"]
    }
  }

  statement {
    sid       = "DenyNonTLSv12"
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
  description = "Defense-in-depth deny for non-FIPS / non-TLSv1.2 traffic. Intended for permission boundaries and SCPs in GovCloud."
  policy      = data.aws_iam_policy_document.deny_non_fips[0].json
  tags        = var.tags
}
