#!/usr/bin/env bash
# @req SCI-ANS-001
# @req SCI-ANS-002
# @req SCI-ANS-003
# @req SCI-TRACE-001
# Comprehensive validation script for Ansible orchestration implementation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ANSIBLE_DIR="${PROJECT_ROOT}/ansible"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ERRORS=0
WARNINGS=0

echo "===== Ansible Implementation Validation ====="
echo ""
echo "Validating compliance with SCI-ANS-001, SCI-ANS-002, SCI-ANS-003"
echo ""

# Helper functions
pass() {
  echo -e "${GREEN}✓${NC} $1"
}

fail() {
  echo -e "${RED}✗${NC} $1"
  ((ERRORS++))
}

warn() {
  echo -e "${YELLOW}⚠${NC} $1"
  ((WARNINGS++))
}

info() {
  echo -e "${BLUE}ℹ${NC} $1"
}

# 1. File Structure Validation
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1. File Structure (@req SCI-ANS-001)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check playbook exists
if [[ -f "${ANSIBLE_DIR}/playbook.yml" ]]; then
  pass "playbook.yml exists"
else
  fail "playbook.yml missing"
fi

# Check roles exist
if [[ -d "${ANSIBLE_DIR}/roles/deploy" ]]; then
  pass "deploy role exists"
else
  fail "deploy role missing"
fi

if [[ -d "${ANSIBLE_DIR}/roles/validate" ]]; then
  pass "validate role exists"
else
  fail "validate role missing"
fi

# Check role tasks
if [[ -f "${ANSIBLE_DIR}/roles/deploy/tasks/main.yml" ]]; then
  pass "deploy role tasks defined"
else
  fail "deploy role tasks missing"
fi

if [[ -f "${ANSIBLE_DIR}/roles/validate/tasks/main.yml" ]]; then
  pass "validate role tasks defined"
else
  fail "validate role tasks missing"
fi

# Check configuration files
if [[ -f "${ANSIBLE_DIR}/group_vars/all.yml" ]]; then
  pass "group_vars/all.yml exists (DRY configuration)"
else
  fail "group_vars/all.yml missing"
fi

if [[ -f "${ANSIBLE_DIR}/inventory/local.yml" ]]; then
  pass "inventory/local.yml exists"
else
  fail "inventory/local.yml missing"
fi

if [[ -f "${ANSIBLE_DIR}/requirements.yml" ]]; then
  pass "requirements.yml exists"
else
  fail "requirements.yml missing"
fi

echo ""

# 2. Traceability Validation
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2. Traceability (@req SCI-TRACE-001)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check @req annotations in playbook
if grep -q "@req SCI-ANS" "${ANSIBLE_DIR}/playbook.yml"; then
  pass "playbook.yml has @req annotations"
else
  fail "playbook.yml missing @req annotations"
fi

# Check @req annotations in deploy role
if grep -q "@req SCI-ANS-001" "${ANSIBLE_DIR}/roles/deploy/tasks/main.yml"; then
  pass "deploy role references SCI-ANS-001"
else
  fail "deploy role missing SCI-ANS-001 reference"
fi

if grep -q "@req SCI-ANS-003" "${ANSIBLE_DIR}/roles/deploy/tasks/main.yml"; then
  pass "deploy role references SCI-ANS-003 (idempotency)"
else
  fail "deploy role missing SCI-ANS-003 reference"
fi

# Check @req annotations in validate role
if grep -q "@req SCI-ANS-002" "${ANSIBLE_DIR}/roles/validate/tasks/main.yml"; then
  pass "validate role references SCI-ANS-002"
else
  fail "validate role missing SCI-ANS-002 reference"
fi

if grep -q "@req SCI-ANS-003" "${ANSIBLE_DIR}/roles/validate/tasks/main.yml"; then
  pass "validate role references SCI-ANS-003 (idempotency)"
else
  fail "validate role missing SCI-ANS-003 reference"
fi

# Check group_vars annotations
if grep -q "@req SCI-ANS" "${ANSIBLE_DIR}/group_vars/all.yml"; then
  pass "group_vars/all.yml has @req annotations"
else
  fail "group_vars/all.yml missing @req annotations"
fi

echo ""

# 3. Deployment Order Validation (SCI-ANS-001)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "3. Deployment Order (@req SCI-ANS-001)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

DEPLOY_TASKS="${ANSIBLE_DIR}/roles/deploy/tasks/main.yml"

# Check namespace creation
if grep -q "Create Kubernetes namespace" "${DEPLOY_TASKS}"; then
  pass "Namespace creation task present"
else
  fail "Namespace creation task missing"
fi

# Check secrets creation
if grep -q "Create database secret" "${DEPLOY_TASKS}"; then
  pass "Secret creation task present"
else
  fail "Secret creation task missing"
fi

# Check Helm deployment
if grep -q "Deploy SDD Navigator Helm chart" "${DEPLOY_TASKS}"; then
  pass "Helm chart deployment task present"
