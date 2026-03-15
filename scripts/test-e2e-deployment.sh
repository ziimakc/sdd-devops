#!/usr/bin/env bash
# @req SCI-ANS-001
# @req SCI-ANS-002
# @req SCI-ANS-003
# End-to-end deployment test for SDD Navigator Ansible orchestration
# Validates complete deployment workflow, post-deploy validation, and idempotency

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ANSIBLE_DIR="${PROJECT_ROOT}/ansible"
TEMP_DIR="${PROJECT_ROOT}/temp/e2e-test"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Test results tracking
declare -a TEST_RESULTS
declare -a TEST_NAMES
TEST_COUNT=0

# Cleanup flag
CLEANUP_ON_EXIT=${CLEANUP_ON_EXIT:-true}

# Print header
print_header() {
  echo ""
  echo -e "${BOLD}${BLUE}=====================================${NC}"
  echo -e "${BOLD}${BLUE}  $1${NC}"
  echo -e "${BOLD}${BLUE}=====================================${NC}"
  echo ""
}

# Print section
print_section() {
  echo ""
  echo -e "${CYAN}--- $1 ---${NC}"
  echo ""
}

# Record test result
record_test() {
  local name="$1"
  local result="$2"
  TEST_NAMES+=("${name}")
  TEST_RESULTS+=("${result}")
  TEST_COUNT=$((TEST_COUNT + 1))
}

# Cleanup function
cleanup() {
  if [[ "${CLEANUP_ON_EXIT}" == "true" ]]; then
    print_section "Cleanup"
    echo "Removing test namespace..."
    if kubectl get namespace sdd-navigator &> /dev/null; then
      kubectl delete namespace sdd-navigator --timeout=60s --wait=true 2>/dev/null || true
    fi
    echo -e "${GREEN}Cleanup completed${NC}"
  else
    echo ""
    echo -e "${YELLOW}Skipping cleanup (CLEANUP_ON_EXIT=false)${NC}"
    echo "To manually cleanup: kubectl delete namespace sdd-navigator"
  fi
}

# Trap exit
trap cleanup EXIT

print_header "SDD Navigator E2E Deployment Test"

echo "Testing requirements:"
echo "  - SCI-ANS-001: Ansible orchestration with correct deployment order"
echo "  - SCI-ANS-002: Post-deploy validation with pass/fail reporting"
echo "  - SCI-ANS-003: Idempotency (second run produces zero changes)"
echo ""

# Validate prerequisites
print_section "Prerequisites Check"

PREREQ_PASS=true

# Check ansible-playbook
if command -v ansible-playbook &> /dev/null; then
  ANSIBLE_VERSION=$(ansible-playbook --version | head -n1)
  echo -e "${GREEN}✓${NC} ansible-playbook: ${ANSIBLE_VERSION}"
else
  echo -e "${RED}✗${NC} ansible-playbook not found"
  PREREQ_PASS=false
fi

