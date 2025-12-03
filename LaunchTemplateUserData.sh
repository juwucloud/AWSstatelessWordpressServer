#!/bin/bash
set -euxo pipefail

# Log alles nach /var/log/user-data.log
exec > /var/log/user-data.log 2>&1

# wait for network and services 
sleep 30 

########################################
# Variables
########################################
REGION="us-west-2"
EFS_ID="${efs_id}"
EFS_AP_ID="${efs_ap_id}"
SECRET_NAME="wpsecrets"
S3_BUCKET="veganlian-artifacts"
WP_URL="http://${alb_dns}"

APACHE_USER="apache"
APACHE_GROUP="apache"

echo "WP_URL is set to $WP_URL"

########################################
# Install packages
########################################
dnf update -y
dnf install -y httpd mariadb1011-server-utils unzip wget python3 amazon-efs-utils vim
dnf install -y php php-mysqlnd php-fpm php-json php-mbstring php-xml php-gd

# Enable WordPress permalinks on Apache
sed -i 's/^#LoadModule rewrite_module/LoadModule rewrite_module/' /etc/httpd/conf.modules.d/00-base.conf
sed -i 's/AllowOverride None/AllowOverride All/' /etc/httpd/conf/httpd.conf

cat >/etc/httpd/conf.d/wordpress.conf <<'EOF'
<Directory "/var/www/html">
    AllowOverride All
    Require all granted
</Directory>
DirectoryIndex index.php
EOF

systemctl enable httpd
systemctl enable php-fpm
systemctl stop httpd

mkdir -p /var/www/html

sleep 15 
########################################
# Mount EFS (Access Point = /wp-content)
########################################
mkdir -p /mnt/efs
mount -t efs -o tls,accesspoint="$EFS_AP_ID" "$EFS_ID":/ /mnt/efs

########################################
# Fetch DB secrets
########################################
echo "Fetching database secrets from Secrets Manager..."
SECRET=$(aws secretsmanager get-secret-value \
    --secret-id "$SECRET_NAME" \
    --region "$REGION" \
    --query SecretString \
    --output text)

DB_NAME=$(echo "$SECRET" | python3 -c "import json,sys; print(json.load(sys.stdin)['db_name'])")
DB_USER=$(echo "$SECRET" | python3 -c "import json,sys; print(json.load(sys.stdin)['db_user'])")
DB_PASSWORD=$(echo "$SECRET" | python3 -c "import json,sys; print(json.load(sys.stdin)['db_password'])")
DB_HOST=$(echo "$SECRET" | python3 -c "import json,sys; print(json.load(sys.stdin)['db_host'])")

echo "DB_NAME=$DB_NAME, DB_USER=$DB_USER, DB_HOST=$DB_HOST"

########################################
# Download & unpack WordPress from S3
########################################
echo "Downloading WordPress package from S3..."
aws s3 cp "s3://$S3_BUCKET/wordpress.zip" /tmp/wp.zip

rm -rf /tmp/wp
mkdir -p /tmp/wp
unzip -oq /tmp/wp.zip -d /tmp/wp

########################################
# First time only: initialize wp-content + DB import
########################################
if [ ! -f /mnt/efs/.initialized ]; then
    echo "INITIAL SETUP START"

    # Sicherstellen, dass wp-content im EFS liegt (Access Point zeigt bereits auf /wp-content)
    mkdir -p /mnt/efs
    rm -rf /mnt/efs/*
    cp -R /tmp/wp/wp-content/* /mnt/efs/

    # local.sql importieren
    echo "Downloading local.sql from S3 and importing into DB..."
    aws s3 cp "s3://$S3_BUCKET/local.sql" /tmp/local.sql
    

    # Check if database is ready before import
    echo "Waiting for database to be ready..."
    for i in {1..30}; do
        if mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" -e "SELECT 1;" >/dev/null 2>&1; then
            echo "Database connection successful"
            break
        fi
        echo "Database not ready, attempt $i/30..."
        sleep 10
    done

    # Verify connection worked
    mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" -e "SELECT 1;" || {
        echo "Database connection failed after 5 minutes"
        exit 1
    }
    mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" < /tmp/local.sql

    touch /mnt/efs/.initialized
    echo "INITIAL SETUP DONE"
fi

########################################
# Deploy WordPress core (ohne wp-content)
########################################
echo "Deploying WordPress core files..."
rm -rf /var/www/html/*
cp -R /tmp/wp/* /var/www/html/
rm -rf /var/www/html/wp-content

########################################
# Symlink wp-content from EFS
########################################
echo "Linking wp-content from EFS..."
rm -rf /var/www/html/wp-content
# Access Point zeigt auf /wp-content, also ist /mnt/efs der Inhalt dieser wp-content
ln -s /mnt/efs /var/www/html/wp-content

########################################
# Force-build a clean wp-config.php
########################################
echo "Rebuilding wp-config.php..."
rm -f /var/www/html/wp-config.php
cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php

# Test DB connection
mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" -e "SELECT 1;" || {
    echo "Database connection test failed"
    exit 1
}

sed -i "s/database_name_here/$DB_NAME/"    /var/www/html/wp-config.php
sed -i "s/username_here/$DB_USER/"         /var/www/html/wp-config.php
sed -i "s/password_here/$DB_PASSWORD/"     /var/www/html/wp-config.php
sed -i "s/localhost/$DB_HOST/"             /var/www/html/wp-config.php

# Seed standard WordPress rewrite rules so pretty URLs work on first boot
cat >/var/www/html/.htaccess <<'EOF'
# BEGIN WordPress
<IfModule mod_rewrite.c>
RewriteEngine On
RewriteBase /
RewriteRule ^index\.php$ - [L]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /index.php [L]
</IfModule>
# END WordPress
EOF
chown $APACHE_USER:$APACHE_GROUP /var/www/html/.htaccess


########################################
# Force SSL for WordPress DB
########################################

sed -i "/define( 'DB_HOST',/a define( 'MYSQL_CLIENT_FLAGS', MYSQLI_CLIENT_SSL );" /var/www/html/wp-config.php

########################################
# Set WordPress URL in DB
########################################
echo "Setting WordPress siteurl & home to $WP_URL ..."
mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" <<EOF
UPDATE wp_options SET option_value='$WP_URL' WHERE option_name='siteurl';
UPDATE wp_options SET option_value='$WP_URL' WHERE option_name='home';
EOF

########################################
# Permissions
########################################
echo "Adjusting permissions..."
chown -R $APACHE_USER:$APACHE_GROUP /var/www/html
chmod -R 755 /var/www/html

########################################
# Health check
########################################
echo "Creating health check file..."
echo "healthy" > /var/www/html/health
chown $APACHE_USER:$APACHE_GROUP /var/www/html/health
chmod 755 /var/www/html/health

########################################
# Start services
########################################
echo "Restarting services..."
systemctl restart php-fpm
systemctl restart httpd

echo "User-data finished successfully."
