#!/bin/bash
set -e

echo "🚀 Starting MinIO with Docker Compose..."
# Use 'docker compose' (modern plugin syntax) instead of 'docker-compose' (legacy)
# Works with OrbStack and Docker Desktop with Compose V2
docker compose up -d

echo "⏳ Waiting for MinIO to be ready..."
sleep 5

echo "📦 Creating bucket 'msvc-images'..."
docker run --rm --network host \
  -e AWS_ACCESS_KEY_ID=minioadmin \
  -e AWS_SECRET_ACCESS_KEY=minioadmin \
  amazon/aws-cli \
  --endpoint-url http://localhost:9000 \
  s3 mb s3://msvc-images 2>/dev/null || echo "Bucket already exists"

echo "✅ MinIO is ready!"
echo ""
echo "📊 MinIO Console UI: http://localhost:9001"
echo "   Username: minioadmin"
echo "   Password: minioadmin"
echo ""
echo "🔗 MinIO API Endpoint: http://localhost:9000"
echo "📦 Bucket: msvc-images"
echo ""