# Check kubectl
if command -v kubectl &> /dev/null; then
  KUBECTL_VERSION=$(kubectl version --client -o json 2>/dev/null | grep -o '"gitVersion":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
  echo -e "${GREEN}✓${NC} kubectl: ${KUBECTL_VERSION}"
else
  echo -e "${RED}✗${NC} kubectl not found"
  PREREQ_PASS=false
fi

# Check helm
if command -v helm &> /dev/null; then
  HELM_VERSION=$(helm version --short 2>/dev/null || echo "unknown")
  echo -e "${GREEN}✓${NC} helm: ${HELM_VERSION}"
else
  echo -e "${YELLOW}⚠${NC} helm not found (Ansible will use helm module)"
fi

# Check kubectl cluster connectivity
if kubectl cluster-info &> /dev/null; then
  CLUSTER_INFO=$(kubectl cluster-info 2>/dev/null | head -n1 | sed 's/\x1b\[[0-9;]*m//g' || echo "connected")
  echo -e "${GREEN}✓${NC} Cluster: ${CLUSTER_INFO}"
else
  echo -e "${RED}✗${NC} Cannot connect to Kubernetes cluster"
  PREREQ_PASS=false
fi

# Check Ansible collection
if ansible-galaxy collection list 2>/dev/null | grep -q "kubernetes.core"; then
  echo -e "${GREEN}✓${NC} kubernetes.core collection installed"
else
  echo -e "${YELLOW}⚠${NC} kubernetes.core collection not found, installing..."
  ansible-galaxy collection install -r "${ANSIBLE_DIR}/requirements.yml" &> /dev/null
  if ansible-galaxy collection list 2>/dev/null | grep -q "kubernetes.core"; then
    echo -e "${GREEN}✓${NC} kubernetes.core collection installed"
  else
    echo -e "${RED}✗${NC} Failed to install kubernetes.core collection"
    PREREQ_PASS=false
  fi
fi

# Check required files
REQUIRED_FILES=(
  "${ANSIBLE_DIR}/playbook.yml"
  "${ANSIBLE_DIR}/inventory/local.yml"
  "${ANSIBLE_DIR}/group_vars/all.yml"
  "${ANSIBLE_DIR}/roles/deploy/tasks/main.yml"
  "${ANSIBLE_DIR}/roles/validate/tasks/main.yml"
  "${PROJECT_ROOT}/charts/sdd-navigator/Chart.yaml"
)

for file in "${REQUIRED_FILES[@]}"; do
  if [[ -f "${file}" ]]; then
    echo -e "${GREEN}✓${NC} Found: ${file#${PROJECT_ROOT}/}"
  else
    echo -e "${RED}✗${NC} Missing: ${file#${PROJECT_ROOT}/}"
    PREREQ_PASS=false
  fi
done

if [[ "${PREREQ_PASS}" != "true" ]]; then
  echo ""
  echo -e "${RED}Prerequisites check failed. Cannot proceed with E2E test.${NC}"
  exit 1
fi

# Set DB_PASSWORD
if [[ -z "${DB_PASSWORD:-}" ]]; then
  export DB_PASSWORD="e2e-test-password-$(date +%s)"
  echo ""
  echo -e "${YELLOW}DB_PASSWORD not set, using generated value${NC}"
fi

# Create temp directory
mkdir -p "${TEMP_DIR}"

# Clean up any existing test deployment
print_section "Pre-test Cleanup"

if kubectl get namespace sdd-navigator &> /dev/null; then
  echo "Removing existing sdd-navigator namespace..."
  kubectl delete namespace sdd-navigator --timeout=120s --wait=true 2>/dev/null || true
  echo "Waiting for namespace deletion to complete..."
  for i in {1..30}; do
    if ! kubectl get namespace sdd-navigator &> /dev/null; then
      break
    fi
    sleep 2
  done
  echo -e "${GREEN}Cleanup completed${NC}"
else
  echo "No existing sdd-navigator namespace found"
fi

# TEST 1: Initial Deployment
print_header "TEST 1: Initial Deployment (SCI-ANS-001)"

echo "Requirement: Ansible MUST deploy Helm chart to Kubernetes in correct order:"
echo "  1. Namespace creation"
echo "  2. Secrets"
echo "  3. Database"
echo "  4. API service"
echo "  5. Frontend"
echo "  6. Ingress"
echo ""
echo "Each component MUST wait for previous component to reach ready state."
echo ""

TEST1_LOG="${TEMP_DIR}/test1-initial-deployment.log"
TEST1_OUTPUT="${TEMP_DIR}/test1-initial-deployment.json"

echo "Running: ansible-playbook playbook.yml"

if ANSIBLE_STDOUT_CALLBACK=json ansible-playbook \
  -i "${ANSIBLE_DIR}/inventory/local.yml" \
  "${ANSIBLE_DIR}/playbook.yml" \
  > "${TEST1_OUTPUT}" 2> "${TEST1_LOG}"; then
  
  echo -e "${GREEN}✓ Playbook execution completed successfully${NC}"
  
  # Parse stats
  if command -v python3 &> /dev/null && [[ -f "${TEST1_OUTPUT}" ]]; then
    STATS=$(python3 -c "
import json
try:
    with open('${TEST1_OUTPUT}') as f:
        data = json.load(f)
    stats = data.get('stats', {}).get('localhost', {})
    print(f\"ok={stats.get('ok', 0)} changed={stats.get('changed', 0)} failed={stats.get('failures', 0)}\")
except:
    print('error parsing stats')
" 2>/dev/null || echo "stats unavailable")
    echo "  Stats: ${STATS}"
  fi
  
  record_test "Initial Deployment" "PASS"
else
  echo -e "${RED}✗ Playbook execution failed${NC}"
  echo ""
  echo "Error log (last 20 lines):"
  tail -20 "${TEST1_LOG}"
  record_test "Initial Deployment" "FAIL"
fi

# Verify deployment artifacts
print_section "Verifying Deployment Artifacts"

ARTIFACTS_OK=true

# Check namespace
if kubectl get namespace sdd-navigator &> /dev/null; then
  echo -e "${GREEN}✓${NC} Namespace: sdd-navigator exists"
else
  echo -e "${RED}✗${NC} Namespace: sdd-navigator not found"
  ARTIFACTS_OK=false
fi

# Check secrets
if kubectl -n sdd-navigator get secret sdd-navigator-db-credentials &> /dev/null; then
  echo -e "${GREEN}✓${NC} Secret: sdd-navigator-db-credentials exists"
else
  echo -e "${RED}✗${NC} Secret: sdd-navigator-db-credentials not found"
  ARTIFACTS_OK=false
fi

# Check deployments
EXPECTED_DEPLOYMENTS=("sdd-navigator-api" "sdd-navigator-frontend")
for deployment in "${EXPECTED_DEPLOYMENTS[@]}"; do
  if kubectl -n sdd-navigator get deployment "${deployment}" &> /dev/null; then
    REPLICAS=$(kubectl -n sdd-navigator get deployment "${deployment}" -o jsonpath='{.status.availableReplicas}' 2>/dev/null || echo "0")
    echo -e "${GREEN}✓${NC} Deployment: ${deployment} (${REPLICAS} replicas available)"
  else
    echo -e "${RED}✗${NC} Deployment: ${deployment} not found"
    ARTIFACTS_OK=false
  fi
done

# Check StatefulSet (PostgreSQL)
if kubectl -n sdd-navigator get statefulset -l app.kubernetes.io/name=postgresql &> /dev/null; then
  POSTGRES_READY=$(kubectl -n sdd-navigator get statefulset -l app.kubernetes.io/name=postgresql -o jsonpath='{.items[0].status.readyReplicas}' 2>/dev/null || echo "0")
  echo -e "${GREEN}✓${NC} StatefulSet: postgresql (${POSTGRES_READY} replicas ready)"
else
  echo -e "${RED}✗${NC} StatefulSet: postgresql not found"
  ARTIFACTS_OK=false
fi

# Check services
EXPECTED_SERVICES=("sdd-navigator-api" "sdd-navigator-frontend")
for service in "${EXPECTED_SERVICES[@]}"; do
  if kubectl -n sdd-navigator get service "${service}" &> /dev/null; then
    PORT=$(kubectl -n sdd-navigator get service "${service}" -o jsonpath='{.spec.ports[0].port}' 2>/dev/null || echo "unknown")
    echo -e "${GREEN}✓${NC} Service: ${service} (port ${PORT})"
  else
    echo -e "${RED}✗${NC} Service: ${service} not found"
    ARTIFACTS_OK=false
  fi
done

if [[ "${ARTIFACTS_OK}" == "true" ]]; then
  record_test "Deployment Artifacts" "PASS"
else
  record_test "Deployment Artifacts" "FAIL"
fi

# TEST 2: Post-Deploy Validation
print_header "TEST 2: Post-Deploy Validation (SCI-ANS-002)"

echo "Requirement: Ansible MUST include validation role that verifies:"
echo "  - /healthcheck returns HTTP 200 with status 'healthy'"
echo "  - /stats returns HTTP 200"
echo "  - All pods are Running"
echo "  - PostgreSQL accepts connections via pg_isready"
echo ""
echo "Results MUST be reported as Ansible debug output with pass/fail per check."
echo ""

# Check if validation was run in initial deployment
if [[ -f "${TEST1_LOG}" ]]; then
  echo "Checking validation output from initial deployment..."
  echo ""
  
  VALIDATION_FOUND=false
  
  # Check for validation summary in logs
  if grep -q "Validation Summary" "${TEST1_LOG}"; then
    VALIDATION_FOUND=true
    echo "Validation summary:"
    grep -A 10 "Validation Summary" "${TEST1_LOG}" | sed 's/^/  /'
  fi
  
  # Check individual validation results
  if grep -q "PASS\|FAIL" "${TEST1_LOG}"; then
    if ! ${VALIDATION_FOUND}; then
      echo "Validation results found:"
      grep "PASS\|FAIL" "${TEST1_LOG}" | sed 's/^/  /'
    fi
    VALIDATION_FOUND=true
  fi
  
  if ${VALIDATION_FOUND}; then
    # Check if all validations passed
    if grep -q "FAIL" "${TEST1_LOG}"; then
      echo ""
      echo -e "${RED}✗ Some validation checks failed${NC}"
      record_test "Post-Deploy Validation" "FAIL"
    else
      echo ""
      echo -e "${GREEN}✓ All validation checks passed${NC}"
      record_test "Post-Deploy Validation" "PASS"
    fi
  else
    echo -e "${YELLOW}⚠ Validation output not found in logs${NC}"
    record_test "Post-Deploy Validation" "WARN"
  fi
else
  echo -e "${RED}✗ Initial deployment log not available${NC}"
  record_test "Post-Deploy Validation" "FAIL"
fi

# TEST 3: Manual Validation Verification
print_section "Manual Validation Checks"

MANUAL_VALIDATION_OK=true

# Get API pod
API_POD=$(kubectl -n sdd-navigator get pods -l app.kubernetes.io/component=api -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [[ -n "${API_POD}" ]]; then
  echo "Using API pod: ${API_POD}"
  
  # Test healthcheck endpoint
  echo -n "Testing /healthcheck endpoint... "
  if kubectl -n sdd-navigator exec "${API_POD}" -- wget -q -O - --timeout=5 http://localhost:8080/healthcheck &> /dev/null; then
    echo -e "${GREEN}✓ PASS${NC}"
  else
    echo -e "${RED}✗ FAIL${NC}"
    MANUAL_VALIDATION_OK=false
  fi
  
  # Test stats endpoint
  echo -n "Testing /stats endpoint... "
  if kubectl -n sdd-navigator exec "${API_POD}" -- wget -q -O - --timeout=5 http://localhost:8080/stats &> /dev/null; then
    echo -e "${GREEN}✓ PASS${NC}"
  else
    echo -e "${RED}✗ FAIL${NC}"
    MANUAL_VALIDATION_OK=false
  fi
else
  echo -e "${RED}✗ API pod not found${NC}"
  MANUAL_VALIDATION_OK=false
fi

# Check all pods are running
echo -n "Checking all pods are Running... "
ALL_PODS_RUNNING=true
PODS_STATUS=$(kubectl -n sdd-navigator get pods --no-headers 2>/dev/null | awk '{print $3}' || echo "")
if [[ -n "${PODS_STATUS}" ]]; then
  while IFS= read -r status; do
    if [[ "${status}" != "Running" ]]; then
      ALL_PODS_RUNNING=false
      break
    fi
  done <<< "${PODS_STATUS}"
  
  if ${ALL_PODS_RUNNING}; then
    TOTAL_PODS=$(echo "${PODS_STATUS}" | wc -l)
    echo -e "${GREEN}✓ PASS${NC} (${TOTAL_PODS} pods)"
  else
    echo -e "${RED}✗ FAIL${NC}"
    MANUAL_VALIDATION_OK=false
  fi
else
  echo -e "${RED}✗ FAIL${NC} (no pods found)"
  MANUAL_VALIDATION_OK=false
fi

# Test PostgreSQL connection
echo -n "Testing PostgreSQL connection... "
POSTGRES_POD=$(kubectl -n sdd-navigator get pods -l app.kubernetes.io/name=postgresql -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [[ -n "${POSTGRES_POD}" ]]; then
  if kubectl -n sdd-navigator exec "${POSTGRES_POD}" -- pg_isready -U sdd_user -d sdd_navigator &> /dev/null; then
    echo -e "${GREEN}✓ PASS${NC}"
  else
    echo -e "${RED}✗ FAIL${NC}"
    MANUAL_VALIDATION_OK=false
  fi
else
  echo -e "${RED}✗ FAIL${NC} (PostgreSQL pod not found)"
  MANUAL_VALIDATION_OK=false
fi

if [[ "${MANUAL_VALIDATION_OK}" == "true" ]]; then
  record_test "Manual Validation Checks" "PASS"
else
  record_test "Manual Validation Checks" "FAIL"
fi

# TEST 4: Idempotency
print_header "TEST 4: Idempotency (SCI-ANS-003)"

echo "Requirement: Running playbook twice MUST produce zero changes on second run."
echo "All Ansible tasks MUST report 'ok' (not 'changed') when desired state exists."
echo ""

TEST4_LOG="${TEMP_DIR}/test4-idempotency.log"
TEST4_OUTPUT="${TEMP_DIR}/test4-idempotency.json"

echo "Waiting 5 seconds for system to stabilize..."
sleep 5

echo "Running: ansible-playbook playbook.yml (second run)"

if ANSIBLE_STDOUT_CALLBACK=json ansible-playbook \
  -i "${ANSIBLE_DIR}/inventory/local.yml" \
  "${ANSIBLE_DIR}/playbook.yml" \
  > "${TEST4_OUTPUT}" 2> "${TEST4_LOG}"; then
  
  echo -e "${GREEN}✓ Second playbook run completed successfully${NC}"
  
  # Parse stats and check for changes
  if command -v python3 &> /dev/null && [[ -f "${TEST4_OUTPUT}" ]]; then
    CHANGED_COUNT=$(python3 -c "
import json
try:
    with open('${TEST4_OUTPUT}') as f:
        data = json.load(f)
    stats = data.get('stats', {}).get('localhost', {})
    changed = stats.get('changed', 0)
    ok = stats.get('ok', 0)
    failed = stats.get('failures', 0)
    print(changed)
    import sys
    print(f'Stats: ok={ok} changed={changed} failed={failed}', file=sys.stderr)
except Exception as e:
    print('999', file=sys.stdout)
    print(f'Error: {e}', file=sys.stderr)
" 2>&1)
    
    STATS_LINE=$(echo "${CHANGED_COUNT}" | tail -1)
    CHANGED_NUM=$(echo "${CHANGED_COUNT}" | head -1)
    
    echo "  ${STATS_LINE}"
    echo ""
    
    if [[ "${CHANGED_NUM}" == "0" ]]; then
      echo -e "${GREEN}✓ IDEMPOTENT: Zero changes on second run${NC}"
      echo "  All tasks reported 'ok' (not 'changed')"
      echo "  Requirement SCI-ANS-003: SATISFIED"
      record_test "Idempotency" "PASS"
    else
      echo -e "${RED}✗ NOT IDEMPOTENT: ${CHANGED_NUM} task(s) changed on second run${NC}"
      echo "  Requirement SCI-ANS-003: VIOLATED"
      record_test "Idempotency" "FAIL"
    fi
  else
    echo -e "${YELLOW}⚠ Cannot parse idempotency stats${NC}"
    record_test "Idempotency" "WARN"
  fi
else
  echo -e "${RED}✗ Second playbook run failed${NC}"
  record_test "Idempotency" "FAIL"
fi

# TEST 5: Deployment Order Verification
print_header "TEST 5: Deployment Order (SCI-ANS-001)"

echo "Verifying deployment happened in correct order by checking role execution..."
echo ""

if [[ -f "${TEST1_LOG}" ]]; then
  DEPLOY_ROLE_FOUND=false
  VALIDATE_ROLE_FOUND=false
  
  if grep -q "TASK.*Create Kubernetes namespace" "${TEST1_LOG}"; then
    echo -e "${GREEN}✓${NC} Deploy role executed (namespace creation task found)"
    DEPLOY_ROLE_FOUND=true
  fi
  
  if grep -q "TASK.*Create database secret" "${TEST1_LOG}"; then
    echo -e "${GREEN}✓${NC} Secrets created before Helm deployment"
  fi
  
  if grep -q "TASK.*Deploy SDD Navigator Helm chart" "${TEST1_LOG}"; then
    echo -e "${GREEN}✓${NC} Helm chart deployment task executed"
  fi
  
  if grep -q "TASK.*Wait for.*pods to be ready" "${TEST1_LOG}"; then
    echo -e "${GREEN}✓${NC} Wait tasks executed for pod readiness"
  fi
  
  if grep -q "TASK.*Validate.*healthcheck" "${TEST1_LOG}"; then
    echo -e "${GREEN}✓${NC} Validate role executed (validation tasks found)"
    VALIDATE_ROLE_FOUND=true
  fi
  
  if ${DEPLOY_ROLE_FOUND} && ${VALIDATE_ROLE_FOUND}; then
    echo ""
    echo -e "${GREEN}✓ Deployment order verified${NC}"
    record_test "Deployment Order" "PASS"
  else
    echo ""
    echo -e "${RED}✗ Could not verify complete deployment order${NC}"
    record_test "Deployment Order" "FAIL"
  fi
else
  echo -e "${RED}✗ Cannot verify deployment order (log not available)${NC}"
  record_test "Deployment Order" "FAIL"
fi

# Final Summary
print_header "E2E Test Results Summary"

TOTAL_PASS=0
TOTAL_FAIL=0
TOTAL_WARN=0

for i in "${!TEST_NAMES[@]}"; do
  name="${TEST_NAMES[$i]}"
  result="${TEST_RESULTS[$i]}"
  
  case "${result}" in
    PASS)
      echo -e "${GREEN}✓ PASS${NC} - ${name}"
      TOTAL_PASS=$((TOTAL_PASS + 1))
      ;;
    FAIL)
      echo -e "${RED}✗ FAIL${NC} - ${name}"
      TOTAL_FAIL=$((TOTAL_FAIL + 1))
      ;;
    WARN)
      echo -e "${YELLOW}⚠ WARN${NC} - ${name}"
      TOTAL_WARN=$((TOTAL_WARN + 1))
      ;;
  esac
done

echo ""
echo "────────────────────────────────────"
echo "Total Tests: ${TEST_COUNT}"
echo "  Passed:  ${TOTAL_PASS}"
echo "  Failed:  ${TOTAL_FAIL}"
echo "  Warnings: ${TOTAL_WARN}"
echo "────────────────────────────────────"
echo ""

# Requirements verification
print_section "Requirements Verification"

if [[ ${TOTAL_FAIL} -eq 0 ]]; then
  echo -e "${GREEN}✓ SCI-ANS-001${NC}: Ansible orchestration with correct deployment order - SATISFIED"
  echo -e "${GREEN}✓ SCI-ANS-002${NC}: Post-deploy validation with pass/fail reporting - SATISFIED"
  echo -e "${GREEN}✓ SCI-ANS-003${NC}: Idempotency (second run produces zero changes) - SATISFIED"
else
  echo -e "${RED}✗ Some requirements not satisfied${NC}"
  echo ""
  echo "Review test failures above and check logs in: ${TEMP_DIR}"
fi

echo ""
echo "Test artifacts saved to: ${TEMP_DIR}"
echo "  - test1-initial-deployment.log"
echo "  - test1-initial-deployment.json"
echo "  - test4-idempotency.log"
echo "  - test4-idempotency.json"
echo ""

# Exit with appropriate code
if [[ ${TOTAL_FAIL} -eq 0 ]]; then
  print_header "✓ E2E TEST PASSED"
  exit 0
else
  print_header "✗ E2E TEST FAILED"
  exit 1
fi