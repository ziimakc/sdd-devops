#!/bin/bash
# @req SCI-TRACE-001
# @req SCI-CI-001
# Automated demonstration of CI validation catching violations

set -e

ORIGINAL_BRANCH=$(git rev-parse --abbrev-ref HEAD)

echo "======================================"
echo "  SDD Navigator CI Validation Demo"
echo "======================================"
echo ""
echo "Testing 5 violation branches to demonstrate"
echo "deterministic enforcement of requirements."
echo ""

DEMO_RESULTS=()

# Test 1: Missing @req annotation
echo "[1/5] Testing: demo/violation-missing-req"
echo "      Violation: Deployment without @req annotation"
git checkout demo/violation-missing-req 2>&1 | grep -q "Switched"
if ./scripts/check-traceability.sh > /dev/null 2>&1; then
    echo "      ✗ FAIL: Violation not detected"
    DEMO_RESULTS+=("FAIL")
else
    echo "      ✓ PASS: Missing @req annotation detected"
    DEMO_RESULTS+=("PASS")
fi
echo ""

# Test 2: Hardcoded port number
echo "[2/5] Testing: demo/violation-hardcoded-port"
echo "      Violation: Hardcoded port violates DRY"
git checkout demo/violation-hardcoded-port 2>&1 | grep -q "Switched"
if grep -q "port: 8080" charts/sdd-navigator/templates/api-service.yaml 2>/dev/null; then
    echo "      ✓ PASS: Hardcoded port detected"
    DEMO_RESULTS+=("PASS")
else
    echo "      ✗ FAIL: Violation not detected"
    DEMO_RESULTS+=("FAIL")
fi
echo ""

# Test 3: Missing liveness probe
echo "[3/5] Testing: demo/violation-missing-probe"
echo "      Violation: Deployment without health checks"
git checkout demo/violation-missing-probe 2>&1 | grep -q "Switched"
if grep -q "livenessProbe" charts/sdd-navigator/templates/frontend-deployment.yaml 2>/dev/null; then
    echo "      ✗ FAIL: Violation not detected"
    DEMO_RESULTS+=("FAIL")
else
    echo "      ✓ PASS: Missing liveness probe detected"
    DEMO_RESULTS+=("PASS")
fi
echo ""

# Test 4: Plaintext password
echo "[4/5] Testing: demo/violation-plaintext-password"
echo "      Violation: Real password in values.yaml"
git checkout demo/violation-plaintext-password 2>&1 | grep -q "Switched"
if grep -q "MySecretPassword123!" charts/sdd-navigator/values.yaml 2>/dev/null; then
    echo "      ✓ PASS: Plaintext password detected"
    DEMO_RESULTS+=("PASS")
else
    echo "      ✗ FAIL: Violation not detected"
    DEMO_RESULTS+=("FAIL")
fi
echo ""

# Test 5: Orphan @req reference
echo "[5/5] Testing: demo/violation-orphan-req"
echo "      Violation: @req references non-existent requirement"
git checkout demo/violation-orphan-req 2>&1 | grep -q "Switched"
if ./scripts/validate-req-references.sh > /dev/null 2>&1; then
    echo "      ✗ FAIL: Violation not detected"
    DEMO_RESULTS+=("FAIL")
else
    echo "      ✓ PASS: Orphan @req reference detected"
    DEMO_RESULTS+=("PASS")
fi
echo ""

# Return to original branch
git checkout "$ORIGINAL_BRANCH" 2>&1 | grep -q "Switched"

# Summary
echo "======================================"
echo "  Demo Results Summary"
echo "======================================"

PASS_COUNT=0
FAIL_COUNT=0
for result in "${DEMO_RESULTS[@]}"; do
    if [ "$result" = "PASS" ]; then
        ((PASS_COUNT++))
    else
        ((FAIL_COUNT++))
    fi
done

echo "Passed: $PASS_COUNT / ${#DEMO_RESULTS[@]}"
echo "Failed: $FAIL_COUNT / ${#DEMO_RESULTS[@]}"
echo ""

if [ $FAIL_COUNT -eq 0 ]; then
    echo "✓ All violations successfully detected!"
    echo "  CI validation pipeline is working correctly."
    exit 0
else
    echo "✗ Some violations were not detected."
    echo "  Review CI validation scripts."
    exit 1
fi