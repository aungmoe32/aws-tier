

variable "domain_name" {
  description = "Apex domain name used for the ACM certificate and Route 53 A record"
  type        = string
}


variable "alb_name" {
  description = "Name for the Application Load Balancer"
  type        = string
  default     = "my-app-alb"
}

variable "alb_security_group_ids" {
  description = "List of security group IDs to attach to the ALB"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs the ALB will be placed in"
  type        = list(string)
}


variable "target_group_name" {
  description = "Name for the ALB target group"
  type        = string
  default     = "my-app-target-group"
}

variable "vpc_id" {
  description = "VPC ID in which the target group is created"
  type        = string
}

variable "health_check_path" {
  description = "HTTP path the ALB uses for target health checks"
  type        = string
  default     = "/health"
}


variable "ssl_policy" {
  description = "SSL negotiation policy for the HTTPS listener"
  type        = string
  default     = "ELBSecurityPolicy-2016-08"
}


variable "tags" {
  description = "Additional tags to apply to all resources in this module"
  type        = map(string)
  default     = {}
}
