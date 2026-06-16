output "alb_sg_id" {
  description = "ID of the ALB security group"
  value       = aws_security_group.alb.id
}

output "ec2_sg_id" {
  description = "ID of the EC2 security group"
  value       = aws_security_group.ec2.id
}

output "db_sg_id" {
  description = "ID of the DB security group"
  value       = aws_security_group.db.id
}
