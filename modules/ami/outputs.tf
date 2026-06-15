output "ami_id" {
  description = "The ID of the most recent matching AMI"
  value       = data.aws_ami.this.id
}

output "ami_name" {
  description = "The name of the most recent matching AMI"
  value       = data.aws_ami.this.name
}

output "ami_description" {
  description = "The description of the resolved AMI"
  value       = data.aws_ami.this.description
}
