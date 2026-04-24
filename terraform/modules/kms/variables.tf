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
