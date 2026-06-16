variable "secret_name" {
  description = "Name of the Secrets Manager secret that stores DB credentials"
  type        = string
  default     = "prod/webapp/db-credentials"
}


variable "db_username" {
  description = "Master username for the RDS instance"
  type        = string
  sensitive   = true
}

variable "db_name" {
  description = "Name of the initial database to create inside the RDS instance"
  type        = string
  default     = "webappdb"
}


variable "identifier" {
  description = "Unique identifier for the RDS instance"
  type        = string
  default     = "app-production-db"
}

variable "engine_version" {
  description = "MySQL engine version"
  type        = string
  default     = "8.0"
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Allocated storage in GiB"
  type        = number
  default     = 20
}

variable "multi_az" {
  description = "Deploy a standby instance in a second AZ for high availability"
  type        = bool
  default     = true
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot on destroy (set false in production)"
  type        = bool
  default     = true
}


variable "subnet_group_name" {
  description = "Name for the DB subnet group"
  type        = string
  default     = "main-db-subnet-group"
}

variable "db_subnet_ids" {
  description = "List of subnet IDs to place the RDS instance in"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs to attach to the RDS instance"
  type        = list(string)
}


variable "tags" {
  description = "Additional tags to apply to all resources in this module"
  type        = map(string)
  default     = {}
}
