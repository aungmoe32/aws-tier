
# Create Dedicated Database Subnets (Highly Recommended)
resource "aws_subnet" "db_subnet_1a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.5.0/24"
  availability_zone = "us-east-1a"

  tags = { Name = "db-subnet-1a" }
}

resource "aws_subnet" "db_subnet_1b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.6.0/24"
  availability_zone = "us-east-1b"

  tags = { Name = "db-subnet-1b" }
}

# Create a DB Subnet Group
resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "main-db-subnet-group"
  subnet_ids = [aws_subnet.db_subnet_1a.id, aws_subnet.db_subnet_1b.id]

  tags = { Name = "Main DB Subnet Group" }
}

# Create the RDS Database Instance
resource "aws_db_instance" "app_database" {
  identifier        = "app-production-db"
  engine            = "mysql"
  engine_version    = "8.0"
  instance_class    = "db.t3.micro"
  allocated_storage = 20

  db_name = "webappdb"

  # Credentials (In production, inject these via AWS Secrets Manager)
  username = var.db_username
  password = var.db_password

  # Network Placement
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]

  # High Availability Configuration
  multi_az            = true # Deploys a standby instance in AZ 1b
  publicly_accessible = false
  skip_final_snapshot = true # Set to false in production to prevent accidental data loss
}
