#!/bin/sh
set -e

# Substitute only specific environment variables in config.production.json
# This prevents envsubst from replacing unintended $ patterns
export VARS='$DATABASE_HOST:$DATABASE_PORT:$DATABASE_SOCKET_PATH:$DATABASE_USER:$DATABASE_PASSWORD:$DATABASE_NAME:$GCS_BUCKET:$GCS_ASSET_DOMAIN:$GHOST_URL:$GHOST_MAIL_FROM:$GHOST_MAIL_TRANSPORT'

envsubst "$VARS" < /var/lib/ghost/config.production.json > /tmp/config.json
mv /tmp/config.json /var/lib/ghost/config.production.json

# Create necessary directories
mkdir -p /var/lib/ghost/content/images
mkdir -p /var/lib/ghost/content/logs
mkdir -p /var/lib/ghost/content/data
mkdir -p /var/lib/ghost/content/themes

# Set proper permissions
chown -R node:node /var/lib/ghost/content

# Execute the main command (Ghost will run migrations automatically on startup)
exec "$@"
