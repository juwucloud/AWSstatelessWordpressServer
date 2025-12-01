########################################
# Bastion Host SG (optional SSH)
########################################

resource "aws_security_group" "jwsg_bastion" {
  name        = "jwsg-bastion"
  description = "SSH access to Bastion Host"
  vpc_id      = aws_vpc.jwvpc.id

  ingress {
    description = "Allow SSH from anywhere (adjust if needed)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "jwsg-bastion"
  }
}

########################################
# ALB Security Group
########################################

resource "aws_security_group" "jwsg_alb" {
  name        = "jwsg-alb"
  description = "Allow HTTP/HTTPS from the internet"
  vpc_id      = aws_vpc.jwvpc.id

  # Allow HTTP from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # ALB outbound to webservers
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "jwsg-alb"
  }
}

########################################
# FIX FOR ALB ↔ Webserver RETURN TRAFFIC  
# Must be a separate resource to avoid cycles
########################################

# Allow EC2 instances to respond to ALB health checks
resource "aws_security_group_rule" "web_to_alb_return" {
  type                     = "ingress"
  from_port                = 1024
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = aws_security_group.jwsg_alb.id
  source_security_group_id = aws_security_group.jwsg_web.id
}

########################################
# Webserver SG (for EC2 ASG)
########################################

resource "aws_security_group" "jwsg_web" {
  name        = "jwsg-web"
  description = "Allow HTTP from ALB, NFS from EFS, and SSH for testing"
  vpc_id      = aws_vpc.jwvpc.id

  # HTTP from ALB
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.jwsg_alb.id]
  }

  # SSH for testing only
  ingress {
    description = "SSH access for testing environment"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [aws_security_group.jwsg_bastion.id]
  }

  # Allow outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "jwsg-web"
  }
}

########################################
# RDS Security Group
########################################

resource "aws_security_group" "jwsg_rds" {
  name        = "jwsg-rds"
  description = "Allow MySQL from Webserver SG"
  vpc_id      = aws_vpc.jwvpc.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.jwsg_web.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "jwsg-rds"
  }
}

########################################
# EFS Security Group
########################################

resource "aws_security_group" "jwsg_efs" {
  name        = "jwsg-efs"
  description = "Allow NFS access from Webserver SG"
  vpc_id      = aws_vpc.jwvpc.id

  ingress {
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.jwsg_web.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "jwsg-efs"
  }
}


