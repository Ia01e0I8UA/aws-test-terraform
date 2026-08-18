

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

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    name = "main_vpc"  
  }
}

resource "aws_internet_gateway" "GW" {
  vpc_id = aws_vpc.main.id
  
  tags = { name = "main" }
}

resource "aws_route_table" "main_table" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.GW.id
  }

}

resource "aws_subnet" "subnet1" {
  vpc_id = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "eu-west-1a"
 
}

resource "aws_route_table_association" "table1" {
  subnet_id = aws_subnet.subnet1.id
  route_table_id = aws_route_table.main_table.id
}


resource "aws_subnet" "subnet2" {
  vpc_id = aws_vpc.main.id 
  cidr_block = "10.0.2.0/24"
  availability_zone = "eu-west-1b"

}

resource "aws_route_table_association" "table2" {
  subnet_id = aws_subnet.subnet2.id
  route_table_id = aws_route_table.main_table.id
}
