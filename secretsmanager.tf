resource "aws_secretsmanager_secret" "db_secret" {
  name = var.db_secret_name

  tags = {
    Name = "jw-db-secret"
  }
}

data "aws_secretsmanager_secret_version" "db_creds" {
  secret_id = aws_secretsmanager_secret.db_secret.id
}
