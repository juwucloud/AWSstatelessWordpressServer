########################################
# Bastion Host (simple EC2)
########################################

resource "aws_instance" "jwbastion" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.jwpublic_1.id
  associate_public_ip_address = true

  # Existing Bastion Security Group (we already created jwsg_bastion)
  vpc_security_group_ids = [
    aws_security_group.jwsg_bastion.id
  ]

  # Load UserData for Bastion
  user_data_base64 = filebase64("${path.module}/BastionUserData.sh")

  key_name = var.key_name

  tags = {
    Name = "jwbastion"
  }
}
