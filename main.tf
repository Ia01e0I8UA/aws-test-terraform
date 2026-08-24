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
# ----------------------------------------------------------------

resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.elastic_ip.id
  subnet_id     = aws_subnet.subnet2.id

  tags = {
    Name = "gw NAT"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.GW]
}

resource "aws_eip" "elastic_ip" {
  domain   = "vpc"
}

resource aws_route_table "private_table" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }
}

resource "aws_route_table_association" "table_priv" {
  subnet_id = aws_subnet.subnet_priv.id
  route_table_id = aws_route_table.private_table.id
}

resource "aws_subnet" "subnet_priv" {
  vpc_id = aws_vpc.main.id
  cidr_block = "10.0.3.0/24"
  availability_zone = "eu-west-1a"
}

resource "aws_route_table_association" "table_priv2" {
  subnet_id = aws_subnet.subnet_priv2.id
  route_table_id = aws_route_table.private_table.id
}

resource "aws_subnet" "subnet_priv2" {
  vpc_id = aws_vpc.main.id
  cidr_block = "10.0.4.0/24"
  availability_zone = "eu-west-1b"
}
