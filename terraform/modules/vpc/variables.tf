variable "name" {
  description = "Name prefix applied to all VPC resources."
  type        = string
}

variable "cidr_block" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "az_count" {
  description = "Number of Availability Zones to span (2 or 3)."
  type        = number
  default     = 2
  validation {
    condition     = var.az_count >= 2 && var.az_count <= 3
    error_message = "az_count must be 2 or 3."
  }
}

variable "enable_nat_gateway" {
  description = "Whether to deploy NAT Gateways for private subnet egress. Disable to force VPC-endpoint-only egress (cheaper, more restrictive)."
  type        = bool
  default     = true
}

variable "flow_log_retention_days" {
  description = "CloudWatch Logs retention for VPC Flow Logs."
  type        = number
  default     = 365
}

variable "kms_key_arn" {
  description = "ARN of the KMS CMK used to encrypt the VPC Flow Logs CloudWatch Logs group. Required so flow-log content (which can include source/destination IPs and bytes-transferred) is encrypted at rest with a customer-managed key."
  type        = string
}

variable "tags" {
  description = "Tags applied to all resources created by this module."
  type        = map(string)
  default     = {}
}
