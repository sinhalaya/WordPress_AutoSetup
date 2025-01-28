
# Automated WordPress Setup For Ubuntu 22.04 LTS
# (Free SSL Certificate & Auto-Renewal)

This script automates the installation of WordPress, along with the required services on an Ubuntu 22.04 LTS server. It sets up a full LAMP stack with Tengine (Nginx), MariaDB, PHP, Redis, Memcached, and phpMyAdmin, while configuring a free SSL certificate using Let's Encrypt. The script also sets up auto-renewal for the SSL certificate to ensure your site remains secure.

## Features
- **Ubuntu 22.04 LTS Compatibility:** Ensures compatibility with Ubuntu 22.04 LTS.
- **Full LAMP Stack:** Installs Tengine (Nginx), MariaDB, PHP 8.4, Redis, Memcached, and phpMyAdmin.
- **Free SSL Certificate:** Uses Let's Encrypt to generate a free SSL certificate for your domain.
- **Auto-Renewal:** Automatically renews the SSL certificate using a cron job.
- **WordPress Installation:** Downloads and sets up the latest version of WordPress.
- **Redis Object Cache:** Installs and configures the Redis Object Cache plugin for WordPress.
- **phpMyAdmin Access:** Configures phpMyAdmin with Basic Authentication for secure access.
- **Server Status Monitoring:** Provides a secure server status page with uptime and resource usage details.

## Prerequisites
- A fresh Ubuntu 22.04 LTS server.
- A domain or subdomain pointing to the server.
- Ports 80, 443, 3306, 6379, and 11211 must be open (along with mail server ports 25, 465, and 587).

## Usage

1. **Clone the Script**  
   Download the script to your server using `wget` or `curl`.

2. **Run the Script**  
   Give the script executable permissions and run it:
   ```bash
   chmod +x setup-wordpress.sh
   ./setup-wordpress.sh
   ```

3. **Follow the Prompts**  
   The script will ask for your domain name and proceed with the installation and configuration.

4. **Complete Installation**  
   Once the script finishes, it will provide a summary with the following details:
   - Your domain name.
   - WordPress admin login URL.
   - Admin email.
   - phpMyAdmin URL (secured with Basic Authentication).
   - SSL certificate status and renewal setup.

## Notes
- The script generates random passwords for the MySQL user, phpMyAdmin, and WordPress configuration.
- It uses Let's Encrypt to generate a free SSL certificate and configures auto-renewal via cron job to ensure the certificate is renewed automatically every 12 hours.
- The server status page is protected with Basic Authentication to provide system information securely.

## Author
- **Author:** RED Media Corporation  
- **Author URI:** [https://dev.redmedia.lk](https://dev.redmedia.lk)  
- **Copyright:** Sinhalaya Software Solutions

## License
This script is licensed under the MIT License. See LICENSE for details.
