#!/bin/bash
# @req SCI-TRACE-001
# @req SCI-CI-001
# Verification script for reviewers to validate demonstration setup

set -e

echo "======================================"
echo "  Demo Verification Script"
echo "======================================"
echo ""
echo "Validating demonstration setup..."
echo ""

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASS=0
FAIL=0

check() {
    local description="$1"
    local command="$2"
    
    echo -n "Checking: $description... "
    
    if eval "$command" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
        PASS=$((PASS + 1))
        return 0
    else
        echo -e "${RED}✗${NC}"
        FAIL=$((FAIL + 1))
        return 1
    fi
}

echo "=== Branch Existence ==="
check "demo/violation-missing-req exists" "git rev-parse --verify demo/violation-missing-req"
check "demo/violation-hardcoded-port exists" "git rev-parse --verify demo/violation-hardcoded-port"
check "demo/violation-missing-probe exists" "git rev-parse --verify demo/violation-missing-probe"
check "demo/violation-plaintext-password exists" "git rev-parse --verify demo/violation-plaintext-password"
check "demo/violation-orphan-req exists" "git rev-parse --verify demo/violation-orphan-req"
echo ""

echo "=== Main Branch Validation ==="
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$CURRENT_BRANCH" != "main" ]; then
    git checkout main >/dev/null 2>&1
fi

check "Main branch passes traceability check" "./scripts/check-traceability.sh"
check "Main branch passes requirement validation" "./scripts/validate-req-references.sh"
check "YAML files are valid" "yamllint ."
check "Helm chart is valid" "helm lint charts/sdd-navigator"
echo ""

echo "=== Violation Detection ==="
# Test 1: Missing annotation
git checkout demo/violation-missing-req >/dev/null 2>&1
if ./scripts/check-traceability.sh >/dev/null 2>&1; then
    echo -e "${RED}✗${NC} Missing annotation NOT detected"
    FAIL=$((FAIL + 1))
else
    echo -e "${GREEN}✓${NC} Missing annotation detected"
    PASS=$((PASS + 1))
fi

# Test 2: Hardcoded port
git checkout demo/violation-hardcoded-port >/dev/null 2>&1
if grep -q "port: 8080" charts/sdd-navigator/templates/api-service.yaml 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Hardcoded port detected"
    PASS=$((PASS + 1))
else
    echo -e "${RED}✗${NC} Hardcoded port NOT detected"
    FAIL=$((FAIL + 1))
fi

# Test 3: Missing probe
git checkout demo/violation-missing-probe >/dev/null 2>&1
if grep -q "livenessProbe" charts/sdd-navigator/templates/frontend-deployment.yaml 2>/dev/null; then
    echo -e "${RED}✗${NC} Missing probe NOT detected"
    FAIL=$((FAIL + 1))
else
    echo -e "${GREEN}✓${NC} Missing probe detected"
    PASS=$((PASS + 1))
fi

# Test 4: Plaintext password
git checkout demo/violation-plaintext-password >/dev/null 2>&1
if grep -q "MySecretPassword123!" charts/sdd-navigator/values.yaml 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Plaintext password detected"
    PASS=$((PASS + 1))
else
    echo -e "${RED}✗${NC} Plaintext password NOT detected"
    FAIL=$((FAIL + 1))
fi

# Test 5: Orphan reference
git checkout demo/violation-orphan-req >/dev/null 2>&1
if ./scripts/validate-req-references.sh >/dev/null 2>&1; then
    echo -e "${RED}✗${NC} Orphan reference NOT detected"
    FAIL=$((FAIL + 1))
else
    echo -e "${GREEN}✓${NC} Orphan reference detected"
    PASS=$((PASS + 1))
fi

# Return to original branch
git checkout "$CURRENT_BRANCH" >/dev/null 2>&1
echo ""

echo "=== Documentation Files ==="
check "DEMO_QUICKSTART.md exists" "test -f docs/DEMO_QUICKSTART.md"
check "DEMO_CI_VALIDATION.md exists" "test -f docs/DEMO_CI_VALIDATION.md"
check "DEMO_SUMMARY.md exists" "test -f docs/DEMO_SUMMARY.md"
check "BRANCH_COMPARISON.md exists" "test -f docs/BRANCH_COMPARISON.md"
check "docs/README.md exists" "test -f docs/README.md"
echo ""

echo "=== Scripts ==="
check "run-demo.sh exists and is executable" "test -x scripts/run-demo.sh"
check "check-traceability.sh exists" "test -x scripts/check-traceability.sh"
check "validate-req-references.sh exists" "test -x scripts/validate-req-references.sh"
echo ""

echo "=== Tasks Completion ==="
check "TASK-051 marked as done" "grep -q 'id: TASK-051' tasks.yaml && grep -A3 'id: TASK-051' tasks.yaml | grep -q 'status: done'"
check "TASK-052 marked as done" "grep -q 'id: TASK-052' tasks.yaml && grep -A3 'id: TASK-052' tasks.yaml | grep -q 'status: done'"
check "TASK-053 marked as done" "grep -q 'id: TASK-053' tasks.yaml && grep -A3 'id: TASK-053' tasks.yaml | grep -q 'status: done'"
check "TASK-054 marked as done" "grep -q 'id: TASK-054' tasks.yaml && grep -A3 'id: TASK-054' tasks.yaml | grep -q 'status: done'"
check "TASK-055 marked as done" "grep -q 'id: TASK-055' tasks.yaml && grep -A3 'id: TASK-055' tasks.yaml | grep -q 'status: done'"
echo ""

echo "======================================"
echo "  Verification Summary"
echo "======================================"
TOTAL=$((PASS + FAIL))
echo "Total checks: $TOTAL"
echo -e "Passed: ${GREEN}$PASS${NC}"
echo -e "Failed: ${RED}$FAIL${NC}"
echo ""

if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}✓ All verification checks passed!${NC}"
    echo "  Demo is ready for review."
    echo ""
    echo "To run the demonstration:"
    echo "  ./scripts/run-demo.sh"
    echo ""
    echo "Documentation available in:"
    echo "  docs/DEMO_QUICKSTART.md"
    echo "  docs/DEMO_SUMMARY.md"
    exit 0
else
    echo -e "${RED}✗ Some verification checks failed.${NC}"
    echo "  Review the failed checks above."
    exit 1
fi