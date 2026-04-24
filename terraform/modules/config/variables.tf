variable "name" {
  description = "Name for the recorder, delivery channel, and supporting resources."
  type        = string
  default     = "cmmc-config"
}

variable "kms_key_arn" {
  description = "KMS CMK ARN for encrypting the Config delivery S3 bucket."
  type        = string
}

variable "include_global_resource_types" {
  description = "Whether to record IAM and other global resources. Set true on exactly ONE region per account."
  type        = bool
  default     = true
}

variable "delivery_frequency" {
  description = "How often Config delivers configuration snapshots."
  type        = string
  default     = "Six_Hours"
}

variable "conformance_pack_template_body" {
  description = <<-EOT
    Optional YAML body for an `aws_config_conformance_pack`. Pass the contents of
    AWS's `Operational-Best-Practices-for-NIST-800-171.yaml` (download separately
    from the AWS Config rules conformance-pack repository — not vendored here for
    license reasons). When null, no conformance pack is created.
  EOT
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
