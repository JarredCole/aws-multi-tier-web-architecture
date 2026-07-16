# 1. Create the Custom VP
resource "aws_vpc" "main" {
  cidr_block	       = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "production-vpc"
  }
}

# 2. Create the Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "production-igw"
  }
}


# 3. Create Public Subnets (A & B)
# tfsec:ignore:aws-ec2-no-public-ip-subnet
resource "aws_subnet" "public_a" {
  vpc_id	    = aws_vpc.main.id
  cidr_block	    = var.public_subnet_cidrs[0]
  availability_zone = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "Public Subnet A"
  }
}

# tfsec:ignore:aws-ec2-no-public-ip-subnet
resource "aws_subnet" "public_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidrs[1]
  availability_zone = "${var.aws_region}b"
  map_public_ip_on_launch = true

  tags = {
    Name = "Public Subnet B"
  }
}

# 4. Create Private Subnets (A & B)
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[0]
  availability_zone = "${var.aws_region}a"

  tags = {
    Name = "Private Subnet A"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[1]
  availability_zone = "${var.aws_region}b"

  tags = {
    Name = "Private Subnet B"
  }
}

# 5. Create Data Subnets (A & B)
resource "aws_subnet" "data_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.data_subnet_cidrs[0]
  availability_zone = "${var.aws_region}a"

  tags = {
    Name = "Data Subnet A"
  }
}

resource "aws_subnet" "data_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.data_subnet_cidrs[1]
  availability_zone = "${var.aws_region}b"

  tags = {
    Name = "Data Subnet B"
  }
}

# 6. Create a Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-route-table"
  }
}

# 7. Associate Public Subnet A with Public Route Table
resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

# 8. Associate Public Subnet B with Public Route Table
resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}
