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
  kms_key_arn             = module.kms.key_arns["logs"]
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

# VPC ENI management permissions for Lambda — required when vpc_config is
# attached (ISS-04). AWSLambdaVPCAccessExecutionRole is a superset of
# AWSLambdaBasicExecutionRole; we keep the basic attachment for explicit
# parity with non-VPC Lambdas elsewhere in the demo.
resource "aws_iam_role_policy_attachment" "demo_lambda_vpc" {
  role       = aws_iam_role.demo_lambda.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# X-Ray tracing permissions (ISS-28). Required for the function's
# tracing_config below to actually emit segments.
resource "aws_iam_role_policy_attachment" "demo_lambda_xray" {
  role       = aws_iam_role.demo_lambda.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

# Security group attached to the demo Lambda's ENIs. Egress is restricted
# to the VPC CIDR so the function can only reach the interface endpoints
# (no internet path; demo VPC has no NAT). Closes ISS-04 by demonstrating
# the enclave network model on the only workload in the demo stack.
resource "aws_security_group" "demo_lambda" {
  name        = "${local.name_prefix}-page-lambda"
  description = "Demo page Lambda \u2014 egress restricted to VPC CIDR (no internet)."
  vpc_id      = module.vpc.vpc_id
  tags        = { Name = "${local.name_prefix}-page-lambda" }
}

# Egress is intentionally restricted to TCP/443 within the VPC CIDR — VPC
# interface endpoints (logs, monitoring, sts, kms, ssm*, ec2*, xray) terminate
# HTTPS on private IPs in the same subnets, and that's the only outbound the
# demo Lambda needs (PR #13 copilot/gemini sec-MED). The previous
# `ip_protocol = "-1"` rule allowed every protocol/port to the entire VPC,
# which was broader than the comment claimed.
resource "aws_vpc_security_group_egress_rule" "demo_lambda_to_vpc_https" {
  security_group_id = aws_security_group.demo_lambda.id
  description       = "Allow Lambda \u2192 VPC interface endpoints (HTTPS only)."
  cidr_ipv4         = module.vpc.vpc_cidr_block
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
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

  # ISS-04: run inside the demo VPC's private subnets so the demo
  # mirrors the enclave network model (Lambda has no direct internet
  # path; reaches AWS APIs via VPC interface endpoints).
  vpc_config {
    subnet_ids         = module.vpc.private_subnet_ids
    security_group_ids = [aws_security_group.demo_lambda.id]
  }

  # ISS-28: Active X-Ray tracing on the only workload in the demo so the
  # CMMC SI controls can be evidenced end-to-end.
  tracing_config {
    mode = "Active"
  }

  depends_on = [
    aws_iam_role_policy_attachment.demo_lambda_basic,
    aws_iam_role_policy_attachment.demo_lambda_vpc,
    aws_iam_role_policy_attachment.demo_lambda_xray,
  ]
}

resource "aws_lambda_function_url" "demo_page" {
  function_name      = aws_lambda_function.demo_page.function_name
  authorization_type = "NONE"
}

# -----------------------------------------------------------------------------
# CUI data bucket — Phase 8 workload-module sample (prompt 11). Stamped in the
# demo so a `terraform validate` / `apply` exercises the module end-to-end and
# the demo-destroy workflow exercises its teardown. No CUI is ever stored
# here (demo carries the "NOT A CUI ENCLAVE" disclaimer); the bucket is wired
# only for parity-of-shape with the GovCloud root.
#
# Demo overrides:
# - expiration_days = 30  (test data must not accumulate / cost)
# - tags include Project = "cmmc-enclave-demo" so demo-destroy and the
#   verify-destroy assertion can tag-filter cleanup.
# -----------------------------------------------------------------------------
module "s3_cui" {
  source = "../modules/workloads/s3_cui"

  name        = local.name_prefix
  kms_key_arn = module.kms.key_arns["data"]

  expiration_days           = 30
  access_log_retention_days = 30

  tags = {
    Project = "cmmc-enclave-demo"
  }
}
