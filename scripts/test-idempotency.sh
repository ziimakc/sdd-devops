#!/usr/bin/env bash
# @req SCI-ANS-003
# Test Ansible playbook idempotency - second run MUST produce zero changes

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ANSIBLE_DIR="${PROJECT_ROOT}/ansible"
TEMP_DIR="${PROJECT_ROOT}/temp"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "===== SDD Navigator Idempotency Test ====="
echo ""
echo "Requirement: SCI-ANS-003 - Running playbook twice MUST produce zero changes on second run"
echo ""

# Validate prerequisites
if [[ ! -f "${ANSIBLE_DIR}/playbook.yml" ]]; then
  echo -e "${RED}ERROR: playbook.yml not found at ${ANSIBLE_DIR}/playbook.yml${NC}"
  exit 1
fi

if ! command -v ansible-playbook &> /dev/null; then
  echo -e "${RED}ERROR: ansible-playbook not found in PATH${NC}"
  exit 1
fi

if ! command -v kubectl &> /dev/null; then
  echo -e "${RED}ERROR: kubectl not found in PATH${NC}"
  exit 1
fi

# Check kubectl connectivity
if ! kubectl cluster-info &> /dev/null; then
  echo -e "${RED}ERROR: Cannot connect to Kubernetes cluster${NC}"
  echo "Ensure kubectl is configured and cluster is accessible"
  exit 1
fi

# Set DB_PASSWORD if not provided
if [[ -z "${DB_PASSWORD:-}" ]]; then
  echo -e "${YELLOW}WARNING: DB_PASSWORD not set, using default 'test-password-idempotency'${NC}"
  export DB_PASSWORD="test-password-idempotency"
fi

mkdir -p "${TEMP_DIR}"

# Function to run playbook
run_playbook() {
  local run_number="$1"
  local output_file="${TEMP_DIR}/idempotency-run${run_number}.log"
  local stats_file="${TEMP_DIR}/idempotency-run${run_number}-stats.json"
  
  echo -e "${BLUE}--- Run ${run_number}: Executing playbook ---${NC}"
  
  # Run with JSON stdout callback for parseable output
  ANSIBLE_STDOUT_CALLBACK=json ansible-playbook \
    -i "${ANSIBLE_DIR}/inventory/local.yml" \
    "${ANSIBLE_DIR}/playbook.yml" \
    > "${stats_file}" 2> "${output_file}"
  
  local exit_code=$?
  
  if [[ ${exit_code} -eq 0 ]]; then
    echo -e "${GREEN}Run ${run_number}: Completed successfully${NC}"
  else
    echo -e "${RED}Run ${run_number}: Failed with exit code ${exit_code}${NC}"
    echo "Error log:"
    cat "${output_file}"
    return ${exit_code}
  fi
  
  return 0
}

# Function to extract stats from Ansible JSON output
extract_stats() {
  local stats_file="$1"
  local stat_type="$2"
  
  if [[ -f "${stats_file}" ]]; then
    # Extract stats from JSON - total for all hosts
    python3 -c "
import json
import sys
try:
    with open('${stats_file}') as f:
        data = json.load(f)
    stats = data.get('stats', {})
    total = 0
    for host, host_stats in stats.items():
        total += host_stats.get('${stat_type}', 0)
    print(total)
except Exception as e:
    print('0', file=sys.stderr)
    print(f'Error: {e}', file=sys.stderr)
    sys.exit(0)
" 2>/dev/null || echo "0"
  else
    echo "0"
  fi
}

# Clean up any existing test namespace
echo ""
echo -e "${BLUE}Cleaning up any existing test deployment...${NC}"
if kubectl get namespace sdd-navigator &> /dev/null; then
  kubectl delete namespace sdd-navigator --timeout=60s || true
  echo "Waiting for namespace deletion to complete..."
  kubectl wait --for=delete namespace/sdd-navigator --timeout=120s || true
fi

# First run - Initial deployment
echo ""
echo "============================================"
echo "First Run: Initial Deployment"
echo "============================================"
echo ""

