# 1. Generate a random 16-character password
resource "random_password" "db_password" {
  length  = 16
  special = true
  # Exclude characters that often break connection string URLs
  exclude_characters = "\"@/\\"
}

# 2. Create the Secret container in AWS Secrets Manager
resource "aws_secretsmanager_secret" "db_secret" {
  name        = "prod/webapp/db-credentials"
  description = "Database credentials for the Python Web App"

  # Ensure the secret is deleted immediately if destroyed in Terraform
  recovery_window_in_days = 0
}

# 3. Store the generated password inside the Secret container
resource "aws_secretsmanager_secret_version" "db_secret_version" {
  secret_id = aws_secretsmanager_secret.db_secret.id

  # Storing as a JSON string so Python can parse it easily
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_password.result
    host     = aws_db_instance.app_database.address
    dbname   = var.db_name
  })
}


# Create a DB Subnet Group
resource "aws_db_subnet_group" "db_subnet_group" {
  name = "main-db-subnet-group"
  # subnet_ids = [aws_subnet.db_subnet_1a.id, aws_subnet.db_subnet_1b.id]
  subnet_ids = [for subnet in aws_subnet.db : subnet.id]

  tags = { Name = "Main DB Subnet Group" }
}

# Create the RDS Database Instance
resource "aws_db_instance" "app_database" {
  identifier        = "app-production-db"
  engine            = "mysql"
  engine_version    = "8.0"
  instance_class    = "db.t3.micro"
  allocated_storage = 20

  db_name = var.db_name

  # Credentials (In production, inject these via AWS Secrets Manager)
  username = var.db_username
  password = random_password.db_password.result # Replaced hardcoded string


  # Network Placement
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]

  # High Availability Configuration
  multi_az            = true # Deploys a standby instance in AZ 1b
  publicly_accessible = false
  skip_final_snapshot = true # Set to false in production to prevent accidental data loss
}
