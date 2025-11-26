########################################
# IAM Role for EC2 (SecretsManager + EFS)
########################################

resource "aws_iam_role" "jw_ec2_role" {
  name = "jw-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "jw-ec2-role"
  }
}

########################################
# IAM Policy for EC2 (minimal permissions)
########################################

resource "aws_iam_policy" "jw_ec2_policy" {
  name = "jw-ec2-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SecretsManagerAccess"         # Access to Secrets Manager
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "*"
      },
      {
        Sid    = "EFSAccess"                    # Access to EFS
        Effect = "Allow"
        Action = [
          "elasticfilesystem:ClientMount",
          "elasticfilesystem:ClientWrite",
          "elasticfilesystem:ClientRootAccess"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name = "jw-ec2-policy"
  }
}

########################################
# Attach Policy to IAM Role
########################################

resource "aws_iam_role_policy_attachment" "jw_attach_policy" {
  role       = aws_iam_role.jw_ec2_role.name
  policy_arn = aws_iam_policy.jw_ec2_policy.arn
}

########################################
# EC2 Instance Profile
########################################

resource "aws_iam_instance_profile" "jw_instance_profile" {
  name = "jw-instance-profile"
  role = aws_iam_role.jw_ec2_role.name
}