if ! run_playbook 1; then
  echo ""
  echo -e "${RED}FAIL: First playbook run failed${NC}"
  exit 1
fi

FIRST_RUN_STATS="${TEMP_DIR}/idempotency-run1-stats.json"
FIRST_RUN_CHANGED=$(extract_stats "${FIRST_RUN_STATS}" "changed")
FIRST_RUN_OK=$(extract_stats "${FIRST_RUN_STATS}" "ok")
FIRST_RUN_FAILED=$(extract_stats "${FIRST_RUN_STATS}" "failures")

echo ""
echo "First run statistics:"
echo "  Changed: ${FIRST_RUN_CHANGED}"
echo "  OK:      ${FIRST_RUN_OK}"
echo "  Failed:  ${FIRST_RUN_FAILED}"
echo ""

if [[ "${FIRST_RUN_FAILED}" -gt 0 ]]; then
  echo -e "${RED}FAIL: First run had failures${NC}"
  exit 1
fi

if [[ "${FIRST_RUN_CHANGED}" -eq 0 ]]; then
  echo -e "${YELLOW}WARNING: First run had no changes (unexpected for initial deployment)${NC}"
fi

# Wait for system to stabilize
echo "Waiting 10 seconds for system to stabilize..."
sleep 10

# Second run - Idempotency verification
echo ""
echo "============================================"
echo "Second Run: Idempotency Verification"
echo "============================================"
echo ""

if ! run_playbook 2; then
  echo ""
  echo -e "${RED}FAIL: Second playbook run failed${NC}"
  exit 1
fi

SECOND_RUN_STATS="${TEMP_DIR}/idempotency-run2-stats.json"
SECOND_RUN_CHANGED=$(extract_stats "${SECOND_RUN_STATS}" "changed")
SECOND_RUN_OK=$(extract_stats "${SECOND_RUN_STATS}" "ok")
SECOND_RUN_FAILED=$(extract_stats "${SECOND_RUN_STATS}" "failures")

echo ""
echo "Second run statistics:"
echo "  Changed: ${SECOND_RUN_CHANGED}"
echo "  OK:      ${SECOND_RUN_OK}"
echo "  Failed:  ${SECOND_RUN_FAILED}"
echo ""

# Verify idempotency
echo "============================================"
echo "Idempotency Test Results"
echo "============================================"
echo ""
echo "Run 1 (initial): ${FIRST_RUN_CHANGED} changed, ${FIRST_RUN_OK} ok, ${FIRST_RUN_FAILED} failed"
echo "Run 2 (verify):  ${SECOND_RUN_CHANGED} changed, ${SECOND_RUN_OK} ok, ${SECOND_RUN_FAILED} failed"
echo ""

# Check for failures
if [[ "${SECOND_RUN_FAILED}" -gt 0 ]]; then
  echo -e "${RED}✗ FAIL: Second run had ${SECOND_RUN_FAILED} failures${NC}"
  echo ""
  echo "See logs at: ${TEMP_DIR}/idempotency-run2.log"
  exit 1
fi

# Check idempotency (zero changes on second run)
if [[ "${SECOND_RUN_CHANGED}" -eq 0 ]]; then
  echo -e "${GREEN}✓ PASS: Playbook is IDEMPOTENT${NC}"
  echo ""
  echo "  All tasks reported 'ok' (not changed) on second run"
  echo "  Requirement SCI-ANS-003: SATISFIED"
  echo ""
  exit 0
else
  echo -e "${RED}✗ FAIL: Playbook is NOT idempotent${NC}"
  echo ""
  echo "  ${SECOND_RUN_CHANGED} task(s) reported 'changed' on second run"
  echo "  Requirement SCI-ANS-003: VIOLATED"
  echo ""
  echo "Tasks that changed on second run (see ${TEMP_DIR}/idempotency-run2.log):"
  if [[ -f "${TEMP_DIR}/idempotency-run2.log" ]]; then
    grep -i "changed:" "${TEMP_DIR}/idempotency-run2.log" | head -10 || true
  fi
  echo ""
  exit 1
fi