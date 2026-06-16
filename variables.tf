variable "db_username" {
  type      = string
  sensitive = true
}

variable "db_name" {
  type    = string
  default = "webappdb"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "network_config" {
  description = "Map of Availability Zones and their respective subnet CIDR blocks"
  type = map(object({
    public_cidr  = string
    private_cidr = string
    db_cidr      = string
  }))
}
variable "domain_name" {
  description = "the domain name"
  type        = string
}
