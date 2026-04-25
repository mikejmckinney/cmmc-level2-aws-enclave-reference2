data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}

locals {
  bucket_name = "${var.name}-${data.aws_caller_identity.current.account_id}"
}

# -----------------------------------------------------------------------------
# Delivery bucket.
# -----------------------------------------------------------------------------
resource "aws_s3_bucket" "delivery" {
  bucket        = local.bucket_name
  force_destroy = false
  tags          = var.tags
}

# Separate bucket that receives S3 access logs for the delivery bucket above.
# Per AWS guidance the access-log target must be a different bucket from the
# source. tfsec flags the target as "missing logging" of its own — ignored
# with rationale below to avoid an infinite-recursion / cost loop.
# tfsec:ignore:aws-s3-enable-bucket-logging
resource "aws_s3_bucket" "delivery_access_logs" {
  bucket        = "${local.bucket_name}-access-logs"
  force_destroy = false
  tags          = merge(var.tags, { Purpose = "S3 access-log target for ${local.bucket_name}" })
}

resource "aws_s3_bucket_public_access_block" "delivery_access_logs" {
  bucket                  = aws_s3_bucket.delivery_access_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "delivery_access_logs" {
  bucket = aws_s3_bucket.delivery_access_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 access-log delivery from the S3 service principal does not support
# SSE-KMS — only SSE-S3 (AES256) writes are accepted on the target bucket.
# tfsec:ignore:aws-s3-encryption-customer-key
resource "aws_s3_bucket_server_side_encryption_configuration" "delivery_access_logs" {
  bucket = aws_s3_bucket.delivery_access_logs.id

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
data "aws_iam_policy_document" "delivery_access_logs" {
  statement {
    sid    = "S3LogDeliveryWrite"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["logging.s3.amazonaws.com"]
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.delivery_access_logs.arn}/*"]
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [aws_s3_bucket.delivery.arn]
    }
  }

  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.delivery_access_logs.arn, "${aws_s3_bucket.delivery_access_logs.arn}/*"]
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

resource "aws_s3_bucket_policy" "delivery_access_logs" {
  bucket = aws_s3_bucket.delivery_access_logs.id
  policy = data.aws_iam_policy_document.delivery_access_logs.json
}

resource "aws_s3_bucket_logging" "delivery" {
  bucket        = aws_s3_bucket.delivery.id
  target_bucket = aws_s3_bucket.delivery_access_logs.id
  target_prefix = "delivery-bucket-access/"
}

resource "aws_s3_bucket_public_access_block" "delivery" {
  bucket                  = aws_s3_bucket.delivery.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "delivery" {
  bucket = aws_s3_bucket.delivery.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "delivery" {
  bucket = aws_s3_bucket.delivery.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

data "aws_iam_policy_document" "delivery" {
  statement {
    sid    = "AWSConfigBucketPermissionsCheck"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
    actions   = ["s3:GetBucketAcl", "s3:ListBucket"]
    resources = [aws_s3_bucket.delivery.arn]
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  statement {
    sid    = "AWSConfigBucketDelivery"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.delivery.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/Config/*"]
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }

  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.delivery.arn, "${aws_s3_bucket.delivery.arn}/*"]
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

resource "aws_s3_bucket_policy" "delivery" {
  bucket = aws_s3_bucket.delivery.id
  policy = data.aws_iam_policy_document.delivery.json
}

# -----------------------------------------------------------------------------
# Service-linked role assumed by Config.
# -----------------------------------------------------------------------------
data "aws_iam_policy_document" "config_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "config" {
  name               = "${var.name}-role"
  assume_role_policy = data.aws_iam_policy_document.config_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "config_managed" {
  role       = aws_iam_role.config.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWS_ConfigRole"
}

# -----------------------------------------------------------------------------
# Recorder + delivery channel.
# -----------------------------------------------------------------------------
resource "aws_config_configuration_recorder" "this" {
  name     = var.name
  role_arn = aws_iam_role.config.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = var.include_global_resource_types
  }
}

resource "aws_config_delivery_channel" "this" {
  name           = var.name
  s3_bucket_name = aws_s3_bucket.delivery.id

  snapshot_delivery_properties {
    delivery_frequency = var.delivery_frequency
  }

  depends_on = [aws_s3_bucket_policy.delivery]
}

resource "aws_config_configuration_recorder_status" "this" {
  name       = aws_config_configuration_recorder.this.name
  is_enabled = true
  depends_on = [aws_config_delivery_channel.this]
}

# -----------------------------------------------------------------------------
# Optional conformance pack — pass YAML body via var.conformance_pack_template_body.
# -----------------------------------------------------------------------------
resource "aws_config_conformance_pack" "nist_800_171" {
  count         = var.conformance_pack_template_body == null ? 0 : 1
  name          = "Operational-Best-Practices-for-NIST-800-171"
  template_body = var.conformance_pack_template_body
  depends_on    = [aws_config_configuration_recorder_status.this]
}
