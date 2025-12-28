#!/bin/bash
set -e

cd /home/frappe/frappe-bench

# Configure database connection using Railway environment variables
if [ -n "$MYSQL_URL" ]; then
    echo "Configuring MariaDB from MYSQL_URL..."
    # Parse Railway's MYSQL_URL (format: mysql://user:pass@host:port/db)
    export DB_HOST=$(echo $MYSQL_URL | sed -e 's/^.*@//' -e 's/:.*$//')
    export DB_PORT=$(echo $MYSQL_URL | sed -e 's/^.*://' -e 's/\/.*$//')
    export DB_NAME=$(echo $MYSQL_URL | sed -e 's/^.*\///')
    export DB_USER=$(echo $MYSQL_URL | sed -e 's/^mysql:\/\///' -e 's/:.*$//')
    export DB_PASS=$(echo $MYSQL_URL | sed -e 's/^.*://' -e 's/@.*$//' | head -1)

    bench set-mariadb-host $DB_HOST
fi

# Configure Redis from Railway environment variables
if [ -n "$REDIS_URL" ]; then
    echo "Configuring Redis from REDIS_URL..."
    export REDIS_HOST=$(echo $REDIS_URL | sed -e 's/^redis:\/\///' -e 's/:.*$//')

    bench set-redis-cache-host $REDIS_HOST
    bench set-redis-queue-host $REDIS_HOST
    bench set-redis-socketio-host $REDIS_HOST
fi

# Remove redis and watch from Procfile (Railway provides these)
sed -i '/redis/d' ./Procfile 2>/dev/null || true
sed -i '/watch/d' ./Procfile 2>/dev/null || true

# Create site if not exists
if [ ! -d "sites/crm.localhost" ]; then
    echo "Creating new site..."
    bench new-site crm.localhost \
        --force \
        --mariadb-root-password ${DB_ROOT_PASSWORD:-123} \
        --admin-password ${ADMIN_PASSWORD:-admin} \
        --no-mariadb-socket

    bench --site crm.localhost install-app crm
    bench --site crm.localhost set-config developer_mode 0
    bench --site crm.localhost set-config mute_emails 0
    bench --site crm.localhost set-config server_script_enabled 1
fi

bench --site crm.localhost clear-cache
bench use crm.localhost

# Start Frappe
exec bench start
