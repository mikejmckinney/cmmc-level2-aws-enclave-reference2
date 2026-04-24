output "demo_url" {
  description = "Public Function URL serving the demo page."
  value       = aws_lambda_function_url.demo_page.function_url
}

output "warning" {
  description = "Reminder that this is NOT A CUI ENCLAVE."
  value       = "DEMO ENVIRONMENT — NOT A CUI ENCLAVE. Do not upload real CUI. See terraform/govcloud/ for the CUI-grade configuration."
}

output "vpc_id" {
  description = "Demo VPC ID."
  value       = module.vpc.vpc_id
}

output "kms_key_arns" {
  description = "Demo CMK ARNs."
  value       = module.kms.key_arns
}

output "cloudtrail_arn" {
  description = "Demo CloudTrail ARN."
  value       = module.cloudtrail.trail_arn
}

output "partition" {
  description = "Deployed partition (expect aws)."
  value       = data.aws_partition.current.partition
}

output "account_id" {
  description = "Deployed account ID."
  value       = data.aws_caller_identity.current.account_id
}
