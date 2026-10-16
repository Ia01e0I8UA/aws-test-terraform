terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }

  backend "s3" {
    bucket       = "tf-state-uno"
    key          = "trrfrm.stte"
    region       = "eu-west-1"
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region
}
