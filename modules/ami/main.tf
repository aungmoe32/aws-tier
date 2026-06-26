data "aws_ami" "this" {
  most_recent = true
  owners      = var.owners

  dynamic "filter" {
    for_each = var.filters
    content {
      name   = filter.value.name
      values = filter.value.values
    }
  }
}

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
