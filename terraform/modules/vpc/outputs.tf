output "vpc_id" {
  description = "ID of the created VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets (one per AZ)."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private/app subnets (one per AZ)."
  value       = aws_subnet.private[*].id
}

output "data_subnet_ids" {
  description = "IDs of the data subnets (one per AZ)."
  value       = aws_subnet.data[*].id
}

output "endpoint_security_group_id" {
  description = "Security group attached to all interface VPC endpoints."
  value       = aws_security_group.endpoints.id
}

output "flow_log_group_name" {
  description = "CloudWatch Log Group receiving VPC Flow Logs."
  value       = aws_cloudwatch_log_group.flow.name
}

output "partition" {
  description = "AWS partition this module deployed into (aws or aws-us-gov)."
  value       = data.aws_partition.current.partition
}
