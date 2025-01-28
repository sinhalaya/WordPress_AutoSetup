#!/bin/bash

# Author: RED Media Corporation
# Author URI: https://dev.redmedia.lk
# Copyright: Sinhalaya Software Solutions

# Variables
WP_ADMIN_EMAIL="info@example.com"
WP_ADMIN_PASSWORD="PassMeNow"
MYSQL_ROOT_PASSWORD="SecureRootPassword123"
WP_DB_NAME=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 10 | head -n 1)
WP_DB_USER=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 10 | head -n 1)
WP_DB_PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
PHPMYADMIN_USER=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 10 | head -n 1)
PHPMYADMIN_PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
STATUS_USER=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 10 | head -n 1)
STATUS_PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)

# Check OS (Only for Ubuntu 22.04 LTS)
OS=$(lsb_release -d | awk -F"\t" '{print $2}')
if [[ "$OS" != "Ubuntu 22.04 LTS" ]]; then
    echo "This script is only for Ubuntu 22.04 LTS. Aborting."
    exit 1
fi

# Check if required ports are open
REQUIRED_PORTS=(80 443 3306 6379 11211)
MAIL_PORTS=(25 465 587)
CLOSED_PORTS=()

for port in "${REQUIRED_PORTS[@]}"; do
    if ! nc -z localhost "$port"; then
        CLOSED_PORTS+=("$port")
    fi
done

for port in "${MAIL_PORTS[@]}"; do
    if ! nc -z localhost "$port"; then
        echo "Error: Mail server port $port is closed. Aborting."
        exit 1
    fi
done

