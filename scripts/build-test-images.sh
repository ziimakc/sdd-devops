#!/usr/bin/env bash
# @req SCI-ANS-001
# Build minimal dummy images for E2E infrastructure testing
# These are NOT the real API/frontend - just placeholders to test Kubernetes deployment

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TEST_IMAGES_DIR="${PROJECT_ROOT}/test-images"

echo "Building dummy test images for SDD Navigator infrastructure tests..."
echo ""

# Build dummy API image
echo "Building dummy API image (sdd-coverage-api:0.1.0)..."
docker build \
  -f "${TEST_IMAGES_DIR}/api.Dockerfile" \
  -t sdd-coverage-api:0.1.0 \
  "${TEST_IMAGES_DIR}"

if [ $? -eq 0 ]; then
  echo "✓ API image built successfully"
else
  echo "✗ Failed to build API image"
  exit 1
fi

echo ""

# Build dummy frontend image
echo "Building dummy frontend image (sdd-navigator-frontend:0.1.0)..."
docker build \
  -f "${TEST_IMAGES_DIR}/frontend.Dockerfile" \
  -t sdd-navigator-frontend:0.1.0 \
  "${TEST_IMAGES_DIR}"

if [ $? -eq 0 ]; then
  echo "✓ Frontend image built successfully"
else
  echo "✗ Failed to build frontend image"
  exit 1
fi

echo ""

# Build mock PostgreSQL image
echo "Building mock PostgreSQL image (bitnami/postgresql:16.2.0-debian-12-r13)..."
docker build \
  -f "${TEST_IMAGES_DIR}/postgresql.Dockerfile" \
  -t bitnami/postgresql:16.2.0-debian-12-r13 \
  "${TEST_IMAGES_DIR}"

if [ $? -eq 0 ]; then
  echo "✓ PostgreSQL image built successfully"
else
  echo "✗ Failed to build PostgreSQL image"
  exit 1
fi

echo ""
echo "All test images built successfully!"
echo ""

# Check if running in kind cluster and load images
CURRENT_CONTEXT=$(kubectl config current-context 2>/dev/null || echo "")
if [[ "${CURRENT_CONTEXT}" == kind-* ]]; then
  CLUSTER_NAME="${CURRENT_CONTEXT#kind-}"
  echo "Detected kind cluster: ${CLUSTER_NAME}"
  echo "Loading images into kind cluster..."
  
  kind load docker-image sdd-coverage-api:0.1.0 --name "${CLUSTER_NAME}" 2>&1
  if [ $? -eq 0 ]; then
    echo "✓ API image loaded into kind cluster"
  else
    echo "✗ Failed to load API image into kind cluster"
    exit 1
  fi
  
  kind load docker-image sdd-navigator-frontend:0.1.0 --name "${CLUSTER_NAME}" 2>&1
  if [ $? -eq 0 ]; then
    echo "✓ Frontend image loaded into kind cluster"
  else
    echo "✗ Failed to load frontend image into kind cluster"
    exit 1
  fi
  
  kind load docker-image bitnami/postgresql:16.2.0-debian-12-r13 --name "${CLUSTER_NAME}" 2>&1
  if [ $? -eq 0 ]; then
    echo "✓ PostgreSQL image loaded into kind cluster"
  else
    echo "✗ Failed to load PostgreSQL image into kind cluster"
    exit 1
  fi
  
  echo ""
fi

echo "Images created:"
docker images | grep -E "sdd-coverage-api|sdd-navigator-frontend" | grep "0.1.0"
docker images | grep "bitnami/postgresql" | grep "16.2.0-debian-12-r13"
echo ""
echo "Note: These are minimal dummy images for testing infrastructure only."
echo "They contain basic nginx/Python servers with mock endpoints, not actual applications."