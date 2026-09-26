# Stage 1: Build the React/Vite application
FROM node:24-alpine AS builder

WORKDIR /app

# Copy dependency files
COPY package.json package-lock.json ./

# Install exact dependencies
RUN npm ci

# Copy source code
COPY . .

# Build production files
RUN npm run build


# Stage 2: Production runtime
FROM nginx:alpine AS runtime

# Remove default Nginx website
RUN rm -rf /usr/share/nginx/html/*

# Copy only production files from build stage
COPY --from=builder /app/dist /usr/share/nginx/html

# Configure Nginx
RUN printf '%s\n' \
    'server {' \
    '    listen 8080;' \
    '    listen [::]:8080;' \
    '    server_name _;' \
    '    root /usr/share/nginx/html;' \
    '    index index.html;' \
    '' \
    '    location / {' \
    '        try_files $uri $uri/ /index.html;' \
    '    }' \
    '}' \
    > /etc/nginx/conf.d/default.conf

# Configure Nginx for non-root execution
RUN sed -i '/^[[:space:]]*user[[:space:]]/d' /etc/nginx/nginx.conf && \
    sed -i '/^[[:space:]]*pid[[:space:]]/d' /etc/nginx/nginx.conf && \
    sed -i '1i pid /tmp/nginx.pid;' /etc/nginx/nginx.conf

# Create non-root user
RUN addgroup -S appgroup && \
    adduser -S appuser -G appgroup

# Give appuser access to required Nginx directories
RUN chown -R appuser:appgroup \
    /usr/share/nginx/html \
    /var/cache/nginx \
    /var/log/nginx \
    /etc/nginx/conf.d \
    /tmp

# Run as non-root
USER appuser

# Application port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s \
    --timeout=5s \
    --start-period=10s \
    --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://127.0.0.1:8080/ || exit 1

# Start Nginx
ENTRYPOINT ["nginx", "-g", "daemon off;"]