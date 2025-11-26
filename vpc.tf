########################################
# VPC
########################################

resource "aws_vpc" "jwvpc" {
  cidr_block           = var.vpc_cidr # 10.0.0.0/16
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "jwvpc"
  }
}

########################################
# Internet Gateway
########################################

resource "aws_internet_gateway" "jwigw" {
  vpc_id = aws_vpc.jwvpc.id

  tags = {
    Name = "jwigw"
  }
}

########################################
# PUBLIC SUBNETS
########################################

# us-west-2a
resource "aws_subnet" "jwpublic_1" {
  vpc_id                  = aws_vpc.jwvpc.id
  cidr_block              = var.public_subnets[0] # 10.0.1.0/24
  availability_zone       = "us-west-2a"
  map_public_ip_on_launch = true

  tags = {
    Name = "jwpublic-1"
  }
}

# us-west-2b
resource "aws_subnet" "jwpublic_2" {
  vpc_id                  = aws_vpc.jwvpc.id
  cidr_block              = var.public_subnets[1] # 10.0.2.0/24
  availability_zone       = "us-west-2b"
  map_public_ip_on_launch = true

  tags = {
    Name = "jwpublic-2"
  }
}

########################################
# PRIVATE SUBNETS
########################################

# us-west-2a
resource "aws_subnet" "jwprivate_1" {
  vpc_id            = aws_vpc.jwvpc.id
  cidr_block        = var.private_subnets[0] # 10.0.3.0/24
  availability_zone = "us-west-2a"

  tags = {
    Name = "jwprivate-1"
  }
}

# us-west-2b
resource "aws_subnet" "jwprivate_2" {
  vpc_id            = aws_vpc.jwvpc.id
  cidr_block        = var.private_subnets[1] # 10.0.4.0/24
  availability_zone = "us-west-2b"

  tags = {
    Name = "jwprivate-2"
  }
}

########################################
# NAT GATEWAY
########################################

resource "aws_eip" "jwnat_eip" {
  depends_on = [ aws_internet_gateway.jwigw ]
  domain = "vpc"

  tags = {
    Name = "jwnat-eip"
  }
}

resource "aws_nat_gateway" "jwnat" {
  allocation_id = aws_eip.jwnat_eip.id
  subnet_id     = aws_subnet.jwpublic_1.id   # Launch NAT in us-west-2a

  tags = {
    Name = "jwnat"
  }
}

########################################
# ROUTE TABLES
########################################

# Public Route Table
resource "aws_route_table" "jwpublic_rt" {
  vpc_id = aws_vpc.jwvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.jwigw.id
  }

  tags = {
    Name = "jwpublic-rt"
  }
}

# Associate Public Subnets
resource "aws_route_table_association" "jwpublic_1_assoc" {
  subnet_id      = aws_subnet.jwpublic_1.id
  route_table_id = aws_route_table.jwpublic_rt.id
}

resource "aws_route_table_association" "jwpublic_2_assoc" {
  subnet_id      = aws_subnet.jwpublic_2.id
  route_table_id = aws_route_table.jwpublic_rt.id
}

# Private Route Table
resource "aws_route_table" "jwprivate_rt" {
  vpc_id = aws_vpc.jwvpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.jwnat.id
  }

  tags = {
    Name = "jwprivate-rt"
  }
}

# Associate Private Subnets
resource "aws_route_table_association" "jwprivate_1_assoc" {
  subnet_id      = aws_subnet.jwprivate_1.id
  route_table_id = aws_route_table.jwprivate_rt.id
}

resource "aws_route_table_association" "jwprivate_2_assoc" {
  subnet_id      = aws_subnet.jwprivate_2.id
  route_table_id = aws_route_table.jwprivate_rt.id
}
