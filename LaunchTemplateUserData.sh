#!/bin/bash

# Redirect all output to a log file
exec > /var/log/user-data.log 2>&1


########################################
# Variables
########################################
REGION="us-west-2"                  # REPLACE with your AWS Region, e.g. eu-central-1
EFS_ID="${efs_id}"                   # REPLACE with your EFS File System ID
EFS_AP_ID="${efs_ap_id}"              # REPLACE with your EFS Access Point ID
SECRET_NAME="wpsecrets"

APACHE_USER="apache"
APACHE_GROUP="apache"
APACHE_UID=48
APACHE_GID=48

########################################
# Install packages
########################################
dnf update -y
# Web server, PHP, MariaDB client, EFS utils
dnf install -y httpd mariadb1011-server-utils unzip wget python3 amazon-efs-utils
# PHP and extensions
dnf install -y php php-mysqlnd php-fpm php-json php-mbstring php-xml php-gd

systemctl enable httpd
systemctl enable php-fpm
systemctl stop httpd

########################################
# Mount EFS with Access Point
########################################
mkdir -p /mnt/efs

mount -t efs -o tls,accesspoint=$EFS_AP_ID $EFS_ID:/ /mnt/efs

# IMPORTANT:
# Because your Access Point root directory **is /wp-content**, 
# /mnt/efs *already IS* the wp-content directory.
# Accesspoint settings: rootuser=48 rootgroup=48 user=apache (uid 48), group=apache (gid 48), permissions=0755
# No mkdir/chown needed!

########################################
# Install WordPress (local)
########################################
cd /tmp
wget https://wordpress.org/latest.zip
unzip latest.zip

cp -r wordpress/* /var/www/html/

########################################
# Sync WordPress wp-content → EFS (ASG safe)
########################################

# Ensure required directories exist
mkdir -p /mnt/efs/plugins
mkdir -p /mnt/efs/themes

# Copy default themes ONCE per theme (safe because IDs differ)
for theme in /var/www/html/wp-content/themes/*; do
    base=$(basename "$theme")
    if [ ! -d "/mnt/efs/themes/$base" ]; then
        cp -r "$theme" /mnt/efs/themes/
    fi
done

# Copy default plugins ONCE per plugin (also safe)
for plugin in /var/www/html/wp-content/plugins/*; do
    base=$(basename "$plugin")
    if [ ! -d "/mnt/efs/plugins/$base" ]; then
        cp -r "$plugin" /mnt/efs/plugins/
    fi
done

# Always overwrite index.php (harmless and recommended)
cp /var/www/html/wp-content/index.php /mnt/efs/

########################################
# Replace wp-content with EFS mount
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

# Ensure WordPress uses SSL for DB connections (required by RDS setting)
# Insert MYSQL_CLIENT_FLAGS after the DB_HOST definition
sed -i "/^define('DB_HOST'/a define('MYSQL_CLIENT_FLAGS', MYSQLI_CLIENT_SSL);" wp-config.php

########################################
# Permissions (local only)
########################################
chown -R $APACHE_USER:$APACHE_GROUP /var/www/html
chmod -R 755 /var/www/html

########################################
# Health Check
########################################
echo "healthy" > /var/www/html/health
chown $APACHE_USER:$APACHE_GROUP /var/www/html/health
chmod 755 /var/www/html/health

########################################
# Start services
########################################
sleep 60
systemctl start php-fpm
systemctl start httpd