resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  tags = {
    Name = "${var.project_name}-vpc"
  }
}

resource "aws_internet_gateway" "GW" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# --- Public subnets ---

resource "aws_subnet" "subnet1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "${var.aws_region}a"

  tags = {
    Name = "${var.project_name}-public-a"
  }
}

resource "aws_subnet" "subnet2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.aws_region}b"

  tags = {
    Name = "${var.project_name}-public-b"
  }
}

resource "aws_route_table" "main_table" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.GW.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table_association" "table1" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.main_table.id
}

resource "aws_route_table_association" "table2" {
  subnet_id      = aws_subnet.subnet2.id
  route_table_id = aws_route_table.main_table.id
}

# --- Private subnets + NAT ---
# NOTE: a single NAT gateway (in subnet2 / AZ-b) serves both private subnets.
# This is a deliberate cost trade-off: a per-AZ NAT would double the cost but
# remove this single point of failure for outbound traffic. See README.

resource "aws_eip" "elastic_ip" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-nat-eip"
  }
}

resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.elastic_ip.id
  subnet_id     = aws_subnet.subnet2.id

  tags = {
    Name = "${var.project_name}-nat"
  }

  depends_on = [aws_internet_gateway.GW]
}

resource "aws_subnet" "subnet_priv" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "${var.aws_region}a"

  tags = {
    Name = "${var.project_name}-private-a"
  }
}

resource "aws_subnet" "subnet_priv2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "${var.aws_region}b"

  tags = {
    Name = "${var.project_name}-private-b"
  }
}

resource "aws_route_table" "private_table" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }

  tags = {
    Name = "${var.project_name}-private-rt"
  }
}

resource "aws_route_table_association" "table_priv" {
  subnet_id      = aws_subnet.subnet_priv.id
  route_table_id = aws_route_table.private_table.id
}

resource "aws_route_table_association" "table_priv2" {
  subnet_id      = aws_subnet.subnet_priv2.id
  route_table_id = aws_route_table.private_table.id
}
