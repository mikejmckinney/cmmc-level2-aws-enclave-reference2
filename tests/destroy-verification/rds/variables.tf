variable "name" {
  description = "Name prefix for the verification RDS instance + supporting resources."
  type        = string
  default     = "destroy-verify"
}

variable "vpc_cidr" {
  description = "CIDR block for the throwaway VPC the RDS instance lives in."
  type        = string
  default     = "10.99.0.0/16"
}

variable "tags" {
  description = "Tags applied to every resource. The Project tag is REQUIRED and asserted on by the verify-destroy-rds workflow."
  type        = map(string)
  default = {
    Project   = "cmmc-enclave-destroy-verify"
    ManagedBy = "verify-destroy-rds.yml"
  }

  validation {
    condition     = lookup(var.tags, "Project", "") == "cmmc-enclave-destroy-verify"
    error_message = "tags must include Project=cmmc-enclave-destroy-verify so the workflow assertion can find the instance."
  }
}
