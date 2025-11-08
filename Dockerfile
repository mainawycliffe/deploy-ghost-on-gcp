# Multi-stage build for Ghost CMS on Cloud Run with Google Cloud Storage

# Stage 1: Build GCS adapter
FROM node:18-alpine AS adapter-builder

WORKDIR /build

# Install GCS adapter
ARG GCS_ADAPTER_VERSION="master"
RUN apk add --no-cache curl && \
    mkdir -p /build/gcs && \
    curl -fsSL "https://api.github.com/repos/danmasta/ghost-gcs-adapter/tarball/${GCS_ADAPTER_VERSION}" | tar xz --strip-components=1 -C /build/gcs && \
    npm install --prefix /build/gcs --omit=dev --omit=optional --no-progress

# Stage 2: Final Ghost image
FROM ghost:5-alpine

# Install runtime dependencies
RUN apk add --no-cache gettext

# Install Google Cloud Storage SDK
WORKDIR /var/lib/ghost/current
RUN npm install --legacy-peer-deps @google-cloud/storage

# Copy GCS adapter from builder stage
COPY --from=adapter-builder /build/gcs /var/lib/ghost/content/adapters/storage/gcs

# Set up directory structure and permissions
WORKDIR /var/lib/ghost/current
RUN chown -R node:node /var/lib/ghost/content && \
    cp -r /var/lib/ghost/current/content/themes /var/lib/ghost/content/ && \
    chown -R node:node /var/lib/ghost/content/themes

# Copy custom configuration
COPY config.production.json /var/lib/ghost/config.production.json
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint-custom.sh
RUN chmod +x /usr/local/bin/docker-entrypoint-custom.sh

# Set working directory
WORKDIR /var/lib/ghost

# Expose Ghost port
EXPOSE 2368

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=3 \
    CMD node -e "require('http').get('http://localhost:2368', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# Use custom entrypoint
ENTRYPOINT ["/usr/local/bin/docker-entrypoint-custom.sh"]
CMD ["node", "current/index.js"]
