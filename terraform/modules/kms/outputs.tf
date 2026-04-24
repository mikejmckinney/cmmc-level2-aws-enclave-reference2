output "key_arns" {
  description = "Map of logical key name → KMS key ARN."
  value       = { for k, v in aws_kms_key.this : k => v.arn }
}

output "key_ids" {
  description = "Map of logical key name → KMS key ID."
  value       = { for k, v in aws_kms_key.this : k => v.key_id }
}

output "alias_names" {
  description = "Map of logical key name → KMS alias."
  value       = { for k, v in aws_kms_alias.this : k => v.name }
}

output "partition" {
  description = "AWS partition this module deployed into."
  value       = data.aws_partition.current.partition
}
