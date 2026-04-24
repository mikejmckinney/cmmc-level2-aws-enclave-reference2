output "detector_id" {
  description = "GuardDuty detector ID, or null if disabled."
  value       = var.enable ? aws_guardduty_detector.this[0].id : null
}

output "detector_arn" {
  description = "GuardDuty detector ARN, or null if disabled."
  value       = var.enable ? aws_guardduty_detector.this[0].arn : null
}

output "enabled_features" {
  description = "Map of feature name -> ENABLED/DISABLED status that this module configured."
  value       = { for k, v in var.features : k => (v ? "ENABLED" : "DISABLED") }
}

output "partition" {
  description = "AWS partition this module deployed into."
  value       = data.aws_partition.current.partition
}
