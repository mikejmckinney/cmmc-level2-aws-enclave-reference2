data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  name_prefix = "cmmc-${var.environment}"
}

# -----------------------------------------------------------------------------
# Network
# -----------------------------------------------------------------------------
module "vpc" {
  source = "../modules/vpc"

  name                    = local.name_prefix
  cidr_block              = var.vpc_cidr
  az_count                = var.az_count
  enable_nat_gateway      = true
  flow_log_retention_days = var.log_retention_days
  kms_key_arn             = module.kms.key_arns["logs"]
}

# -----------------------------------------------------------------------------
# KMS — separate keys per data class.
# -----------------------------------------------------------------------------
module "kms" {
  source = "../modules/kms"

  name_prefix = local.name_prefix

  keys = {
    logs = {
      description       = "CMK for CloudTrail / CloudWatch Logs / Config delivery."
      additional_admins = var.kms_admin_principal_arns
      service_principals = [
        "cloudtrail.amazonaws.com",
        "logs.${var.region}.amazonaws.com",
      ]
    }
    data = {
      description       = "CMK for CUI data at rest (S3, EBS, RDS in workload modules)."
      additional_admins = var.kms_admin_principal_arns
    }
    config = {
      description       = "CMK for AWS Config delivery channel."
      additional_admins = var.kms_admin_principal_arns
      service_principals = [
        "config.amazonaws.com",
      ]
    }
  }
}

# -----------------------------------------------------------------------------
# IAM baseline + DenyNonFipsEndpoints (GovCloud: ON).
# -----------------------------------------------------------------------------
module "iam_baseline" {
  source = "../modules/iam_baseline"

  attach_deny_non_fips = true
  access_analyzer_name = "${local.name_prefix}-access-analyzer"
}

# -----------------------------------------------------------------------------
# CloudTrail — single-account multi-region trail.
# Org trail mode is intentionally NOT wired here; if you operate an
# organization, deploy the trail from the management account instead and
# disable this module.
# -----------------------------------------------------------------------------
module "cloudtrail" {
  source = "../modules/cloudtrail"

  name                        = var.trail_name
  kms_key_arn                 = module.kms.key_arns["logs"]
  log_retention_days          = var.log_retention_days
  object_lock_retention_years = var.object_lock_retention_years
  is_multi_region             = true

  # CMMC AU.L2-3.3.1/3.3.2 — record S3 object operations and Lambda
  # invocations across the partition (closes ISS-01). Scope by ARN prefix
  # so all S3 buckets and Lambda functions in the partition are captured.
  # The S3 prefix uses the explicit triple-colon bucket form
  # (`arn:<partition>:s3:::`) per CloudTrail data-event ARN syntax for
  # `AWS::S3::Object` (PR #13 copilot/gemini). Both `arn:<partition>:s3`
  # and `arn:<partition>:s3:::` match all buckets in the partition under
  # CloudTrail's prefix-match semantics; the triple-colon form avoids
  # ambiguity with the bare service ARN. The Lambda prefix
  # `arn:<partition>:lambda` is the documented account-wide form for
  # `AWS::Lambda::Function`.
  data_event_resources = [
    {
      type   = "AWS::S3::Object"
      values = ["arn:${data.aws_partition.current.partition}:s3:::"]
    },
    {
      type   = "AWS::Lambda::Function"
      values = ["arn:${data.aws_partition.current.partition}:lambda"]
    },
  ]
}

# -----------------------------------------------------------------------------
# GuardDuty — all features on.
# -----------------------------------------------------------------------------
module "guardduty" {
  source = "../modules/guardduty"

  enable = true
  # features defaults to all-true; GovCloud feature support is a moving
  # target — verify against current docs and override if any feature is
  # not yet GA in us-gov-west-1.
}

# -----------------------------------------------------------------------------
# Config — recorder + delivery + (optional) NIST 800-171 conformance pack.
# -----------------------------------------------------------------------------
module "config" {
  source = "../modules/config"

  name                           = "${local.name_prefix}-config"
  kms_key_arn                    = module.kms.key_arns["config"]
  include_global_resource_types  = true
  conformance_pack_template_body = var.config_conformance_pack_template_body
}

# -----------------------------------------------------------------------------
# CUI data bucket — first workload module from the Phase 8 library
# (prompt 11). Reference pattern only; consumers swap in their own name and
# wire workload IAM roles to consume it. The `data` KMS key declared above
# is finally used here — that's intentional, not vestigial.
# -----------------------------------------------------------------------------
module "s3_cui" {
  source = "../modules/workloads/s3_cui"

  name        = local.name_prefix
  kms_key_arn = module.kms.key_arns["data"]
}
