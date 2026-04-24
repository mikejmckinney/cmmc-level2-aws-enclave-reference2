output "password_policy_id" {
  description = "ID of the account password policy."
  value       = aws_iam_account_password_policy.this.id
}

output "access_analyzer_arn" {
  description = "ARN of the IAM Access Analyzer."
  value       = aws_accessanalyzer_analyzer.account.arn
}

output "deny_non_fips_policy_arn" {
  description = "ARN of the DenyNonFipsEndpoints policy, or null if disabled."
  value       = var.attach_deny_non_fips ? aws_iam_policy.deny_non_fips[0].arn : null
}

output "partition" {
  description = "AWS partition this module deployed into."
  value       = data.aws_partition.current.partition
}
