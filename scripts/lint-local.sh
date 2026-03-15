```#!/usr/bin/env bash
# @req SCI-CI-001
# @req SCI-CI-002
# Local linting script - runs same checks as CI pipeline

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🔍 Running local linting checks..."
echo "Project root: $PROJECT_ROOT"
echo ""

cd "$PROJECT_ROOT"

# YAML Lint
echo "📝 [1/5] Running yamllint..."
if ! command -v yamllint &> /dev/null; then
    echo "❌ yamllint not found. Install with: pip install yamllint"
    exit 1
fi

yamllint -d '{extends: default, rules: {line-length: {max: 120, level: warning}, indentation: {spaces: 2}, comments: {min-spaces-from-content: 1}}}' .
echo "✅ yamllint passed"
echo ""

# Ansible Lint
echo "📝 [2/5] Running ansible-lint..."
if ! command -v ansible-lint &> /dev/null; then
    echo "❌ ansible-lint not found. Install with: pip install ansible-lint ansible-core"
    exit 1
fi

ansible-lint ansible/playbook.yml
echo "✅ ansible-lint passed"
echo ""

# Helm Lint
echo "📝 [3/5] Running helm lint..."
if ! command -v helm &> /dev/null; then
    echo "❌ helm not found. Install from: https://helm.sh/docs/intro/install/"
    exit 1
fi

helm lint charts/sdd-navigator
helm lint charts/sdd-navigator/charts/api
helm lint charts/sdd-navigator/charts/frontend
echo "✅ helm lint passed"
echo ""

# Validate Kubernetes Manifests
echo "📝 [4/5] Validating Kubernetes manifests..."
if ! command -v kubeconform &> /dev/null; then
    echo "⚠️  kubeconform not found. Skipping manifest validation."
    echo "    Install from: https://github.com/yannh/kubeconform"
else
    TEMP_DIR=$(mktemp -d)
    helm template sdd-navigator charts/sdd-navigator \
        --set database.password=test-password \
        --output-dir "$TEMP_DIR"
    
    kubeconform \
        -strict \
        -ignore-missing-schemas \
        -summary \
        "$TEMP_DIR"
    
    rm -rf "$TEMP_DIR"
    echo "✅ manifest validation passed"
fi
echo ""

# Traceability Check
echo "📝 [5/5] Checking traceability annotations..."
if [[ -x "$SCRIPT_DIR/check-traceability.sh" ]]; then
    "$SCRIPT_DIR/check-traceability.sh"
    echo "✅ traceability check passed"
else
    echo "⚠️  check-traceability.sh not found or not executable"
fi
echo ""

echo "🎉 All local linting checks passed!"
