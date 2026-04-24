# All inputs are required (no defaults) so `terraform plan` fails fast when
# a consumer forgets to supply something. Adapt to your account / org.

variable "region" {
  description = "GovCloud region. Reference deployments target us-gov-west-1."
  type        = string
}

variable "environment" {
  description = "Logical environment name (e.g. prod, staging)."
  type        = string
}

variable "owner" {
  description = "Owning team or distribution list (used in default tags)."
  type        = string
}

variable "vpc_cidr" {
  description = "Primary VPC CIDR. Carve from your enterprise IPAM allocation."
  type        = string
}

variable "az_count" {
  description = "Number of AZs to span. CUI workloads should use 3."
  type        = number
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention for VPC Flow Logs and CloudTrail group."
  type        = number
}

variable "object_lock_retention_years" {
  description = "Object Lock retention for the CloudTrail bucket. CUI baseline is 7."
  type        = number
}

variable "kms_admin_principal_arns" {
  description = "ARNs allowed to administer the CMKs (e.g. break-glass admin role)."
  type        = list(string)
}

variable "trail_name" {
  description = "Name for the management-events CloudTrail."
  type        = string
}

variable "config_conformance_pack_template_body" {
  description = <<-EOT
    YAML body for the NIST-800-171 Config conformance pack. Download from
    awslabs/aws-config-rules and supply via file(...). Pass null to skip.
  EOT
  type        = string
  default     = null
}
