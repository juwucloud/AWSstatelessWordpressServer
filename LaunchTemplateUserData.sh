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
dnf install -y httpd mariadb1011-server-utils unzip wget python3 amazon-efs-utils vim
dnf install -y php php-mysqlnd php-fpm php-json php-mbstring php-xml php-gd

systemctl enable httpd
systemctl enable php-fpm
systemctl stop httpd

########################################
# mount efs
########################################
mkdir -p /mnt/efs

mount -t efs -o tls,accesspoint=$EFS_AP_ID $EFS_ID:/ /mnt/efs


########################################
# Check initialization flag
########################################

# fetch secrets
SECRET=$(aws secretsmanager get-secret-value --secret-id "$SECRET_NAME" --region "$REGION" --query SecretString --output text)

DB_NAME=$(echo "$SECRET" | python3 -c "import json,sys; print(json.load(sys.stdin)['db_name'])")
DB_USER=$(echo "$SECRET" | python3 -c "import json,sys; print(json.load(sys.stdin)['db_user'])")
DB_PASSWORD=$(echo "$SECRET" | python3 -c "import json,sys; print(json.load(sys.stdin)['db_password'])")
DB_HOST=$(echo "$SECRET" | python3 -c "import json,sys; print(json.load(sys.stdin)['db_host'])")

if [ ! -f /mnt/efs/.initialized ]; then

    echo "Running first-time setup"

    # Download and unpack site
    aws s3 cp "s3://$S3_BUCKET/wordpress.zip" /tmp/wp.zip
    unzip /tmp/wp.zip -d /tmp/wp

    # move wp core to html
    cp -r /tmp/wp/* /var/www/html/

        # Initial wp-content → copy EFS (only first boot)
    if [ -d /var/www/html/wp-content ]; then
        # nur wenn EFS noch leer ist
        if [ -z "$(ls -A /mnt/efs 2>/dev/null)" ]; then
            cp -r /var/www/html/wp-content/* /mnt/efs/
        fi
    fi

    # import DB
    aws s3 cp "s3://$S3_BUCKET/local.sql" /tmp/local.sql
    mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" < /tmp/local.sql

    # mark as complete
    touch /mnt/efs/.initialized
fi


########################################
# point wp-content to efs
########################################

rm -rf /var/www/html/wp-content
ln -s /mnt/efs /var/www/html/wp-content


########################################
# build wp-config if missing
########################################

if [ ! -f /var/www/html/wp-config.php ]; then

    cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php

    sed -i "s/database_name_here/$DB_NAME/" /var/www/html/wp-config.php
    sed -i "s/username_here/$DB_USER/" /var/www/html/wp-config.php
    sed -i "s/password_here/$DB_PASSWORD/" /var/www/html/wp-config.php
    sed -i "s/localhost/$DB_HOST/" /var/www/html/wp-config.php

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
