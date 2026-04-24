provider "aws" {
  region            = var.region
  use_fips_endpoint = true

  default_tags {
    tags = {
      Environment        = var.environment
      DataClassification = "CUI"
      Owner              = var.owner
      Compliance         = "CMMC-L2"
      ManagedBy          = "terraform"
      Repo               = "cmmc-level2-aws-enclave-reference"
    }
  }
}
