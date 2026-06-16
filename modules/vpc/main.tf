resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = var.vpc_name }
}

resource "aws_subnet" "public" {
  for_each                = var.network_config
  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value.public_cidr
  availability_zone       = each.key
  map_public_ip_on_launch = true

  tags = { Name = "public-subnet-${each.key}" }
}

resource "aws_subnet" "private" {
  for_each          = var.network_config
  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value.private_cidr
  availability_zone = each.key

  tags = { Name = "private-subnet-${each.key}" }
}

resource "aws_subnet" "db" {
  for_each          = var.network_config
  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value.db_cidr
  availability_zone = each.key

  tags = { Name = "db-subnet-${each.key}" }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = { Name = "${var.vpc_name}-igw" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = { Name = "${var.vpc_name}-public-rt" }
}

resource "aws_eip" "nat" {
  for_each = var.network_config
  domain   = "vpc"

  tags = { Name = "nat-eip-${each.key}" }
}

resource "aws_nat_gateway" "this" {
  for_each      = var.network_config
  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id

  depends_on = [aws_internet_gateway.this]

  tags = { Name = "nat-gw-${each.key}" }
}

resource "aws_route_table" "private" {
  for_each = var.network_config
  vpc_id   = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[each.key].id
  }

  tags = { Name = "private-rt-${each.key}" }
}

resource "aws_route_table_association" "private" {
  for_each       = var.network_config
  subnet_id      = aws_subnet.private[each.key].id
  route_table_id = aws_route_table.private[each.key].id
}

resource "aws_route_table_association" "public" {
  for_each       = var.network_config
  subnet_id      = aws_subnet.public[each.key].id
  route_table_id = aws_route_table.public.id
}