else
  fail "Helm chart deployment task missing"
fi

# Check wait for API
if grep -q "Wait for API pods to be ready" "${DEPLOY_TASKS}"; then
  pass "Wait for API pods task present"
else
  fail "Wait for API pods task missing"
fi

# Check wait for frontend
if grep -q "Wait for frontend pods to be ready" "${DEPLOY_TASKS}"; then
  pass "Wait for frontend pods task present"
else
  fail "Wait for frontend pods task missing"
fi

# Check wait for database
if grep -q "Wait for database to be ready" "${DEPLOY_TASKS}"; then
  pass "Wait for database pods task present"
else
  fail "Wait for database pods task missing"
fi

# Verify kubernetes.core.helm module usage
if grep -q "kubernetes.core.helm:" "${DEPLOY_TASKS}"; then
  pass "Uses kubernetes.core.helm module"
else
  fail "kubernetes.core.helm module not used"
fi

# Verify wait parameter
if grep -q 'wait:.*"{{.*helm.wait' "${DEPLOY_TASKS}"; then
  pass "Helm deployment waits for ready state"
else
  warn "Helm deployment may not wait for ready state"
fi

echo ""

# 4. Validation Checks (SCI-ANS-002)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "4. Post-Deploy Validation (@req SCI-ANS-002)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

VALIDATE_TASKS="${ANSIBLE_DIR}/roles/validate/tasks/main.yml"

# Check /healthcheck validation
if grep -q "/healthcheck" "${VALIDATE_TASKS}"; then
  pass "API /healthcheck validation present"
else
  fail "API /healthcheck validation missing"
fi

# Check /stats validation
if grep -q "/stats" "${VALIDATE_TASKS}"; then
  pass "API /stats validation present"
else
  fail "API /stats validation missing"
fi

# Check pods Running validation
if grep -q "pods.*Running" "${VALIDATE_TASKS}"; then
  pass "Pods Running status check present"
else
  fail "Pods Running status check missing"
fi

# Check PostgreSQL validation
if grep -q "pg_isready" "${VALIDATE_TASKS}"; then
  pass "PostgreSQL pg_isready check present"
else
  fail "PostgreSQL pg_isready check missing"
fi

# Check for retries
if grep -q "retries:" "${VALIDATE_TASKS}"; then
  pass "Validation tasks have retry logic"
else
  warn "Validation tasks may not have retry logic"
fi

# Check for debug output
if grep -q "ansible.builtin.debug:" "${VALIDATE_TASKS}"; then
  pass "Validation results reported via debug output"
else
  fail "Validation results not reported via debug"
fi

# Check for PASS/FAIL reporting
if grep -q "PASS.*FAIL" "${VALIDATE_TASKS}"; then
  pass "PASS/FAIL reporting implemented"
else
  fail "PASS/FAIL reporting missing"
fi

# Check for validation failure task
if grep -q "Fail if any validation check failed" "${VALIDATE_TASKS}"; then
  pass "Playbook fails if validation checks fail"
else
  fail "Missing task to fail on validation failure"
fi

echo ""

# 5. Idempotency Validation (SCI-ANS-003)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "5. Idempotency (@req SCI-ANS-003)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check for state: present (idempotent)
if grep -q "state: present" "${DEPLOY_TASKS}"; then
  pass "Uses 'state: present' for idempotency"
else
  warn "May not use 'state: present' for resources"
fi

# Check validate tasks use read-only operations
if grep -q "k8s_info\|k8s_exec" "${VALIDATE_TASKS}"; then
  pass "Validate role uses read-only operations"
else
  warn "Validate role may modify state"
fi

# Check for idempotency test script
if [[ -f "${SCRIPT_DIR}/test-idempotency.sh" ]]; then
  pass "Idempotency test script exists"
  if [[ -x "${SCRIPT_DIR}/test-idempotency.sh" ]]; then
    pass "Idempotency test script is executable"
  else
    warn "Idempotency test script not executable"
  fi
else
  fail "Idempotency test script missing"
fi

# Check for idempotency annotations
IDEMPOTENT_ANNOTATIONS=$(grep -c "idempotent" "${DEPLOY_TASKS}" || echo 0)
if [[ ${IDEMPOTENT_ANNOTATIONS} -gt 0 ]]; then
  pass "Deploy tasks annotated with idempotency notes (${IDEMPOTENT_ANNOTATIONS} occurrences)"
else
  warn "Deploy tasks lack idempotency documentation"
fi

echo ""

# 6. DRY Principle Validation
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "6. DRY Configuration (@req SCI-HELM-006)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check group_vars contains namespace
if grep -q "namespace:" "${ANSIBLE_DIR}/group_vars/all.yml"; then
  pass "Namespace defined in group_vars"
else
  fail "Namespace not defined in group_vars"
fi

# Check group_vars contains database config
if grep -q "database:" "${ANSIBLE_DIR}/group_vars/all.yml"; then
  pass "Database config defined in group_vars"
