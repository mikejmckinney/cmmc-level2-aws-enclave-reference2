variable "name_prefix" {
  description = "Prefix applied to alias names. Aliases are 'alias/<name_prefix>-<key_name>'."
  type        = string
}

variable "keys" {
  description = "Map of logical key name → key configuration. One CMK is created per entry."
  type = map(object({
    description       = string
    deletion_window   = optional(number, 30)
    additional_users  = optional(list(string), []) # IAM principal ARNs allowed to use the key
    additional_admins = optional(list(string), []) # IAM principal ARNs allowed to administer the key
    # AWS service principals granted standard data-plane access
    # (Encrypt/Decrypt/GenerateDataKey*/ReEncrypt*/DescribeKey). Required for
    # services that perform server-side encryption against the key without
    # going through an IAM principal — e.g. CloudTrail (`cloudtrail.amazonaws.com`),
    # AWS Config (`config.amazonaws.com`), CloudWatch Logs
    # (`logs.<region>.amazonaws.com`). Without this, applies that wire the key
    # into those services will succeed but the services will fail at runtime
    # when they try to use the key.
    service_principals = optional(list(string), [])
  }))
  validation {
    condition     = length(var.keys) > 0
    error_message = "At least one key must be declared."
  }
}

variable "tags" {
  description = "Tags applied to all keys."
  type        = map(string)
  default     = {}
}
