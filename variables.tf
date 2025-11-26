variable "region" {
  description = "The AWS region for the Project"
  type        = string
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC"
  default     = "10.0.0.0/16"
}

variable "public_subnets" {
  type        = list(string)
  description = "List of public subnet CIDR ranges"
}

variable "private_subnets" {
  type        = list(string)
  description = "List of private subnet CIDR ranges"
}

variable "db_secret_name" {
  type        = string
  description = "Name of the Secrets Manager secret for DB credentials"
}
