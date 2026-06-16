variable "vpc_name" {
  description = "Name tag applied to the VPC and derived resources"
  type        = string
  default     = "main-vpc"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "network_config" {
  description = "Map of Availability Zones to subnet CIDR blocks"
  type = map(object({
    public_cidr  = string
    private_cidr = string
    db_cidr      = string
  }))
}
