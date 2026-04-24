# All inputs ship safe defaults so a fresh `terraform apply` works with
# zero overrides — that's the point of the demo root.

variable "region" {
  description = "Commercial AWS region. us-east-1 is cheapest for a tiny demo."
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Name prefix for demo resources."
  type        = string
  default     = "cmmc-demo"
}

variable "vpc_cidr" {
  description = "CIDR for the demo VPC. Doesn't need to coordinate with anything."
  type        = string
  default     = "10.99.0.0/16"
}

variable "az_count" {
  description = "AZs to span. Demo uses 2 to halve subnet/NAT cost."
  type        = number
  default     = 2
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention. Short for demo cost."
  type        = number
  default     = 7
}

variable "object_lock_retention_years" {
  description = "Object Lock retention for the demo CloudTrail bucket. 1 year keeps storage cheap."
  type        = number
  default     = 1
}

variable "trail_name" {
  description = "CloudTrail name."
  type        = string
  default     = "cmmc-demo-trail"
}

variable "enable_guardduty" {
  description = "Enable GuardDuty in the demo. Off by default to keep cost near zero."
  type        = bool
  default     = false
}

variable "enable_guardduty_extras" {
  description = "Enable GuardDuty extra features (S3 events, malware scan, EKS, RDS, Lambda). Off by default."
  type        = bool
  default     = false
}
