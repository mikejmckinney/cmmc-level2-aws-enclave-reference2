# `vpc` module

3-tier VPC (public / private / data) with VPC endpoints, flow logs, and
optional NAT Gateways. Partition-aware via `data.aws_partition.current`.

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `name` | string | — | Name prefix for all resources |
| `cidr_block` | string | `10.20.0.0/16` | VPC CIDR (carved into /20 subnets per tier per AZ) |
| `az_count` | number | `2` | 2 or 3 AZs |
| `enable_nat_gateway` | bool | `true` | Per-AZ NAT Gateway. Set `false` to force VPC-endpoint-only egress |
| `flow_log_retention_days` | number | `365` | CloudWatch Logs retention for flow logs |
| `tags` | map(string) | `{}` | Applied to every created resource |

## Outputs

`vpc_id`, `vpc_cidr_block`, `public_subnet_ids`, `private_subnet_ids`,
`data_subnet_ids`, `endpoint_security_group_id`, `flow_log_group_name`,
`partition`.

## Architecture notes

- **Public subnets** route to an Internet Gateway. No public IPs are
  auto-assigned (`map_public_ip_on_launch = false`); only the ALB lives here.
- **Private subnets** route to per-AZ NAT Gateways when
  `enable_nat_gateway = true`. With NAT disabled, workloads must reach AWS
  services exclusively through the VPC endpoints.
- **Data subnets** have no default route. Egress to AWS services is via the
  S3/DynamoDB Gateway endpoints attached to their route tables.
- **Interface VPC endpoints** (`ssm`, `ssmmessages`, `ec2messages`, `kms`,
  `logs`, `monitoring`, `sts`, `ec2`) live in the private subnets and serve
  the whole VPC via private DNS. In AWS GovCloud these resolve to FIPS
  endpoints automatically when the provider has `use_fips_endpoint = true`.
- **VPC Flow Logs** capture ALL traffic to a per-VPC CloudWatch Log Group
  with a configurable retention window.

## NIST SP 800-171 r2 controls this module helps satisfy

| Control | Why |
|---|---|
| 3.1.3 — Control flow of CUI | Subnet tiering + restricted route tables for data subnets |
| 3.13.1 — Monitor / control communications at boundaries | VPC + SG defaults + private endpoints |
| 3.13.5 — Implement subnetworks for publicly accessible components | Public/private/data tiering |
| 3.13.6 — Deny by default at boundaries | Data subnet route tables have no default route |
| 3.14.6 — Monitor system for attacks | VPC Flow Logs into CloudWatch (consumed by `cloudtrail` + GuardDuty modules) |

## Gaps the consumer must fill

- Workload security groups (this module only creates an endpoint SG).
- Network ACLs beyond AWS defaults.
- TGW / Direct Connect attachments for hybrid connectivity.
- Per-workload route additions (e.g., to on-prem CIDRs).
- Egress filtering through a managed proxy / firewall, if required.
