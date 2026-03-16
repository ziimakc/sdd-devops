#!/usr/bin/env bash
# @req SCI-CI-001
# @req SCI-CI-002
# Validate Kubernetes manifests locally - runs same checks as CI pipeline

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🔍 Validating Kubernetes manifests..."
echo "Project root: $PROJECT_ROOT"
echo ""

cd "$PROJECT_ROOT"

# Check prerequisites
if ! command -v helm &> /dev/null; then
    echo "❌ helm not found. Install from: https://helm.sh/docs/intro/install/"
    exit 1
fi

if ! command -v kubeconform &> /dev/null; then
    echo "❌ kubeconform not found. Install from: https://github.com/yannh/kubeconform"
    echo "   Quick install: curl -L https://github.com/yannh/kubeconform/releases/download/v0.6.4/kubeconform-linux-amd64.tar.gz | tar xz && sudo mv kubeconform /usr/local/bin/"
    exit 1
fi

# Add Bitnami repository
echo "📦 Adding Bitnami Helm repository..."
helm repo add bitnami https://charts.bitnami.com/bitnami 2>/dev/null || true
echo ""

# Build dependencies
echo "📦 Building Helm dependencies..."
helm dependency build charts/sdd-navigator
echo ""

# Render templates
echo "📝 Rendering Helm templates..."
TEMP_DIR=$(mktemp -d)
helm template sdd-navigator charts/sdd-navigator \
    --set database.password=test-password \
    --output-dir "$TEMP_DIR"
echo ""

# Validate manifests
echo "✅ Validating manifests with kubeconform..."
kubeconform \
    -strict \
    -ignore-missing-schemas \
    -summary \
    "$TEMP_DIR"

# Cleanup
rm -rf "$TEMP_DIR"

echo ""
echo "🎉 All manifests are valid!"