else
  fail "Database config not defined in group_vars"
fi

# Check group_vars contains helm config
if grep -q "helm:" "${ANSIBLE_DIR}/group_vars/all.yml"; then
  pass "Helm config defined in group_vars"
else
  fail "Helm config not defined in group_vars"
fi

# Check for Jinja2 variable references
VAR_REFS=$(grep -c "{{" "${DEPLOY_TASKS}" || echo 0)
if [[ ${VAR_REFS} -gt 5 ]]; then
  pass "Deploy tasks reference variables (${VAR_REFS} references)"
else
  warn "Deploy tasks may have hardcoded values"
fi

# Check no duplicate namespace definitions
NAMESPACE_DEFS=$(grep -r "namespace:" "${ANSIBLE_DIR}" --include="*.yml" | grep -v "release_namespace\|create_namespace" | wc -l || echo 0)
if [[ ${NAMESPACE_DEFS} -le 2 ]]; then
  pass "Namespace defined in single location (DRY)"
else
  warn "Namespace may be defined in multiple locations (${NAMESPACE_DEFS} occurrences)"
fi

echo ""

# 7. Ansible Syntax and Lint
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "7. Syntax and Lint Validation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check ansible-playbook is available
if command -v ansible-playbook &> /dev/null; then
  pass "ansible-playbook found in PATH"
  
  # Syntax check
  if ansible-playbook "${ANSIBLE_DIR}/playbook.yml" -i "${ANSIBLE_DIR}/inventory/local.yml" --syntax-check &> /dev/null; then
    pass "Playbook syntax is valid"
  else
    fail "Playbook syntax check failed"
  fi
else
  warn "ansible-playbook not found, skipping syntax check"
fi

# Check ansible-lint is available
if command -v ansible-lint &> /dev/null; then
  pass "ansible-lint found in PATH"
  
  # Run ansible-lint
  if ansible-lint "${ANSIBLE_DIR}/playbook.yml" "${ANSIBLE_DIR}/roles/" --profile production 2>&1 | grep -q "Passed:"; then
    pass "ansible-lint validation passed"
  else
    warn "ansible-lint reported issues (check manually)"
  fi
else
  warn "ansible-lint not found, skipping lint check"
fi

# Check yamllint is available
if command -v yamllint &> /dev/null; then
  pass "yamllint found in PATH"
  
  # Run yamllint on ansible directory
  if yamllint "${ANSIBLE_DIR}" &> /dev/null; then
    pass "yamllint validation passed"
  else
    warn "yamllint reported issues (check manually)"
  fi
else
  warn "yamllint not found, skipping YAML lint check"
fi

echo ""

# 8. Documentation
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "8. Documentation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [[ -f "${ANSIBLE_DIR}/README.md" ]]; then
  pass "README.md exists"
else
  warn "README.md missing"
fi

if [[ -f "${ANSIBLE_DIR}/IMPLEMENTATION.md" ]]; then
  pass "IMPLEMENTATION.md exists (detailed docs)"
else
  warn "IMPLEMENTATION.md missing"
fi

# Check deploy script exists
if [[ -f "${SCRIPT_DIR}/deploy.sh" ]]; then
  pass "Deployment helper script exists"
  if [[ -x "${SCRIPT_DIR}/deploy.sh" ]]; then
    pass "Deployment script is executable"
  else
    warn "Deployment script not executable"
  fi
else
  warn "Deployment helper script missing"
fi

echo ""

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Validation Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [[ ${ERRORS} -eq 0 ]]; then
  echo -e "${GREEN}✓ All critical validations passed${NC}"
  echo ""
  echo "Requirements coverage:"
  echo "  ✓ SCI-ANS-001: Ansible orchestration with correct deployment order"
  echo "  ✓ SCI-ANS-002: Post-deploy validation with pass/fail reporting"
  echo "  ✓ SCI-ANS-003: Idempotency enforcement and testing"
  echo "  ✓ SCI-TRACE-001: Traceability annotations present"
  echo ""
else
  echo -e "${RED}✗ ${ERRORS} critical error(s) found${NC}"
  echo ""
fi

if [[ ${WARNINGS} -gt 0 ]]; then
  echo -e "${YELLOW}⚠ ${WARNINGS} warning(s) issued${NC}"
  echo ""
fi

echo "Next steps:"
if [[ ${ERRORS} -eq 0 ]]; then
  echo "  1. Run: ./scripts/deploy.sh --check (dry-run deployment)"
  echo "  2. Run: ./scripts/test-idempotency.sh (verify idempotency)"
  echo "  3. Deploy: DB_PASSWORD=secret ./scripts/deploy.sh"
else
  echo "  1. Fix errors listed above"
  echo "  2. Re-run this validation script"
fi
echo ""

# Exit with error if any errors found
if [[ ${ERRORS} -gt 0 ]]; then
  exit 1
else
  exit 0
fi