# Create the VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "main-vpc"
  }
}


# Create all Public Subnets
resource "aws_subnet" "public" {
  for_each                = var.network_config
  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.public_cidr
  availability_zone       = each.key
  map_public_ip_on_launch = true

  tags = { Name = "public-subnet-${each.key}" }
}

# Create all Private Subnets
resource "aws_subnet" "private" {
  for_each          = var.network_config
  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.private_cidr
  availability_zone = each.key

  tags = { Name = "private-subnet-${each.key}" }
}

# Create all DB Subnets
resource "aws_subnet" "db" {
  for_each          = var.network_config
  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.db_cidr
  availability_zone = each.key

  tags = { Name = "db-subnet-${each.key}" }
}

# Create an Internet Gateway (IGW)
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-igw"
  }
}

# Create a Public Route Table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-route-table"
  }
}


# Create Elastic IPs for NAT Gateways
resource "aws_eip" "nat" {
  for_each = var.network_config
  domain   = "vpc"

  tags = { Name = "nat-eip-${each.key}" }
}


# Create NAT Gateways (matching the Elastic IP to the exact Public Subnet)
resource "aws_nat_gateway" "nat_gw" {
  for_each      = var.network_config
  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id

  depends_on = [aws_internet_gateway.igw]

  tags = { Name = "nat-gw-${each.key}" }
}


# Create Private Route Tables
resource "aws_route_table" "private" {
  for_each = var.network_config
  vpc_id   = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw[each.key].id
  }

  tags = { Name = "private-rt-${each.key}" }
}

# Associate Private Subnets with their specific Private Route Tables
resource "aws_route_table_association" "private" {
  for_each       = var.network_config
  subnet_id      = aws_subnet.private[each.key].id
  route_table_id = aws_route_table.private[each.key].id
}

resource "aws_route_table_association" "public" {
  for_each       = var.network_config
  subnet_id      = aws_subnet.public[each.key].id
  route_table_id = aws_route_table.public_rt.id
}
