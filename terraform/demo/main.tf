data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  name_prefix = var.name
}

# -----------------------------------------------------------------------------
# Network — no NAT, rely on VPC endpoints + Lambda.
# -----------------------------------------------------------------------------
module "vpc" {
  source = "../modules/vpc"

  name                    = local.name_prefix
  cidr_block              = var.vpc_cidr
  az_count                = var.az_count
  enable_nat_gateway      = false
  flow_log_retention_days = var.log_retention_days
}

# -----------------------------------------------------------------------------
# KMS — 2 keys for the demo.
# -----------------------------------------------------------------------------
module "kms" {
  source = "../modules/kms"

  name_prefix = local.name_prefix

  keys = {
    logs = {
      description = "Demo CMK for logs / CloudTrail / Lambda env vars."
      service_principals = [
        "cloudtrail.amazonaws.com",
        "logs.${var.region}.amazonaws.com",
      ]
    }
    data = {
      description = "Demo CMK for data at rest (none in this demo, but stamped for parity)."
    }
  }
}

# -----------------------------------------------------------------------------
# IAM baseline — DenyNonFipsEndpoints OFF for commercial.
# -----------------------------------------------------------------------------
module "iam_baseline" {
  source = "../modules/iam_baseline"

  attach_deny_non_fips = false
  access_analyzer_name = "${local.name_prefix}-access-analyzer"
}

# -----------------------------------------------------------------------------
# CloudTrail — single-region for cost.
# -----------------------------------------------------------------------------
module "cloudtrail" {
  source = "../modules/cloudtrail"

  name                        = var.trail_name
  kms_key_arn                 = module.kms.key_arns["logs"]
  log_retention_days          = var.log_retention_days
  object_lock_retention_years = var.object_lock_retention_years
  is_multi_region             = false
}

# -----------------------------------------------------------------------------
# GuardDuty — off by default in demo.
# -----------------------------------------------------------------------------
module "guardduty" {
  source = "../modules/guardduty"

  enable = var.enable_guardduty
  features = {
    S3_DATA_EVENTS         = var.enable_guardduty_extras
    EKS_AUDIT_LOGS         = var.enable_guardduty_extras
    EBS_MALWARE_PROTECTION = var.enable_guardduty_extras
    RDS_LOGIN_EVENTS       = var.enable_guardduty_extras
    LAMBDA_NETWORK_LOGS    = var.enable_guardduty_extras
    EKS_RUNTIME_MONITORING = var.enable_guardduty_extras
  }
}

# -----------------------------------------------------------------------------
# Demo workload — Lambda + Function URL serving the disclaimer page.
# -----------------------------------------------------------------------------
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/index.py"
  output_path = "${path.module}/.build/lambda.zip"
}

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "demo_lambda" {
  name               = "${local.name_prefix}-page"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "demo_lambda_basic" {
  role       = aws_iam_role.demo_lambda.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "demo_page" {
  function_name    = "${local.name_prefix}-page"
  role             = aws_iam_role.demo_lambda.arn
  handler          = "index.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = 5
  memory_size      = 128
}

resource "aws_lambda_function_url" "demo_page" {
  function_name      = aws_lambda_function.demo_page.function_name
  authorization_type = "NONE"
}
