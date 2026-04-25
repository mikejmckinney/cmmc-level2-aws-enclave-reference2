variable "name" {
  description = "Logical name for the CUI bucket pair (used as bucket-name prefix). Must be DNS-compliant lowercase."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.name))
    error_message = "name must be 3-63 chars, lowercase alphanumerics + dashes, no leading/trailing dash."
  }
}

variable "kms_key_arn" {
  description = "ARN of the KMS CMK used to encrypt CUI objects (SSE-KMS). The access-log bucket uses SSE-S3 because S3 access-log delivery does not support SSE-KMS."
  type        = string
}

variable "versioning_enabled" {
  description = "Enable bucket versioning on the CUI bucket. Strongly recommended for CUI; defaults true."
  type        = bool
  default     = true
}

variable "transition_to_ia_days" {
  description = "Days after object creation before transition to STANDARD_IA. Set to 0 to disable transition."
  type        = number
  default     = 30

  validation {
    condition     = var.transition_to_ia_days >= 0 && var.transition_to_ia_days <= 3650
    error_message = "transition_to_ia_days must be between 0 and 3650."
  }
}

variable "expiration_days" {
  description = "Days after object creation before expiration. Default 2555 (~7 years) matches a common CUI baseline."
  type        = number
  default     = 2555

  validation {
    condition     = var.expiration_days > 0 && var.expiration_days <= 36500
    error_message = "expiration_days must be > 0 and <= 36500 (100 years)."
  }
}

variable "noncurrent_version_expiration_days" {
  description = "Days after which non-current object versions are deleted. 90 mirrors the CloudTrail module."
  type        = number
  default     = 90
}

variable "access_log_retention_days" {
  description = "Days to retain S3 access logs in the access-log bucket before expiration."
  type        = number
  default     = 365
}

variable "data_classification_tag" {
  description = "Value of the data_classification tag the bucket policy enforces on PutObject. Defaults to 'cui'."
  type        = string
  default     = "cui"

  validation {
    condition     = length(var.data_classification_tag) > 0
    error_message = "data_classification_tag must be non-empty."
  }
}

variable "tags" {
  description = "Tags applied to all resources. data_classification is added automatically if not present."
  type        = map(string)
  default     = {}
}
