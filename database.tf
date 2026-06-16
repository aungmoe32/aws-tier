resource "random_password" "db_password" {
  length  = 16
  special = true
  # explicitly define WHICH special characters are allowed
  # This intentionally leaves out @, /, \, and " 
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "db_secret" {
  name        = "prod/webapp/db-credentials"
  description = "Database credentials for the Python Web App"

  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "db_secret_version" {
  secret_id = aws_secretsmanager_secret.db_secret.id

  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_password.result
    host     = aws_db_instance.app_database.address
    dbname   = var.db_name
  })
}


resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "main-db-subnet-group"
  subnet_ids = [for subnet in aws_subnet.db : subnet.id]

  tags = { Name = "Main DB Subnet Group" }
}

resource "aws_db_instance" "app_database" {
  identifier        = "app-production-db"
  engine            = "mysql"
  engine_version    = "8.0"
  instance_class    = "db.t3.micro"
  allocated_storage = 20

  db_name = var.db_name

  username = var.db_username
  password = random_password.db_password.result


  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]

  multi_az            = true
  publicly_accessible = false
  skip_final_snapshot = true
}