if [ ${#CLOSED_PORTS[@]} -ne 0 ]; then
    echo "Error: The following required ports are closed: ${CLOSED_PORTS[*]}. Aborting."
    exit 1
else
    echo "All required ports are open."
fi

# Ask for domain or subdomain
read -p "Enter your domain or subdomain (e.g., example.com or sub.example.com): " DOMAIN

# Update and upgrade the system
sudo apt-get update -y
sudo apt-get upgrade -y

# Install Nginx (Tengine)
sudo apt-get install -y curl
curl -O https://tengine.taobao.org/download/tengine-2.3.2.tar.gz
tar -zxvf tengine-2.3.2.tar.gz
cd tengine-2.3.2
./configure
make
sudo make install
cd ..

# Install MariaDB 10.11
sudo apt-get install -y software-properties-common
sudo apt-key adv --fetch-keys 'https://mariadb.org/mariadb_release_signing_key.asc'
sudo add-apt-repository 'deb [arch=amd64,arm64,ppc64el] https://mirrors.xtom.ee/mariadb/repo/10.11/ubuntu jammy main'
sudo apt-get update -y
sudo apt-get install -y mariadb-server
sudo mysql_secure_installation <<EOF
$MYSQL_ROOT_PASSWORD
n
y
y
y
y
EOF

# Create WordPress database and user
sudo mysql -u root -p$MYSQL_ROOT_PASSWORD <<EOF
CREATE DATABASE $WP_DB_NAME;
CREATE USER '$WP_DB_USER'@'localhost' IDENTIFIED BY '$WP_DB_PASSWORD';
GRANT ALL PRIVILEGES ON $WP_DB_NAME.* TO '$WP_DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

# Install PHP 8.4 and WordPress recommended extensions
sudo apt-get install -y software-properties-common
sudo add-apt-repository ppa:ondrej/php -y
sudo apt-get update -y
sudo apt-get install -y php8.4 php8.4-fpm php8.4-mysql php8.4-curl php8.4-gd php8.4-mbstring php8.4-xml php8.4-xmlrpc php8.4-soap php8.4-intl php8.4-zip php8.4-redis php8.4-memcached php8.4-mail

# Install Redis and Memcached
sudo apt-get install -y redis-server memcached

# Install phpMyAdmin and secure it with Basic Auth
sudo apt-get install -y phpmyadmin
sudo htpasswd -cb /etc/nginx/.htpasswd $PHPMYADMIN_USER $PHPMYADMIN_PASSWORD
sudo ln -s /usr/share/phpmyadmin /var/www/html/phpmyadmin

# Download and configure WordPress
cd /var/www/html
sudo rm -rf *
sudo wget https://wordpress.org/latest.tar.gz
sudo tar -xzvf latest.tar.gz
sudo mv wordpress/* .
sudo rm -rf wordpress latest.tar.gz
sudo chown -R www-data:www-data /var/www/html
sudo chmod -R 755 /var/www/html

# Configure WordPress
sudo cp wp-config-sample.php wp-config.php
sudo sed -i "s/database_name_here/$WP_DB_NAME/" wp-config.php
sudo sed -i "s/username_here/$WP_DB_USER/" wp-config.php
sudo sed -i "s/password_here/$WP_DB_PASSWORD/" wp-config.php

# Change WordPress admin email
sudo sed -i "s/define( 'WP_DEBUG', false );/define( 'WP_DEBUG', false );\ndefine( 'WP_ADMIN_EMAIL', '$WP_ADMIN_EMAIL' );/" wp-config.php

# Configure Redis for WordPress
sudo apt-get install -y redis
sudo systemctl enable redis
sudo systemctl start redis

# Install Redis Object Cache plugin for WordPress
sudo wget https://downloads.wordpress.org/plugin/redis-cache.2.4.3.zip
sudo unzip redis-cache.2.4.3.zip -d /var/www/html/wp-content/plugins/
sudo rm redis-cache.2.4.3.zip

# Enable Redis Object Cache plugin
sudo tee /var/www/html/wp-content/object-cache.php <<EOF
<?php
require_once WP_CONTENT_DIR . '/plugins/redis-cache/includes/object-cache.php';
EOF

# Configure Nginx (Tengine) for the domain
sudo tee /usr/local/nginx/conf/nginx.conf <<EOF
worker_processes  1;

events {
    worker_connections  1024;
}

http {
    include       mime.types;
    default_type  application/octet-stream;

    sendfile        on;
    keepalive_timeout  65;

    server {
        listen       80;
        server_name  $DOMAIN;

        root   /var/www/html;
        index  index.php index.html index.htm;

        location / {
            try_files \$uri \$uri/ /index.php?\$args;
        }

        location ~ \.php\$ {
            include        fastcgi_params;
            fastcgi_pass   unix:/var/run/php/php8.4-fpm.sock;
            fastcgi_index  index.php;
            fastcgi_param  SCRIPT_FILENAME  \$document_root\$fastcgi_script_name;
        }

        location ~ /\.ht {
            deny  all;
        }

        location /phpmyadmin {
            auth_basic "Admin Login";
            auth_basic_user_file /etc/nginx/.htpasswd;
        }
    }

    server {
        listen 1919 ssl;
        server_name $DOMAIN;

        ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

        location /uptime {
            auth_basic "Server Status";
            auth_basic_user_file /etc/nginx/.htpasswd_status;

            default_type text/html;
            return 200 "<html><body><pre>$(uptime)\n\n$(free -h)\n\n$(df -h)\n\n$(top -bn1 | head -n 20)</pre></body></html>";
        }
    }
}
EOF

# Create Basic Auth for Server Status
sudo htpasswd -cb /etc/nginx/.htpasswd_status $STATUS_USER $STATUS_PASSWORD

# Install Certbot for Let's Encrypt SSL
sudo apt-get install -y certbot python3-certbot-nginx
sudo certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m $WP_ADMIN_EMAIL

# Set up auto-renewal for Let's Encrypt SSL
sudo crontab -l | { cat; echo "0 12 * * * /usr/bin/certbot renew --quiet"; } | sudo crontab -

# Restart services
sudo systemctl restart nginx
sudo systemctl restart php8.4-fpm
sudo systemctl restart mariadb
sudo systemctl restart redis-server
sudo systemctl restart memcached

# Output the summary
echo "===================================================="
echo "WordPress Setup Summary"
echo "===================================================="
echo "Domain: https://$DOMAIN"
echo "WordPress Admin Login: https://$DOMAIN/wp-admin"
echo "WordPress Admin Email: $WP_ADMIN_EMAIL"
echo "WordPress Admin Password: $WP_ADMIN_PASSWORD"
echo "Database Name: $WP_DB_NAME"
echo "Database User: $WP_DB_USER"
echo "Database Password: $WP_DB_PASSWORD"
echo "phpMyAdmin URL: https://$DOMAIN/phpmyadmin"
echo "phpMyAdmin Username: $PHPMYADMIN_USER"
echo "phpMyAdmin Password: $PHPMYADMIN_PASSWORD"
echo "Redis Object Cache: Installed and Configured"
echo "Let's Encrypt SSL: Installed and Auto-Renewal Configured"
echo "Server Status URL: https://$DOMAIN:1919/uptime"
echo "Server Status Username: $STATUS_USER"
echo "Server Status Password: $STATUS_PASSWORD"
echo "===================================================="
