output "vpc_id" {
  description = "ID of the enclave VPC."
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs (workload tier)."
  value       = module.vpc.private_subnet_ids
}

output "data_subnet_ids" {
  description = "Data subnet IDs (databases, no NAT egress)."
  value       = module.vpc.data_subnet_ids
}

output "kms_key_arns" {
  description = "Map of logical name -> CMK ARN."
  value       = module.kms.key_arns
}

output "cloudtrail_arn" {
  description = "ARN of the management CloudTrail."
  value       = module.cloudtrail.trail_arn
}

output "guardduty_detector_id" {
  description = "GuardDuty detector ID."
  value       = module.guardduty.detector_id
}

output "config_recorder_name" {
  description = "AWS Config recorder name."
  value       = module.config.recorder_name
}

output "partition" {
  description = "Deployed partition (expect aws-us-gov)."
  value       = data.aws_partition.current.partition
}

output "account_id" {
  description = "Deployed account ID."
  value       = data.aws_caller_identity.current.account_id
}
