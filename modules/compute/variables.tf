# ── Launch Template ──────────────────────────────────────────────────────────

variable "name_prefix" {
  description = "Prefix used for the launch template name and instance tag"
  type        = string
  default     = "app-"
}

variable "ami_id" {
  description = "AMI ID to launch (typically from the dynamic-ami module)"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "security_group_ids" {
  description = "List of security group IDs to attach to each EC2 instance"
  type        = list(string)
}

variable "iam_instance_profile_name" {
  description = "Name of the IAM instance profile to attach to EC2 instances"
  type        = string
}

variable "user_data_base64" {
  description = "Base64-encoded user-data script to run on instance launch"
  type        = string
}

variable "tags" {
  description = "Additional tags to apply to launched instances"
  type        = map(string)
  default     = {}
}

# ── Auto Scaling Group ────────────────────────────────────────────────────────

variable "asg_name" {
  description = "Name for the Auto Scaling Group"
  type        = string
  default     = "app-autoscaling-group"
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs across which the ASG distributes instances"
  type        = list(string)
}

variable "target_group_arns" {
  description = "List of ALB Target Group ARNs to register instances with"
  type        = list(string)
}

variable "health_check_grace_period" {
  description = "Seconds to wait after instance launch before checking health"
  type        = number
  default     = 300
}

variable "min_size" {
  description = "Minimum number of instances in the ASG"
  type        = number
  default     = 2
}

variable "desired_capacity" {
  description = "Desired number of instances in the ASG"
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum number of instances the ASG can scale out to"
  type        = number
  default     = 4
}

# ── Scaling Policy ────────────────────────────────────────────────────────────

variable "alb_resource_label" {
  description = "Combined ALB + Target Group ARN suffix for the CloudWatch metric (format: <alb_arn_suffix>/<tg_arn_suffix>)"
  type        = string
}

variable "scale_out_request_count" {
  description = "Target requests-per-minute per instance that triggers a scale-out"
  type        = number
  default     = 1000.0
}
