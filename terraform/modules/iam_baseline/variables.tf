variable "minimum_password_length" {
  description = "Minimum length for IAM user passwords."
  type        = number
  default     = 14
  validation {
    condition     = var.minimum_password_length >= 14
    error_message = "Per CMMC L2 / NIST SP 800-171 3.5.7, password length must be >= 14."
  }
}

variable "max_password_age" {
  description = "Days before IAM users must rotate passwords."
  type        = number
  default     = 90
}

variable "password_reuse_prevention" {
  description = "Number of previous passwords an IAM user cannot reuse."
  type        = number
  default     = 24
}

variable "attach_deny_non_fips" {
  description = "Whether to create the customer-managed DenyNonFipsEndpoints policy. Set true in GovCloud roots, false in commercial demo roots (commercial doesn't have universal FIPS endpoints across all services)."
  type        = bool
  default     = true
}

variable "access_analyzer_name" {
  description = "Name for the IAM Access Analyzer."
  type        = string
  default     = "account-analyzer"
}

variable "tags" {
  description = "Tags applied to taggable resources."
  type        = map(string)
  default     = {}
}
