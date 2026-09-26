# Stage 1: Build the static React application
FROM node:20-alpine AS builder

WORKDIR /app

# Copy dependency manifests first to maximize layer caching
COPY package.json ./

# Install all dependencies (react-scripts is a devDependency needed for build)
# --legacy-peer-deps avoids strict peer resolution failures with older React 15 packages
RUN npm install --legacy-peer-deps

# Copy the full source tree
COPY . .

# Produce production static assets in /app/build
RUN npm run build

# Stage 2: Serve the static bundle with nginx
FROM nginx:alpine

# SPA fallback routing for client-side navigation
RUN mkdir -p /etc/nginx/conf.d /run/nginx && \
    printf 'server {\n\
    listen 80;\n\
    server_name _;\n\
    root /usr/share/nginx/html;\n\
    index index.html;\n\
\n\
    location / {\n\
        try_files $uri $uri/ /index.html;\n\
    }\n\
\n\
    location ~* \\.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {\n\
        expires 30d;\n\
        add_header Cache-Control "public, immutable";\n\
    }\n\
\n\
    gzip on;\n\
    gzip_types text/plain text/css application/javascript application/json image/svg+xml;\n\
}\n' > /etc/nginx/conf.d/default.conf

# Copy built static assets from the builder stage
COPY --from=builder /app/build /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]