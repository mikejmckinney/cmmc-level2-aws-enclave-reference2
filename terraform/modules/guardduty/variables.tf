variable "enable" {
  description = "Master switch. Set false to leave GuardDuty disabled (e.g. cost-sensitive demo)."
  type        = bool
  default     = true
}

variable "finding_publishing_frequency" {
  description = "How often findings are exported (FIFTEEN_MINUTES, ONE_HOUR, SIX_HOURS)."
  type        = string
  default     = "FIFTEEN_MINUTES"
}

variable "features" {
  description = <<-EOT
    Map of optional GuardDuty features to enable. Keys must be valid GuardDuty feature names
    (e.g. S3_DATA_EVENTS, EKS_AUDIT_LOGS, EBS_MALWARE_PROTECTION, RDS_LOGIN_EVENTS,
    LAMBDA_NETWORK_LOGS, EKS_RUNTIME_MONITORING). Set value to false to explicitly disable.

    Defaults to all-true; the demo root overrides to all-false to control cost.
  EOT
  type        = map(bool)
  default = {
    S3_DATA_EVENTS         = true
    EKS_AUDIT_LOGS         = true
    EBS_MALWARE_PROTECTION = true
    RDS_LOGIN_EVENTS       = true
    LAMBDA_NETWORK_LOGS    = true
    EKS_RUNTIME_MONITORING = true
  }
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
