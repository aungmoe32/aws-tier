output "db_endpoint" {
  value       = aws_db_instance.app_database.endpoint
  description = "The connection endpoint for the EC2 instances to talk to the database"
}

output "alb_dns_name" {
  value       = module.loadbalancer.alb_dns_name
  description = "Copy this URL into your browser to access the website"
}
