########################################
# WEB SERVER SECURITY GROUP
########################################

resource "aws_security_group" "jwsg_web" {
  name        = "jwsg-web"
  description = "Allow HTTP from ALB and SSH from Bastion"
  vpc_id      = aws_vpc.jwvpc.id

  tags = {
    Name = "jwsg-web"
  }
}

# HTTP from ALB
resource "aws_vpc_security_group_ingress_rule" "jwsg_web_http_from_alb" {
  security_group_id             = aws_security_group.jwsg_web.id
  referenced_security_group_id  = aws_security_group.jwsg_alb.id
  from_port                     = 80
  to_port                       = 80
  ip_protocol                   = "tcp"
}

# SSH from Bastion
resource "aws_vpc_security_group_ingress_rule" "jwsg_web_ssh_from_bastion" {
  security_group_id             = aws_security_group.jwsg_web.id
  referenced_security_group_id  = aws_security_group.jwsg_bastion.id
  from_port                     = 22
  to_port                       = 22
  ip_protocol                   = "tcp"
}

# NFS to EFS
resource "aws_vpc_security_group_ingress_rule" "jwsg_web_nfs_to_efs" {
  security_group_id             = aws_security_group.jwsg_web.id
  referenced_security_group_id  = aws_security_group.jwsg_efs.id
  from_port                     = 2049
  to_port                       = 2049
  ip_protocol                   = "tcp"
}


# Outbound all IPv4
resource "aws_vpc_security_group_egress_rule" "jwsg_web_allow_all_ipv4" {
  security_group_id = aws_security_group.jwsg_web.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}


########################################
# ALB SECURITY GROUP
########################################

resource "aws_security_group" "jwsg_alb" {
  name        = "jwsg-alb"
  description = "Allow HTTP from internet"
  vpc_id      = aws_vpc.jwvpc.id

  tags = {
    Name = "jwsg-alb"
  }
}

# HTTP from internet
resource "aws_vpc_security_group_ingress_rule" "jwsg_alb_http_anywhere" {
  security_group_id = aws_security_group.jwsg_alb.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

# Outbound all
resource "aws_vpc_security_group_egress_rule" "jwsg_alb_allow_all_ipv4" {
  security_group_id = aws_security_group.jwsg_alb.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}


########################################
# BASTION SECURITY GROUP
########################################

resource "aws_security_group" "jwsg_bastion" {
  name        = "jwsg-bastion"
  description = "SSH access to Bastion Host"
  vpc_id      = aws_vpc.jwvpc.id

  tags = {
    Name = "jwsg-bastion"
  }
}

# SSH from anywhere (lab mode)
resource "aws_vpc_security_group_ingress_rule" "jwsg_bastion_ssh_anywhere" {
  security_group_id = aws_security_group.jwsg_bastion.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

# Outbound all
resource "aws_vpc_security_group_egress_rule" "jwsg_bastion_allow_all_ipv4" {
  security_group_id = aws_security_group.jwsg_bastion.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}


########################################
# RDS SECURITY GROUP
########################################

resource "aws_security_group" "jwsg_rds" {
  name        = "jwsg-rds"
  description = "Allow MySQL from Webserver SG"
  vpc_id      = aws_vpc.jwvpc.id

  tags = {
    Name = "jwsg-rds"
  }
}

# Allow MySQL from Web instances
resource "aws_vpc_security_group_ingress_rule" "jwsg_rds_mysql_from_web" {
  security_group_id             = aws_security_group.jwsg_rds.id
  referenced_security_group_id  = aws_security_group.jwsg_web.id
  from_port                     = 3306
  to_port                       = 3306
  ip_protocol                   = "tcp"
}

# Outbound all
resource "aws_vpc_security_group_egress_rule" "jwsg_rds_allow_all_ipv4" {
  security_group_id = aws_security_group.jwsg_rds.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}


########################################
# EFS SECURITY GROUP
########################################

resource "aws_security_group" "jwsg_efs" {
  name        = "jwsg-efs"
  description = "Allow NFS access from Webservers"
  vpc_id      = aws_vpc.jwvpc.id

  tags = {
    Name = "jwsg-efs"
  }
}

# NFS from Web
resource "aws_vpc_security_group_ingress_rule" "jwsg_efs_nfs_from_web" {
  security_group_id             = aws_security_group.jwsg_efs.id
  referenced_security_group_id  = aws_security_group.jwsg_web.id
  from_port                     = 2049
  to_port                       = 2049
  ip_protocol                   = "tcp"
}

# Outbound all
resource "aws_vpc_security_group_egress_rule" "jwsg_efs_allow_all_ipv4" {
  security_group_id = aws_security_group.jwsg_efs.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
