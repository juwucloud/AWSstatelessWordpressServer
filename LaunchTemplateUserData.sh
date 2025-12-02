#!/bin/bash
set -euxo pipefail

exec > /var/log/user-data.log 2>&1

########################################
# Variables
########################################
REGION="eu-central-1"
EFS_ID="${efs_id}"
EFS_AP_ID="${efs_ap_id}"
SECRET_NAME="wpsecrets"
S3_BUCKET="veganlian-artifacts"

APACHE_USER="apache"
APACHE_GROUP="apache"

########################################
# Install packages
########################################
dnf update -y
dnf install -y httpd mariadb1011-server-utils unzip wget python3 amazon-efs-utils
dnf install -y php php-mysqlnd php-fpm php-json php-mbstring php-xml php-gd

systemctl enable httpd
systemctl enable php-fpm
systemctl stop httpd

########################################
# Mount EFS
########################################
mkdir -p /mnt/efs
mount -t efs -o tls,accesspoint=$EFS_AP_ID $EFS_ID:/ /mnt/efs

########################################
# Deploy WordPress build from S3
########################################
cd /tmp
aws s3 cp "s3://$S3_BUCKET/wordpress.zip" wordpress.zip
unzip wordpress.zip -d /var/www/html

########################################
# Replace wp-content with EFS
########################################
rm -rf /var/www/html/wp-content
ln -s /mnt/efs /var/www/html/wp-content

########################################
# Fetch RDS credentials
########################################
SECRET=$(aws secretsmanager get-secret-value \
    --secret-id "$SECRET_NAME" \
    --region "$REGION" \
    --query SecretString \
    --output text)

DB_NAME=$(echo "$SECRET" | python3 -c "import json,sys; print(json.load(sys.stdin)['db_name'])")
DB_USER=$(echo "$SECRET" | python3 -c "import json,sys; print(json.load(sys.stdin)['db_user'])")
DB_PASSWORD=$(echo "$SECRET" | python3 -c "import json,sys; print(json.load(sys.stdin)['db_password'])")
DB_HOST=$(echo "$SECRET" | python3 -c "import json,sys; print(json.load(sys.stdin)['db_host'])")


########################################
# Configure wp-config.php
########################################
cd /var/www/html
cp wp-config-sample.php wp-config.php

sed -i "s/database_name_here/$DB_NAME/" wp-config.php
sed -i "s/username_here/$DB_USER/" wp-config.php
sed -i "s/password_here/$DB_PASSWORD/" wp-config.php
sed -i "s/localhost/$DB_HOST/" wp-config.php

sed -i "/define( 'DB_HOST',/a define( 'MYSQL_CLIENT_FLAGS', MYSQLI_CLIENT_SSL );" wp-config.php


########################################
# One-time DB import (optional)
########################################
FLAG="/mnt/efs/.dbimportdone"

if [ ! -f "$FLAG" ]; then
    aws s3 cp "s3://$S3_BUCKET/local.sql" /tmp/local.sql
    mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" < /tmp/local.sql || true
    touch "$FLAG"
fi

########################################
# Permissions
########################################
chown -R $APACHE_USER:$APACHE_GROUP /var/www/html
chmod -R 755 /var/www/html

########################################
# Health check
########################################
echo "healthy" > /var/www/html/health
chown $APACHE_USER:$APACHE_GROUP /var/www/html/health
chmod 755 /var/www/html/health

########################################
# Start services
########################################
systemctl restart php-fpm
systemctl restart httpd
