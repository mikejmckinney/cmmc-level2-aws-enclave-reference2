data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  # Account-suffixed bucket names avoid collision in shared partitions and
  # mirror the cloudtrail module's naming convention.
  bucket_name        = "${var.name}-cui-${data.aws_caller_identity.current.account_id}"
  access_logs_bucket = "${local.bucket_name}-access-logs"

  # Always merge the data_classification tag onto every resource so users
  # auditing by tag (e.g. AWS Config queries) see CUI material consistently.
  tags = merge(
    { data_classification = var.data_classification_tag },
    var.tags,
  )
}

# -----------------------------------------------------------------------------
# CUI bucket — KMS SSE, versioning, public-access block, classification policy
# -----------------------------------------------------------------------------

resource "aws_s3_bucket" "cui" {
  bucket        = local.bucket_name
  force_destroy = false
  tags          = local.tags

  # Partition gate (ADR-011 §3): both `aws` and `aws-us-gov` support every
  # feature this module uses; fail closed for any other partition (e.g.
  # `aws-cn`) at validate time so callers don't discover the gap on apply.
  lifecycle {
    precondition {
      condition     = contains(["aws", "aws-us-gov"], data.aws_partition.current.partition)
      error_message = "s3_cui supports the 'aws' and 'aws-us-gov' partitions only; got '${data.aws_partition.current.partition}'."
    }
  }
}

resource "aws_s3_bucket_public_access_block" "cui" {
  bucket                  = aws_s3_bucket.cui.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "cui" {
  bucket = aws_s3_bucket.cui.id
  versioning_configuration {
    status = var.versioning_enabled ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cui" {
  bucket = aws_s3_bucket.cui.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    # bucket_key_enabled cuts SSE-KMS request cost ~99% by caching a per-bucket
    # data key; safe for single-key buckets like this one.
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_logging" "cui" {
  bucket        = aws_s3_bucket.cui.id
  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "${local.bucket_name}/"
}

resource "aws_s3_bucket_lifecycle_configuration" "cui" {
  bucket = aws_s3_bucket.cui.id

  rule {
    id     = "cui-lifecycle"
    status = "Enabled"

    filter {}

    # Skip transition entirely if the caller set transition_to_ia_days = 0.
    dynamic "transition" {
      for_each = var.transition_to_ia_days > 0 ? [1] : []
      content {
        days          = var.transition_to_ia_days
        storage_class = "STANDARD_IA"
      }
    }

    expiration {
      days = var.expiration_days
    }

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_expiration_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# Bucket policy: deny non-TLS + deny PutObject lacking the classification tag.
data "aws_iam_policy_document" "cui" {
  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.cui.arn, "${aws_s3_bucket.cui.arn}/*"]
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

  # Enforces the data-classification tag at upload time. Without this, an
  # IAM principal with `s3:PutObject` could put untagged objects into the
  # CUI bucket, defeating tag-based AWS Config / Macie / Athena queries.
  # `s3:RequestObjectTag/<key>` matches the request's tag value; absence
  # of the tag fails StringNotEquals (object would be untagged).
  statement {
    sid       = "DenyPutObjectWithoutClassificationTag"
    effect    = "Deny"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.cui.arn}/*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "StringNotEquals"
      variable = "s3:RequestObjectTag/data_classification"
      values   = [var.data_classification_tag]
    }
  }

  # Companion to the put-object guard: prevent removing the classification
  # tag once set. An attacker who couldn't bypass the upload guard might
  # try to wipe tags afterward to hide objects from audit queries.
  statement {
    sid       = "DenyTagRemoval"
    effect    = "Deny"
    actions   = ["s3:DeleteObjectTagging"]
    resources = ["${aws_s3_bucket.cui.arn}/*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

resource "aws_s3_bucket_policy" "cui" {
  bucket = aws_s3_bucket.cui.id
  policy = data.aws_iam_policy_document.cui.json
}

# -----------------------------------------------------------------------------
# Access-log target bucket. Per AWS guidance the access-log target must be a
# different bucket from the source. tfsec flags the target as "missing
# logging" of its own — ignored to avoid an infinite-recursion / cost loop
# (same rationale as the cloudtrail module).
# -----------------------------------------------------------------------------
# tfsec:ignore:aws-s3-enable-bucket-logging
resource "aws_s3_bucket" "access_logs" {
  bucket        = local.access_logs_bucket
  force_destroy = false
  tags          = merge(local.tags, { Purpose = "S3 access-log target for ${local.bucket_name}" })
}

resource "aws_s3_bucket_public_access_block" "access_logs" {
  bucket                  = aws_s3_bucket.access_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 access-log delivery from the S3 service principal does not support
# SSE-KMS — only SSE-S3 (AES256) writes are accepted on the target bucket.
# tfsec:ignore:aws-s3-encryption-customer-key
resource "aws_s3_bucket_server_side_encryption_configuration" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

data "aws_iam_policy_document" "access_logs" {
  statement {
    sid    = "S3LogDeliveryWrite"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["logging.s3.amazonaws.com"]
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.access_logs.arn}/*"]
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [aws_s3_bucket.cui.arn]
    }
  }

  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.access_logs.arn, "${aws_s3_bucket.access_logs.arn}/*"]
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

resource "aws_s3_bucket_policy" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id
  policy = data.aws_iam_policy_document.access_logs.json
}

resource "aws_s3_bucket_lifecycle_configuration" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

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
      days = var.access_log_retention_days
    }
    noncurrent_version_expiration {
      noncurrent_days = 90
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}
