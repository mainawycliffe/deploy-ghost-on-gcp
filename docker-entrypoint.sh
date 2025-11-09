#!/bin/sh
set -e

# Render Ghost config using jq to ensure JSON-safe values
jq -n \
  --arg url "${GHOST_URL:-}" \
  --arg socket "${DATABASE_SOCKET_PATH:-}" \
  --arg user "${DATABASE_USER:-}" \
  --arg password "${DATABASE_PASSWORD:-}" \
  --arg dbname "${DATABASE_NAME:-}" \
  --arg bucket "${GCS_BUCKET:-}" \
  --arg asset "${GCS_ASSET_DOMAIN:-}" \
  --arg mail_from "${GHOST_MAIL_FROM:-}" \
  --arg mail_transport "${GHOST_MAIL_TRANSPORT:-}" \
  '{
    url: $url,
    server: {port: 2368, host: "0.0.0.0"},
    database: {
      client: "mysql",
      connection: {socketPath: $socket, user: $user, password: $password, database: $dbname, charset: "utf8mb4"},
      pool: {min: 0, max: 5}
    },
    mail: {transport: $mail_transport, from: $mail_from},
    logging: {level: "info", rotation: {enabled: true}, transports: ["stdout"]},
    process: "local",
    paths: {contentPath: "/var/lib/ghost/content"},
    storage: {active: "gcs", gcs: {bucket: $bucket, assetDomain: $asset, insecure: false, maxAge: 2678400}},
    imageOptimization: {resize: true},
    privacy: {useRpcPing: false, useUpdateCheck: true},
    useMinFiles: true,
    caching: {frontend: {maxAge: 600}}
  }' > /var/lib/ghost/config.production.json

# Copy themes at runtime (since /var/lib/ghost/content is a VOLUME in base image)
# Data added after VOLUME declaration in Dockerfile is lost
if [ ! -d "/var/lib/ghost/content/themes/casper" ]; then
    echo "Copying Ghost themes..."
    mkdir -p /var/lib/ghost/content/themes
    cp -r /var/lib/ghost/current/content/themes/* /var/lib/ghost/content/themes/
fi

# Ensure all content directories exist with proper permissions
chown -R node:node /var/lib/ghost/content

# Execute the main command (Ghost will run migrations automatically on startup)
exec "$@"
