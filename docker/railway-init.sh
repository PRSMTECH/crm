#!/bin/bash
set -e

cd /home/frappe/frappe-bench

# Configure database connection using Railway environment variables
if [ -n "$MYSQL_URL" ]; then
    echo "Configuring MariaDB from MYSQL_URL..."
    echo "MYSQL_URL: $MYSQL_URL"

    # Parse Railway's MYSQL_URL (format: mysql://user:pass@host:port/db)
    # Remove mysql:// prefix first
    URL_PART=$(echo $MYSQL_URL | sed 's/^mysql:\/\///')

    # Extract user (before first :)
    export DB_USER=$(echo $URL_PART | cut -d: -f1)

    # Extract password (between first : and @)
    export DB_PASS=$(echo $URL_PART | sed 's/^[^:]*://' | sed 's/@.*//')

    # Extract host:port/db (after @)
    HOST_PART=$(echo $URL_PART | sed 's/^.*@//')

    # Extract host (before :)
    export DB_HOST=$(echo $HOST_PART | cut -d: -f1)

    # Extract port (between : and /)
    export DB_PORT=$(echo $HOST_PART | cut -d: -f2 | cut -d/ -f1)

    # Extract database name (after /)
    export DB_NAME=$(echo $HOST_PART | cut -d/ -f2)

    echo "Parsed - Host: $DB_HOST, Port: $DB_PORT, User: $DB_USER, DB: $DB_NAME"

    bench set-mariadb-host $DB_HOST
fi

# Configure Redis from Railway environment variables
if [ -n "$REDIS_URL" ]; then
    echo "Configuring Redis from REDIS_URL..."
    echo "REDIS_URL: $REDIS_URL"

    # Railway Redis URL format: redis://default:password@host:port
    # For Frappe, we need the full URL with auth
    export REDIS_FULL_URL="$REDIS_URL"
    echo "Redis connection: $REDIS_FULL_URL"
fi

# Remove redis and watch from Procfile (Railway provides these)
sed -i '/redis/d' ./Procfile 2>/dev/null || true
sed -i '/watch/d' ./Procfile 2>/dev/null || true

# Create site if not exists
if [ ! -d "sites/crm.localhost" ]; then
    echo "Creating new site..."
    echo "DB_HOST: $DB_HOST"
    echo "DB_PORT: $DB_PORT"
    echo "DB_USER: $DB_USER"

    # Use Railway MySQL host if available, otherwise localhost
    if [ -n "$DB_HOST" ]; then
        bench new-site crm.localhost \
            --force \
            --db-host $DB_HOST \
            --db-port ${DB_PORT:-3306} \
            --db-root-username ${DB_USER:-root} \
            --db-root-password "${DB_PASS}" \
            --mariadb-root-password "${DB_PASS:-${DB_ROOT_PASSWORD:-123}}" \
            --admin-password ${ADMIN_PASSWORD:-admin} \
            --no-mariadb-socket
    else
        bench new-site crm.localhost \
            --force \
            --mariadb-root-password ${DB_ROOT_PASSWORD:-123} \
            --admin-password ${ADMIN_PASSWORD:-admin} \
            --no-mariadb-socket
    fi

    bench --site crm.localhost install-app crm
    bench --site crm.localhost set-config developer_mode 0
    bench --site crm.localhost set-config mute_emails 0
    bench --site crm.localhost set-config server_script_enabled 1
fi

# Configure Redis URLs in common site config (applies to all sites)
if [ -n "$REDIS_URL" ]; then
    echo "Setting Redis configuration..."
    # Update common_site_config.json with Redis URLs
    CONFIG_FILE="sites/common_site_config.json"
    if [ -f "$CONFIG_FILE" ]; then
        python3 << EOF
import json
with open('$CONFIG_FILE', 'r') as f:
    config = json.load(f)
config['redis_cache'] = '$REDIS_URL'
config['redis_queue'] = '$REDIS_URL'
config['redis_socketio'] = '$REDIS_URL'
with open('$CONFIG_FILE', 'w') as f:
    json.dump(config, f, indent=2)
print('Redis configuration updated in common_site_config.json')
EOF
    else
        echo '{"redis_cache": "'$REDIS_URL'", "redis_queue": "'$REDIS_URL'", "redis_socketio": "'$REDIS_URL'"}' > "$CONFIG_FILE"
        echo "Created common_site_config.json with Redis configuration"
    fi
    cat "$CONFIG_FILE"
fi

bench --site crm.localhost clear-cache
bench use crm.localhost

# Start Frappe
exec bench start
