########################################
# RDS Subnet Group (private subnets only)
########################################

resource "aws_db_subnet_group" "jwrds_sng" {
  name       = "jwrds-sng"
  subnet_ids = [
    aws_subnet.jwprivate_1.id,
    aws_subnet.jwprivate_2.id
  ]

  tags = {
    Name = "jwrds-sng"
  }
}

########################################
# RDS Instance (MySQL-compatible for WordPress)
########################################

resource "aws_db_instance" "jwrds" {
  identifier              = "jwrds"
  engine                  = "mariadb"
  engine_version          = "11.8.5"   # latest version
  instance_class          = "db.t3.micro"

  allocated_storage       = 20       # Minimum and cheap
  storage_type            = "gp3"

  # No Multi-AZ for cost saving
  multi_az                = false

  # Database credentials (from variables)
  username                = var.db_username
  password                = var.db_password
  db_name                 = var.db_name

  # Security groups
  vpc_security_group_ids  = [aws_security_group.jwsg_rds.id]

  # Private subnets only
  db_subnet_group_name    = aws_db_subnet_group.jwrds_sng.name
  publicly_accessible     = false

  # Backup disabled for cost saving
  backup_retention_period = 0

  # Performance Insights disabled
  performance_insights_enabled = false

  # Apply changes immediately (use cautiously)
  apply_immediately = true

  # Skip final snapshot to avoid cost
  skip_final_snapshot = true

  tags = {
    Name = "jwrds"
  }
}
