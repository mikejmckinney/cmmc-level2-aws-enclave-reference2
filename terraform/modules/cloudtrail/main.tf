data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  bucket_name = "${var.name}-cloudtrail-${data.aws_caller_identity.current.account_id}"
  log_group   = "/aws/cloudtrail/${var.name}"
}

# -----------------------------------------------------------------------------
# S3 bucket for trail logs — Object Lock governance mode + KMS SSE.
# -----------------------------------------------------------------------------
resource "aws_s3_bucket" "trail" {
  bucket              = local.bucket_name
  force_destroy       = false
  object_lock_enabled = true
  tags                = var.tags
}

# Separate bucket that receives S3 access logs for the trail bucket above.
# Per AWS guidance the access-log target must be a different bucket from the
# source. tfsec flags the target as "missing logging" of its own — ignored
# with rationale below to avoid an infinite-recursion / cost loop.
# tfsec:ignore:aws-s3-enable-bucket-logging
resource "aws_s3_bucket" "trail_access_logs" {
  bucket        = "${local.bucket_name}-access-logs"
  force_destroy = false
  tags          = merge(var.tags, { Purpose = "S3 access-log target for ${local.bucket_name}" })
}

resource "aws_s3_bucket_public_access_block" "trail_access_logs" {
  bucket                  = aws_s3_bucket.trail_access_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "trail_access_logs" {
  bucket = aws_s3_bucket.trail_access_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 access-log delivery from the S3 service principal does not support
# SSE-KMS — only SSE-S3 (AES256) writes are accepted on the target bucket.
# tfsec:ignore:aws-s3-encryption-customer-key
resource "aws_s3_bucket_server_side_encryption_configuration" "trail_access_logs" {
  bucket = aws_s3_bucket.trail_access_logs.id

  rule {
    apply_server_side_encryption_by_default {
      # Access-log delivery uses SSE-S3 (AES256) per AWS requirement; SSE-KMS
      # is not supported for log-delivery writes from the S3 service principal.
      sse_algorithm = "AES256"
    }
    # bucket_key_enabled is only valid for SSE-KMS; omitted (defaults false)
    # to avoid PutBucketEncryption rejection on AES256 buckets.
  }
}

# Grant the S3 log-delivery service principal permission to write access logs
# into the target bucket. Without this policy, S3 log delivery is silently
# rejected on buckets where object ACLs are disabled (the default since 2023).
data "aws_iam_policy_document" "trail_access_logs" {
  statement {
    sid    = "S3LogDeliveryWrite"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["logging.s3.amazonaws.com"]
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.trail_access_logs.arn}/*"]
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [aws_s3_bucket.trail.arn]
    }
  }

  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.trail_access_logs.arn, "${aws_s3_bucket.trail_access_logs.arn}/*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "trail_access_logs" {
  bucket = aws_s3_bucket.trail_access_logs.id
  policy = data.aws_iam_policy_document.trail_access_logs.json
}

# Lifecycle: transition access logs to IA at 30 days, GLACIER at 90 days,
# expire at 365 days. S3 access logs accumulate quickly; this caps storage
# cost without losing the recent operational window.
resource "aws_s3_bucket_lifecycle_configuration" "trail_access_logs" {
  bucket = aws_s3_bucket.trail_access_logs.id

  rule {
    id     = "expire-access-logs"
    status = "Enabled"

    filter {}

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
    transition {
      days          = 90
      storage_class = "GLACIER"
    }
    expiration {
      days = 365
    }
    noncurrent_version_expiration {
      noncurrent_days = 90
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_s3_bucket_logging" "trail" {
  bucket        = aws_s3_bucket.trail.id
  target_bucket = aws_s3_bucket.trail_access_logs.id
  target_prefix = "trail-bucket-access/"
}

resource "aws_s3_bucket_public_access_block" "trail" {
  bucket                  = aws_s3_bucket.trail.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "trail" {
  bucket = aws_s3_bucket.trail.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "trail" {
  bucket = aws_s3_bucket.trail.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_object_lock_configuration" "trail" {
  bucket = aws_s3_bucket.trail.id

  rule {
    default_retention {
      mode  = "GOVERNANCE"
      years = var.object_lock_retention_years
    }
  }

  # Object Lock requires versioning to be enabled. Terraform doesn't infer
  # this dependency from the resource graph (both reference only the bucket),
  # so without an explicit depends_on a fresh apply can race and fail with
  # "Versioning must be enabled" on the Object Lock configuration.
  depends_on = [aws_s3_bucket_versioning.trail]
}

data "aws_iam_policy_document" "trail_bucket" {
  statement {
    sid    = "AWSCloudTrailAclCheck"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.trail.arn]
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = ["arn:${data.aws_partition.current.partition}:cloudtrail:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:trail/${var.name}"]
    }
  }

  statement {
    sid    = "AWSCloudTrailWrite"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.trail.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"]
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = ["arn:${data.aws_partition.current.partition}:cloudtrail:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:trail/${var.name}"]
    }
  }

  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.trail.arn, "${aws_s3_bucket.trail.arn}/*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "trail" {
  bucket = aws_s3_bucket.trail.id
  policy = data.aws_iam_policy_document.trail_bucket.json
}

# -----------------------------------------------------------------------------
# CloudWatch Logs target — KMS-encrypted.
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "trail" {
  name              = local.log_group
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn
  tags              = var.tags
}

data "aws_iam_policy_document" "cwlogs_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cwlogs" {
  name               = "${var.name}-cloudtrail-cwlogs"
  assume_role_policy = data.aws_iam_policy_document.cwlogs_assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "cwlogs" {
  statement {
    effect  = "Allow"
    actions = ["logs:CreateLogStream", "logs:PutLogEvents"]
    # The `:*` suffix on the log-group ARN scopes to log-streams *within this
    # one log group*. CloudTrail creates log streams dynamically (one per
    # account/region) and they cannot be enumerated at terraform plan time.
    # The wildcard is required by the service contract.
    # tfsec:ignore:aws-iam-no-policy-wildcards
    resources = ["${aws_cloudwatch_log_group.trail.arn}:*"]
  }
}

resource "aws_iam_role_policy" "cwlogs" {
  name   = "${var.name}-cloudtrail-cwlogs"
  role   = aws_iam_role.cwlogs.id
  policy = data.aws_iam_policy_document.cwlogs.json
}

# -----------------------------------------------------------------------------
# Trail itself.
# -----------------------------------------------------------------------------
resource "aws_cloudtrail" "this" {
  name                          = var.name
  s3_bucket_name                = aws_s3_bucket.trail.id
  include_global_service_events = true
  is_multi_region_trail         = var.is_multi_region
  enable_log_file_validation    = var.enable_log_file_validation
  kms_key_id                    = var.kms_key_arn
  cloud_watch_logs_group_arn    = "${aws_cloudwatch_log_group.trail.arn}:*"
  cloud_watch_logs_role_arn     = aws_iam_role.cwlogs.arn
  tags                          = var.tags

  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }

  # Data-event selector(s) — CMMC AU controls (ISS-01).
  # Only emitted when callers pass a non-empty `data_event_resources` list,
  # so the demo root stays cost-stripped while govcloud captures S3 + Lambda
  # data plane activity.
  dynamic "event_selector" {
    for_each = length(var.data_event_resources) > 0 ? [1] : []
    content {
      read_write_type           = "All"
      include_management_events = false

      dynamic "data_resource" {
        for_each = var.data_event_resources
        content {
          type   = data_resource.value.type
          values = data_resource.value.values
        }
      }
    }
  }

  depends_on = [aws_s3_bucket_policy.trail]
}

# -----------------------------------------------------------------------------
# Metric filters — surface high-signal events.
# -----------------------------------------------------------------------------
locals {
  metric_filters = {
    root_login = {
      pattern = "{ $.userIdentity.type = \"Root\" && $.userIdentity.invokedBy NOT EXISTS && $.eventType != \"AwsServiceEvent\" }"
      name    = "RootAccountUsage"
    }
    iam_policy_change = {
      pattern = "{ ($.eventName = DeleteGroupPolicy) || ($.eventName = DeleteRolePolicy) || ($.eventName = DeleteUserPolicy) || ($.eventName = PutGroupPolicy) || ($.eventName = PutRolePolicy) || ($.eventName = PutUserPolicy) || ($.eventName = CreatePolicy) || ($.eventName = DeletePolicy) || ($.eventName = CreatePolicyVersion) || ($.eventName = DeletePolicyVersion) || ($.eventName = AttachRolePolicy) || ($.eventName = DetachRolePolicy) || ($.eventName = AttachUserPolicy) || ($.eventName = DetachUserPolicy) || ($.eventName = AttachGroupPolicy) || ($.eventName = DetachGroupPolicy) }"
      name    = "IAMPolicyChange"
    }
    # ConsoleLogin is emitted for both IAMUser and AssumedRole identities
    # (the latter covers SSO/identity-federation sign-ins). Filtering on
    # userIdentity.type missed the AssumedRole path entirely (ISS-03), so
    # an SSO user signing in without MFA at the IdP would not surface here.
    # Drop the type constraint and let the alarm fire on any successful
    # console sign-in that lacks MFAUsed=Yes.
    #
    # SSO/IAM Identity Center caveat (PR #13 codex P2): for federated
    # AssumedRole sessions, CloudTrail often omits
    # `additionalEventData.MFAUsed` even when the IdP enforced MFA, which
    # would produce false positives. Cross-check
    # `userIdentity.sessionContext.attributes.mfaAuthenticated` — when
    # the role was assumed from an MFA-authenticated session this is
    # "true", and the alarm should not fire. Both predicates use `!=`,
    # which CloudWatch metric filters evaluate as true when the field
    # is missing — so plain IAMUser logins (no sessionContext at all)
    # still match.
    console_no_mfa = {
      pattern = "{ ($.eventName = ConsoleLogin) && ($.responseElements.ConsoleLogin = \"Success\") && ($.additionalEventData.MFAUsed != \"Yes\") && ($.userIdentity.sessionContext.attributes.mfaAuthenticated != \"true\") }"
      name    = "ConsoleSignInWithoutMFA"
    }
    kms_key_disable = {
      pattern = "{ ($.eventSource = kms.amazonaws.com) && (($.eventName = DisableKey) || ($.eventName = ScheduleKeyDeletion)) }"
      name    = "KMSKeyDisableOrDelete"
    }
  }
}

resource "aws_cloudwatch_log_metric_filter" "this" {
  for_each       = local.metric_filters
  name           = each.value.name
  log_group_name = aws_cloudwatch_log_group.trail.name
  pattern        = each.value.pattern

  metric_transformation {
    name      = each.value.name
    namespace = "CMMC/CloudTrail"
    value     = "1"
  }
}
