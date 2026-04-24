variable "name" {
  description = "Name for the trail and supporting resources."
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of the KMS CMK used to encrypt CloudTrail logs (both S3 SSE-KMS and CloudWatch Logs)."
  type        = string
}

variable "log_retention_days" {
  description = "Retention for the CloudWatch Logs group (in days). CMMC L2 expects >= 90; default 365."
  type        = number
  default     = 365
}

variable "object_lock_retention_years" {
  description = "Object Lock retention period in years (governance mode). 7 years is a common CUI baseline."
  type        = number
  default     = 7
}

variable "enable_log_file_validation" {
  description = "Enable CloudTrail log-file integrity validation (digest files)."
  type        = bool
  default     = true
}

variable "is_multi_region" {
  description = "Multi-region trail. Set true for the management account / org trail."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
