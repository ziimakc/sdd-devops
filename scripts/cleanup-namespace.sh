#!/usr/bin/env bash
# @req SCI-ANS-001
# Aggressive namespace cleanup script to prevent hanging deletions
# Handles stuck PVCs, finalizers, and terminating namespaces

set -euo pipefail

NAMESPACE="${1:-sdd-navigator}"
TIMEOUT_SECONDS="${2:-30}"

echo "Cleaning up namespace: ${NAMESPACE}"

# Check if namespace exists
if ! kubectl get namespace "${NAMESPACE}" &> /dev/null; then
  echo "Namespace ${NAMESPACE} does not exist. Nothing to clean up."
  exit 0
fi

# Start async deletion
echo "Starting namespace deletion..."
kubectl delete namespace "${NAMESPACE}" --wait=false 2>/dev/null || true

# Wait a moment for initial cleanup
sleep 2

# Check if still present
if ! kubectl get namespace "${NAMESPACE}" &> /dev/null 2>&1; then
  echo "Namespace deleted successfully."
  exit 0
fi

echo "Namespace still present, removing finalizers from resources..."

# Remove finalizers from all PVCs
kubectl get pvc -n "${NAMESPACE}" -o name 2>/dev/null | while read -r pvc; do
  kubectl patch "${pvc}" -n "${NAMESPACE}" -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
done

# Remove finalizers from all pods
kubectl get pods -n "${NAMESPACE}" -o name 2>/dev/null | while read -r pod; do
  kubectl patch "${pod}" -n "${NAMESPACE}" -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
done

# Remove finalizers from namespace itself
kubectl patch namespace "${NAMESPACE}" -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true

# Use API to force finalize if still stuck
sleep 1
if kubectl get namespace "${NAMESPACE}" &> /dev/null 2>&1; then
  echo "Force finalizing namespace via API..."
  kubectl get namespace "${NAMESPACE}" -o json 2>/dev/null | \
    jq '.spec.finalizers = []' 2>/dev/null | \
    kubectl replace --raw "/api/v1/namespaces/${NAMESPACE}/finalize" -f - 2>/dev/null || true
fi

# Wait with timeout for final deletion
echo "Waiting for namespace deletion (timeout: ${TIMEOUT_SECONDS}s)..."
for i in $(seq 1 "${TIMEOUT_SECONDS}"); do
  if ! kubectl get namespace "${NAMESPACE}" &> /dev/null 2>&1; then
    echo "Namespace ${NAMESPACE} deleted successfully."
    exit 0
  fi
  sleep 1
done

# If we get here, namespace is still stuck
echo "WARNING: Namespace ${NAMESPACE} still exists after ${TIMEOUT_SECONDS}s"
echo "Status:"
kubectl get namespace "${NAMESPACE}" 2>&1 || true
echo ""
echo "You may need to manually intervene or restart the cluster."
exit 1