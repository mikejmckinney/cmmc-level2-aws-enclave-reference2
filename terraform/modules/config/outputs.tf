output "recorder_name" {
  description = "Name of the Config configuration recorder."
  value       = aws_config_configuration_recorder.this.name
}

output "delivery_channel_name" {
  description = "Name of the Config delivery channel."
  value       = aws_config_delivery_channel.this.name
}

output "delivery_bucket_name" {
  description = "S3 bucket receiving Config snapshots and history."
  value       = aws_s3_bucket.delivery.id
}

output "delivery_bucket_arn" {
  description = "ARN of the Config delivery bucket."
  value       = aws_s3_bucket.delivery.arn
}

output "config_role_arn" {
  description = "ARN of the IAM role assumed by AWS Config."
  value       = aws_iam_role.config.arn
}

output "conformance_pack_arn" {
  description = "ARN of the NIST 800-171 conformance pack, or null if none."
  value       = var.conformance_pack_template_body == null ? null : aws_config_conformance_pack.nist_800_171[0].arn
}

output "partition" {
  description = "AWS partition this module deployed into."
  value       = data.aws_partition.current.partition
}
