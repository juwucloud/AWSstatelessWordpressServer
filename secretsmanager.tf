########################################
# Read existing secret container
########################################

data "aws_secretsmanager_secret" "db_secret" {
  name = var.db_secret_name  # "wpsecrets"
}

########################################
# Read current secret content
########################################

data "aws_secretsmanager_secret_version" "db_creds" {
  secret_id = data.aws_secretsmanager_secret.db_secret.id
}

########################################
# Update only the db_host after RDS is created
########################################

resource "aws_secretsmanager_secret_version" "db_creds_update" {
  secret_id = data.aws_secretsmanager_secret.db_secret.id

  secret_string = jsonencode({
    db_name     = jsondecode(data.aws_secretsmanager_secret_version.db_creds.secret_string)["db_name"]
    db_user     = jsondecode(data.aws_secretsmanager_secret_version.db_creds.secret_string)["db_user"]
    db_password = jsondecode(data.aws_secretsmanager_secret_version.db_creds.secret_string)["db_password"]
    db_host     = aws_db_instance.jwrds.address
  })

  depends_on = [
    aws_db_instance.jwrds
  ]
}
