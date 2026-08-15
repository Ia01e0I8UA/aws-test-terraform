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

resource "aws_s3_bucket" "bucket01" {
  bucket = "tf-state-uno"
}

resource "aws_s3_bucket_versioning" "state_versioning" {
  bucket = aws_s3_bucket.bucket01.id 
  versioning_configuration {
    status = "Enabled"  
  }
}

resource "aws_dynamodb_table" "example_DDBB" {
  name = "DDBB"
  billing_mode = "PAY_PER_REQUEST"
  hash_key = "LockID"
  
  attribute {
    name = "LockID"
    type = "S"
  }

}
