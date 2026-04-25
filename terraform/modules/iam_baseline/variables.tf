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

variable "fips_allowed_regions" {
  description = "AWS regions whose service endpoints are FIPS 140-2 / 140-3 validated by default. The DenyNonFipsEndpoints policy denies any API call whose aws:RequestedRegion is NOT in this list. GovCloud regions (us-gov-west-1, us-gov-east-1) serve FIPS endpoints by default, so restricting requests to these regions is the actual FIPS enforcement mechanism. Override only if AWS publishes additional FIPS-by-default regions."
  type        = list(string)
  default     = ["us-gov-west-1", "us-gov-east-1"]
  validation {
    condition     = length(var.fips_allowed_regions) > 0
    error_message = "fips_allowed_regions must contain at least one region."
  }
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
