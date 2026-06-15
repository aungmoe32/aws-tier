variable "owners" {
  description = "List of AMI owner account IDs or aliases (e.g. 'amazon', 'self')"
  type        = list(string)
  default     = ["amazon"]
}

variable "filters" {
  description = "List of filter objects used to narrow down the AMI search"
  type = list(object({
    name   = string
    values = list(string)
  }))
  # Default: latest Amazon Linux 2023 HVM x86_64 AMI
  default = [
    {
      name   = "name"
      values = ["al2023-ami-2023.*-x86_64"]
    },
    {
      name   = "virtualization-type"
      values = ["hvm"]
    },
    {
      name   = "architecture"
      values = ["x86_64"]
    },
    {
      name   = "state"
      values = ["available"]
    }
  ]
}
