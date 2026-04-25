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

# CloudTrail data events (CMMC AU controls — closes ISS-01).
#
# Management events alone do not record S3 GetObject / PutObject or Lambda
# Invoke calls. CMMC L2 AU.L2-3.3.1/3.3.2 expect data-plane visibility on
# CUI stores and CUI-processing functions. Pass a list of objects of the
# form `{ type = "AWS::S3::Object" | "AWS::Lambda::Function" | ...,
# values = ["arn:aws-us-gov:s3", "arn:aws-us-gov:s3:::specific-bucket/"] }`.
# Empty list (default) keeps backward compatibility for the demo root,
# where data events would add cost without compliance benefit (no CUI).
variable "data_event_resources" {
  description = "Data-event resources to record (S3 objects, Lambda functions, etc). Empty disables data events."
  type = list(object({
    type   = string
    values = list(string)
  }))
  default = []
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
