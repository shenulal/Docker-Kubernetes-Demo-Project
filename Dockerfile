# Multi-stage Docker build for production optimization
# Stage 1: Build stage with all dependencies
FROM node:18-alpine AS builder

# Set working directory
WORKDIR /app

# Copy package files first (Docker layer caching optimization)
# This allows Docker to cache the npm install step if package.json hasn't changed
COPY package*.json ./

# Install ALL dependencies (including devDependencies for potential build steps)
RUN npm ci --only=production && npm cache clean --force

# Stage 2: Production stage with minimal footprint
FROM node:18-alpine AS production

# Create non-root user for security
# Running as root in containers is a security risk
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install only production dependencies
RUN npm ci --omit=dev && npm cache clean --force

# Copy application source code
COPY src/ ./src/

# Change ownership of the app directory to nodejs user
RUN chown -R nodejs:nodejs /app

# Switch to non-root user
USER nodejs

# Expose the port the app runs on
# This is documentation - doesn't actually publish the port
EXPOSE 3000

# Health check to ensure container is healthy
# Kubernetes can use this for health monitoring
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/api/health/live', (res) => { process.exit(res.statusCode === 200 ? 0 : 1) })" || exit 1

# Use exec form for proper signal handling
# This ensures SIGTERM signals are properly handled for graceful shutdown
CMD ["node", "src/server.js"]

# Labels for better container management and documentation
LABEL maintainer="Docker & Kubernetes Learning Project" \
      version="1.0.0" \
      description="Task Management API for learning Docker and Kubernetes" \
      org.opencontainers.image.source="https://github.com/your-repo/docker-kubernetes-poc"
