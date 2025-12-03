#!/bin/bash
set -euxo pipefail

exec > /var/log/user-data.log 2>&1

########################################
# Variables
########################################
REGION="us-west-2"
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
dnf install -y httpd mariadb1011-server-utils unzip wget python3 amazon-efs-utils rsync vim
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
# Fetch DB secrets
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
# Always download WP ZIP and unpack
########################################
aws s3 cp "s3://$S3_BUCKET/wordpress.zip" /tmp/wp.zip
unzip -o /tmp/wp.zip -d /tmp/wp


########################################
# Always deploy WP Core (exclude wp-content)
########################################
rsync -a --delete --exclude 'wp-content' /tmp/wp/ /var/www/html/


########################################
# First time only: initialize wp-content + DB import
########################################
if [ ! -f /mnt/efs/.initialized ]; then

    echo "Running first-time setup"

    #
    # Populate wp-content in EFS (first time only)
    #
    if [ -d /tmp/wp/wp-content ]; then
        cp -r /tmp/wp/wp-content/* /mnt/efs/
    fi

    #
    # Import DB dump
    #
    aws s3 cp "s3://$S3_BUCKET/local.sql" /tmp/local.sql
    mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" < /tmp/local.sql

    #
    # Mark initialization complete
    #
    touch /mnt/efs/.initialized
fi


########################################
# Symlink wp-content from EFS
########################################
rm -rf /var/www/html/wp-content
ln -s /mnt/efs /var/www/html/wp-content


########################################
# Build or update wp-config.php
########################################

if [ ! -f /var/www/html/wp-config.php ]; then
    cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php
fi

sed -i "s/database_name_here/$DB_NAME/"       /var/www/html/wp-config.php
sed -i "s/username_here/$DB_USER/"            /var/www/html/wp-config.php
sed -i "s/password_here/$DB_PASSWORD/"        /var/www/html/wp-config.php
sed -i "s/localhost/$DB_HOST/"                /var/www/html/wp-config.php


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
