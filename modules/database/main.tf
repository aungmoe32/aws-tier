resource "random_password" "db_password" {
  length  = 16
  special = true
  # Intentionally excludes @, /, \, and " which break MySQL connection strings
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "db_secret" {
  name        = var.secret_name
  description = "Database credentials for the Python Web App"

  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "db_secret_version" {
  secret_id = aws_secretsmanager_secret.db_secret.id

  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_password.result
    host     = aws_db_instance.this.address
    dbname   = var.db_name
  })
}

resource "aws_db_subnet_group" "this" {
  name       = var.subnet_group_name
  subnet_ids = var.db_subnet_ids

  tags = merge({ Name = var.subnet_group_name }, var.tags)
}

resource "aws_db_instance" "this" {
  identifier        = var.identifier
  engine            = "mysql"
  engine_version    = var.engine_version
  instance_class    = var.instance_class
  allocated_storage = var.allocated_storage

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db_password.result

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = var.security_group_ids

  multi_az            = var.multi_az
  publicly_accessible = false
  skip_final_snapshot = var.skip_final_snapshot

  tags = merge({ Name = var.identifier }, var.tags)
}

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}
