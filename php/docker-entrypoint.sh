#!/bin/sh
set -e

# Wait for the Database to be ready (checked using PHP mysqli to avoid binary dependencies)
echo "Waiting for MySQL database at '${DB_HOST}'..."
until php -r "mysqli_report(MYSQLI_REPORT_OFF); \$conn = @new mysqli('${DB_HOST}', '${DB_USER}', '${DB_PASSWORD}', '${DB_NAME}'); if (\$conn->connect_error) { exit(1); }"; do
    echo -n "."
    sleep 2
done
echo -e "\nDatabase is ready!"

# If wp-config.php doesn't exist, initialize WordPress
if [ ! -f "/var/www/html/wp-config.php" ]; then
    echo "WordPress is not installed. Initiating automated setup..."

    # 1. Download WordPress
    echo "Downloading WordPress..."
    wp core download --allow-root

    # 2. Create wp-config.php
    echo "Creating wp-config.php..."
    wp config create \
        --dbname="${DB_NAME}" \
        --dbuser="${DB_USER}" \
        --dbpass="${DB_PASSWORD}" \
        --dbhost="${DB_HOST}" \
        --allow-root

    # 3. Install WordPress
    echo "Installing WordPress..."
    wp core install \
        --url="${WP_URL}" \
        --title="${WP_TITLE}" \
        --admin_user="${WP_ADMIN_USER}" \
        --admin_password="${WP_ADMIN_PASSWORD}" \
        --admin_email="${WP_ADMIN_EMAIL}" \
        --allow-root

    # 4. Convert to Multisite
    echo "Converting to Multisite..."
    wp core multisite-convert \
        --title="${WP_TITLE}" \
        --allow-root
    
    # Ensure the admin user has super-admin privileges in the Multisite network
    wp super-admin add "${WP_ADMIN_USER}" --allow-root

    # Install Arabic language pack by default alongside English
    echo "Installing Arabic language pack..."
    wp language core install ar --allow-root

    # 5. Ensure correct permissions for wp-content
    echo "Configuring permissions..."
    chmod -R 777 /var/www/html/wp-content || true
    
    echo "WordPress Multisite Setup Complete!"
else
    # WordPress is already installed.
    # Check if the domain/port has changed in the settings and automatically update the DB & config.
    echo "Checking if site domain has changed..."
    
    # Get current domain from database (main site, blog ID 1) using WP-CLI
    DB_DOMAIN=$(wp site list --blog_id=1 --field=domain --allow-root 2>/dev/null | tr -d '\r' | tr -d '\n')
    TARGET_DOMAIN="${WP_DOMAIN}"
    
    if [ -n "$WP_PORT" ] && [ "$WP_PORT" != "80" ] && [ "$WP_PORT" != "443" ]; then
        TARGET_DOMAIN="${WP_DOMAIN}:${WP_PORT}"
    fi

    if [ -n "$DB_DOMAIN" ] && [ "$DB_DOMAIN" != "$TARGET_DOMAIN" ]; then
        echo "Domain change detected: '${DB_DOMAIN}' -> '${TARGET_DOMAIN}'"
        echo "Running search-replace in the database..."
        
        # Run search-replace across network tables
        wp search-replace "$DB_DOMAIN" "$TARGET_DOMAIN" --network --allow-root
        
        # Update the DOMAIN_CURRENT_SITE constant in wp-config.php using regex
        echo "Updating DOMAIN_CURRENT_SITE in wp-config.php..."
        sed -i -E "s/define\(\s*['\"]DOMAIN_CURRENT_SITE['\"]\s*,\s*['\"].*['\"]\s*\);/define( 'DOMAIN_CURRENT_SITE', '$TARGET_DOMAIN' );/g" /var/www/html/wp-config.php
        
        echo "Database and config domain update complete!"
    fi

    # Sync admin credentials (username, password, email, display_name) with settings
    echo "Syncing admin credentials with current configuration..."
    php -r "\$mysqli = new mysqli(getenv('DB_HOST'), getenv('DB_USER'), getenv('DB_PASSWORD'), getenv('DB_NAME')); \$mysqli->query(\"UPDATE wp_users SET user_login = '\" . \$mysqli->real_escape_string(getenv('WP_ADMIN_USER')) . \"' WHERE ID = 1\");"
    wp user update 1 \
        --user_pass="${WP_ADMIN_PASSWORD}" \
        --user_email="${WP_ADMIN_EMAIL}" \
        --display_name="${WP_ADMIN_USER}" \
        --nickname="${WP_ADMIN_USER}" \
        --allow-root 2>/dev/null || true
    
    # Ensure current synced username is super-admin
    wp super-admin add "${WP_ADMIN_USER}" --allow-root
    echo "Admin credentials sync complete!"
fi

# Run the standard PHP-FPM CMD
exec "$@"
