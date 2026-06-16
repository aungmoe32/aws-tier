output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "Map of AZ → public subnet ID"
  value       = { for k, s in aws_subnet.public : k => s.id }
}

output "private_subnet_ids" {
  description = "Map of AZ → private subnet ID"
  value       = { for k, s in aws_subnet.private : k => s.id }
}

output "db_subnet_ids" {
  description = "Map of AZ → DB subnet ID"
  value       = { for k, s in aws_subnet.db : k => s.id }
}
