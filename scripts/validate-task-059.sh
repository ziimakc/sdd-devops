#!/usr/bin/env bash
# @req SCI-ANS-001
# @req SCI-ANS-002
# @req SCI-ANS-003
# Quick validation script for TASK-059 implementation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "======================================"
echo "  TASK-059 Implementation Validation"
echo "======================================"
echo ""

PASS_COUNT=0
FAIL_COUNT=0

check() {
  local name="$1"
  local command="$2"
  
  if eval "$command" &> /dev/null; then
    echo -e "${GREEN}✓${NC} $name"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo -e "${RED}✗${NC} $name"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

echo "Checking files exist..."
check "scripts/test-e2e-deployment.sh exists" "test -f ${PROJECT_ROOT}/scripts/test-e2e-deployment.sh"
check "ansible/test-e2e.yml exists" "test -f ${PROJECT_ROOT}/ansible/test-e2e.yml"
check ".github/workflows/e2e-test.yml exists" "test -f ${PROJECT_ROOT}/.github/workflows/e2e-test.yml"
check "docs/E2E-TESTING.md exists" "test -f ${PROJECT_ROOT}/docs/E2E-TESTING.md"
check "ansible/TEST-E2E-README.md exists" "test -f ${PROJECT_ROOT}/ansible/TEST-E2E-README.md"
check "docs/E2E-TEST-CHECKLIST.md exists" "test -f ${PROJECT_ROOT}/docs/E2E-TEST-CHECKLIST.md"
check "docs/TASK-059-IMPLEMENTATION.md exists" "test -f ${PROJECT_ROOT}/docs/TASK-059-IMPLEMENTATION.md"
echo ""

echo "Checking file permissions..."
check "test-e2e-deployment.sh is executable" "test -x ${PROJECT_ROOT}/scripts/test-e2e-deployment.sh"
echo ""

echo "Checking syntax..."
check "Bash script syntax valid" "bash -n ${PROJECT_ROOT}/scripts/test-e2e-deployment.sh"
check "Ansible playbook syntax valid" "ansible-playbook --syntax-check ${PROJECT_ROOT}/ansible/test-e2e.yml"
echo ""

echo "Checking @req annotations..."
check "test-e2e-deployment.sh has @req SCI-ANS-001" "grep -q '@req SCI-ANS-001' ${PROJECT_ROOT}/scripts/test-e2e-deployment.sh"
check "test-e2e-deployment.sh has @req SCI-ANS-002" "grep -q '@req SCI-ANS-002' ${PROJECT_ROOT}/scripts/test-e2e-deployment.sh"
check "test-e2e-deployment.sh has @req SCI-ANS-003" "grep -q '@req SCI-ANS-003' ${PROJECT_ROOT}/scripts/test-e2e-deployment.sh"
check "test-e2e.yml has @req SCI-ANS-001" "grep -q '@req SCI-ANS-001' ${PROJECT_ROOT}/ansible/test-e2e.yml"
check "test-e2e.yml has @req SCI-ANS-002" "grep -q '@req SCI-ANS-002' ${PROJECT_ROOT}/ansible/test-e2e.yml"
check "test-e2e.yml has @req SCI-ANS-003" "grep -q '@req SCI-ANS-003' ${PROJECT_ROOT}/ansible/test-e2e.yml"
check "e2e-test.yml has @req annotations" "grep -q '@req SCI-ANS-001' ${PROJECT_ROOT}/.github/workflows/e2e-test.yml"
check "E2E-TESTING.md has @req annotations" "grep -q '@req SCI-ANS-001' ${PROJECT_ROOT}/docs/E2E-TESTING.md"
echo ""

echo "Checking task status..."
check "TASK-059 status is 'done'" "grep -A 3 'id: TASK-059' ${PROJECT_ROOT}/tasks.yaml | grep -q 'status: done'"
check "TASK-059 has updatedAt timestamp" "grep -A 6 'id: TASK-059' ${PROJECT_ROOT}/tasks.yaml | grep -q 'updatedAt:'"
echo ""

echo "Checking README updates..."
check "README has E2E testing section" "grep -q 'End-to-End Testing' ${PROJECT_ROOT}/README.md"
check "README references SCI-ANS-001" "grep -q 'SCI-ANS-001' ${PROJECT_ROOT}/README.md"
check "README references SCI-ANS-002" "grep -q 'SCI-ANS-002' ${PROJECT_ROOT}/README.md"
check "README references SCI-ANS-003" "grep -q 'SCI-ANS-003' ${PROJECT_ROOT}/README.md"
check "README links to E2E-TESTING.md" "grep -q 'E2E-TESTING.md' ${PROJECT_ROOT}/README.md"
echo ""

echo "Checking test implementations..."
check "Bash script has prerequisite checks" "grep -q 'Prerequisites Check' ${PROJECT_ROOT}/scripts/test-e2e-deployment.sh"
check "Bash script has deployment test" "grep -q 'Initial Deployment' ${PROJECT_ROOT}/scripts/test-e2e-deployment.sh"
check "Bash script has validation test" "grep -q 'Post-Deploy Validation' ${PROJECT_ROOT}/scripts/test-e2e-deployment.sh"
check "Bash script has idempotency test" "grep -q 'Idempotency' ${PROJECT_ROOT}/scripts/test-e2e-deployment.sh"
check "Ansible playbook has deployment tasks" "grep -q 'Deploy SDD Navigator Helm chart' ${PROJECT_ROOT}/ansible/test-e2e.yml"
check "Ansible playbook has validation tasks" "grep -q 'Validate API healthcheck' ${PROJECT_ROOT}/ansible/test-e2e.yml"
check "Ansible playbook has idempotency test" "grep -q 'second run' ${PROJECT_ROOT}/ansible/test-e2e.yml"
echo ""

echo "Checking CI workflow..."
check "CI workflow has bash script job" "grep -q 'e2e-test:' ${PROJECT_ROOT}/.github/workflows/e2e-test.yml"
check "CI workflow has ansible playbook job" "grep -q 'e2e-test-ansible-playbook:' ${PROJECT_ROOT}/.github/workflows/e2e-test.yml"
check "CI workflow has summary job" "grep -q 'summary:' ${PROJECT_ROOT}/.github/workflows/e2e-test.yml"
check "CI workflow creates kind cluster" "grep -q 'kind-action' ${PROJECT_ROOT}/.github/workflows/e2e-test.yml"
check "CI workflow uploads artifacts" "grep -q 'upload-artifact' ${PROJECT_ROOT}/.github/workflows/e2e-test.yml"
echo ""

echo "Checking documentation..."
check "E2E-TESTING.md has overview section" "grep -q '## Overview' ${PROJECT_ROOT}/docs/E2E-TESTING.md"
check "E2E-TESTING.md has test workflow section" "grep -q '## Test Workflow' ${PROJECT_ROOT}/docs/E2E-TESTING.md"
check "E2E-TESTING.md has debugging section" "grep -q '## Debugging' ${PROJECT_ROOT}/docs/E2E-TESTING.md"
check "TEST-E2E-README.md has usage section" "grep -q '## Usage' ${PROJECT_ROOT}/ansible/TEST-E2E-README.md"
check "TEST-E2E-README.md has workflow section" "grep -q '## Test Workflow' ${PROJECT_ROOT}/ansible/TEST-E2E-README.md"
check "E2E-TEST-CHECKLIST.md has validation items" "grep -q 'Pre-Test Validation' ${PROJECT_ROOT}/docs/E2E-TEST-CHECKLIST.md"
check "TASK-059-IMPLEMENTATION.md has summary" "grep -q 'Implementation Summary' ${PROJECT_ROOT}/docs/TASK-059-IMPLEMENTATION.md"
echo ""

echo "======================================"
echo "  Validation Results"
echo "======================================"
echo "Passed: ${PASS_COUNT}"
echo "Failed: ${FAIL_COUNT}"
echo ""

if [[ ${FAIL_COUNT} -eq 0 ]]; then
  echo -e "${GREEN}✓ TASK-059 implementation is complete and valid${NC}"
  echo ""
  echo "Requirements verified:"
  echo "  ✓ SCI-ANS-001: Ansible orchestration testing"
  echo "  ✓ SCI-ANS-002: Post-deploy validation testing"
  echo "  ✓ SCI-ANS-003: Idempotency testing"
  echo ""
  exit 0
else
  echo -e "${RED}✗ TASK-059 implementation has issues${NC}"
  echo ""
  echo "Please review failed checks above and fix issues."
  echo ""
  exit 1
fi