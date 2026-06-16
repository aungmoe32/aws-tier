output "db_address" {
  description = "Hostname of the RDS instance endpoint"
  value       = aws_db_instance.this.address
}

output "db_port" {
  description = "Port the RDS instance is listening on"
  value       = aws_db_instance.this.port
}

output "db_name" {
  description = "Name of the database created inside the RDS instance"
  value       = aws_db_instance.this.db_name
}

output "secret_arn" {
  description = "ARN of the Secrets Manager secret holding the DB credentials"
  value       = aws_secretsmanager_secret.db_secret.arn
}

output "secret_name" {
  description = "Name of the Secrets Manager secret holding the DB credentials"
  value       = aws_secretsmanager_secret.db_secret.name
}
