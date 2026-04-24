provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Environment        = "demo"
      DataClassification = "synthetic"
      AutoDestroy        = "true"
      Repo               = "cmmc-level2-aws-enclave-reference"
      ManagedBy          = "terraform"
    }
  }
}
