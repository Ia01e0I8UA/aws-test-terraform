terraform {
  required_providers {
    aws    = { source = "hashicorp/aws", version = "~> 5.0" }
    random = { source = "hashicorp/random", version = "~> 3.0" }
  }
  

  backend "s3" {
    bucket = "tf-state-uno"
    key = "trrfrm.stte"
    region= "eu-west-1"
    dynamodb_table = "DDBB"
  }

}


provider "aws" {
  region = "eu-west-1"
}


