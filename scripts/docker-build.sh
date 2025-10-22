#!/bin/bash

# Docker build script with best practices
# This script demonstrates proper Docker image building and tagging

set -e  # Exit on any error

# Configuration
IMAGE_NAME="taskmanager-api"
REGISTRY="your-registry.com"  # Replace with your registry
VERSION=${1:-"latest"}

echo "🐳 Building Docker image: ${IMAGE_NAME}:${VERSION}"

# Build the image with multiple tags
docker build \
  --tag "${IMAGE_NAME}:${VERSION}" \
  --tag "${IMAGE_NAME}:latest" \
  --tag "${REGISTRY}/${IMAGE_NAME}:${VERSION}" \
  --tag "${REGISTRY}/${IMAGE_NAME}:latest" \
  --build-arg BUILD_DATE="$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
  --build-arg VCS_REF="$(git rev-parse --short HEAD)" \
  --file Dockerfile \
  .

echo "✅ Build completed successfully!"

# Show image details
echo "📊 Image details:"
docker images "${IMAGE_NAME}" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"

# Optional: Run security scan (if you have tools like trivy installed)
if command -v trivy &> /dev/null; then
    echo "🔍 Running security scan..."
    trivy image "${IMAGE_NAME}:${VERSION}"
fi

echo "🚀 To run the image locally:"
echo "   docker run -p 3000:3000 ${IMAGE_NAME}:${VERSION}"
echo ""
echo "📤 To push to registry:"
echo "   docker push ${REGISTRY}/${IMAGE_NAME}:${VERSION}"
