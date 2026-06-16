variable "role_name" {
  description = "Name for the IAM role"
  type        = string
  default     = "ec2-ssm-role"
}

variable "instance_profile_name" {
  description = "Name for the IAM instance profile"
  type        = string
  default     = "ec2-ssm-profile"
}

variable "secret_arn" {
  description = "ARN of the Secrets Manager secret the EC2 instances are allowed to read"
  type        = string
}
