data "aws_partition" "current" {}
data "aws_region" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  # /20 subnets carved from a /16: 16 per tier, far more than az_count needs.
  public_subnets  = [for i, az in local.azs : cidrsubnet(var.cidr_block, 4, i)]
  private_subnets = [for i, az in local.azs : cidrsubnet(var.cidr_block, 4, i + 4)]
  data_subnets    = [for i, az in local.azs : cidrsubnet(var.cidr_block, 4, i + 8)]

  interface_endpoints = toset([
    "ssm",
    "ssmmessages",
    "ec2messages",
    "kms",
    "logs",
    "monitoring",
    "sts",
    "ec2",
  ])
}

resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(var.tags, { Name = var.name })
}

# ── Subnets ────────────────────────────────────────────────────────────────
resource "aws_subnet" "public" {
  count                   = var.az_count
  vpc_id                  = aws_vpc.this.id
  cidr_block              = local.public_subnets[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = false
  tags                    = merge(var.tags, { Name = "${var.name}-public-${local.azs[count.index]}", Tier = "public" })
}

resource "aws_subnet" "private" {
  count             = var.az_count
  vpc_id            = aws_vpc.this.id
  cidr_block        = local.private_subnets[count.index]
  availability_zone = local.azs[count.index]
  tags              = merge(var.tags, { Name = "${var.name}-private-${local.azs[count.index]}", Tier = "private" })
}

resource "aws_subnet" "data" {
  count             = var.az_count
  vpc_id            = aws_vpc.this.id
  cidr_block        = local.data_subnets[count.index]
  availability_zone = local.azs[count.index]
  tags              = merge(var.tags, { Name = "${var.name}-data-${local.azs[count.index]}", Tier = "data" })
}

# ── Internet + NAT ─────────────────────────────────────────────────────────
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name}-igw" })
}

resource "aws_eip" "nat" {
  count  = var.enable_nat_gateway ? var.az_count : 0
  domain = "vpc"
  tags   = merge(var.tags, { Name = "${var.name}-nat-${local.azs[count.index]}" })
}

resource "aws_nat_gateway" "this" {
  count         = var.enable_nat_gateway ? var.az_count : 0
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  tags          = merge(var.tags, { Name = "${var.name}-nat-${local.azs[count.index]}" })
  depends_on    = [aws_internet_gateway.this]
}

# ── Route tables ───────────────────────────────────────────────────────────
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
  tags = merge(var.tags, { Name = "${var.name}-public" })
}

resource "aws_route_table_association" "public" {
  count          = var.az_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  count  = var.az_count
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name}-private-${local.azs[count.index]}" })
}

resource "aws_route" "private_nat" {
  count                  = var.enable_nat_gateway ? var.az_count : 0
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[count.index].id
}

resource "aws_route_table_association" "private" {
  count          = var.az_count
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# Data subnets get their own route tables with NO default route. Egress to AWS
# services flows over VPC endpoints only.
resource "aws_route_table" "data" {
  count  = var.az_count
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name}-data-${local.azs[count.index]}" })
}

resource "aws_route_table_association" "data" {
  count          = var.az_count
  subnet_id      = aws_subnet.data[count.index].id
  route_table_id = aws_route_table.data[count.index].id
}

# ── VPC endpoints ──────────────────────────────────────────────────────────
resource "aws_security_group" "endpoints" {
  name_prefix = "${var.name}-endpoints-"
  description = "Allow HTTPS from VPC CIDR to interface VPC endpoints."
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.cidr_block]
  }

  egress {
    description = "Return traffic to VPC CIDR (intra-VPC interface-endpoint replies)."
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.cidr_block]
  }

  tags = merge(var.tags, { Name = "${var.name}-endpoints" })
}

resource "aws_vpc_endpoint" "interface" {
  for_each = local.interface_endpoints

  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${data.aws_region.current.region}.${each.key}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true
  tags                = merge(var.tags, { Name = "${var.name}-${each.key}" })
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = concat(aws_route_table.private[*].id, aws_route_table.data[*].id)
  tags              = merge(var.tags, { Name = "${var.name}-s3" })
}

resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = concat(aws_route_table.private[*].id, aws_route_table.data[*].id)
  tags              = merge(var.tags, { Name = "${var.name}-dynamodb" })
}

# ── Flow logs ──────────────────────────────────────────────────────────────
resource "aws_cloudwatch_log_group" "flow" {
  name              = "/aws/vpc/${var.name}/flow-logs"
  retention_in_days = var.flow_log_retention_days
  kms_key_id        = var.kms_key_arn
  tags              = var.tags
}

data "aws_iam_policy_document" "flow_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "flow_publish" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
    ]
    # The `:*` suffix on the log-group ARN scopes to log-streams *within this
    # one log group*. CloudWatch Logs streams are created dynamically by VPC
    # Flow Logs (one per ENI per hour) and cannot be enumerated at terraform
    # plan time. The wildcard is required by the service contract; this is
    # not a least-privilege violation.
    # tfsec:ignore:aws-iam-no-policy-wildcards
    resources = ["${aws_cloudwatch_log_group.flow.arn}:*"]
  }
}

resource "aws_iam_role" "flow" {
  name_prefix        = "${var.name}-flow-"
  assume_role_policy = data.aws_iam_policy_document.flow_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy" "flow" {
  name_prefix = "${var.name}-flow-"
  role        = aws_iam_role.flow.id
  policy      = data.aws_iam_policy_document.flow_publish.json
}

resource "aws_flow_log" "this" {
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.flow.arn
  iam_role_arn         = aws_iam_role.flow.arn
  vpc_id               = aws_vpc.this.id
  traffic_type         = "ALL"
  tags                 = var.tags
}
