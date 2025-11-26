variable "region" {
  description = "The AWS region for the Project"
  type        = string
}

variable "db_username" {
  type        = string
  description = "Master username for RDS"
}

variable "db_password" {
  type        = string
  description = "Master password for RDS"
  sensitive   = true
}

variable "db_name" {
  type        = string
  description = "Initial database name for WordPress"
  default     = "wordpressdb"
}

variable "key_name" {
  type        = string
  description = "EC2 Key Pair for optional SSH access"
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