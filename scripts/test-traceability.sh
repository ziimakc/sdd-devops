#!/bin/bash
# @req SCI-TRACE-001
# Comprehensive test suite for traceability system

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

TESTS_PASSED=0
TESTS_FAILED=0

# Test result helper functions
pass_test() {
  TESTS_PASSED=$((TESTS_PASSED + 1))
  printf "${GREEN}✓${NC} %s\n" "$1"
}

fail_test() {
  TESTS_FAILED=$((TESTS_FAILED + 1))
  printf "${RED}✗${NC} %s\n" "$1"
  if [ -n "${2:-}" ]; then
    echo "  Error: $2"
  fi
}

info_test() {
  printf "${CYAN}→${NC} %s\n" "$1"
}

printf "${BOLD}===== Traceability System Test Suite =====${NC}\n\n"

# Test 1: Check traceability script exists and is executable
info_test "Test 1: Verify check-traceability.sh exists and is executable"
if [ -x "${SCRIPT_DIR}/check-traceability.sh" ]; then
  pass_test "check-traceability.sh is executable"
else
  fail_test "check-traceability.sh is not executable"
fi

# Test 2: Check validation script exists and is executable
info_test "Test 2: Verify validate-req-references.sh exists and is executable"
if [ -x "${SCRIPT_DIR}/validate-req-references.sh" ]; then
  pass_test "validate-req-references.sh is executable"
else
  fail_test "validate-req-references.sh is not executable"
fi

# Test 4: Run check-traceability.sh
info_test "Test 4: Run check-traceability.sh"
if "${SCRIPT_DIR}/check-traceability.sh" > /dev/null 2>&1; then
  pass_test "All files have @req annotations"
else
  fail_test "Some files are missing @req annotations"
fi

# Test 5: Run validate-req-references.sh
info_test "Test 5: Run validate-req-references.sh"
if "${SCRIPT_DIR}/validate-req-references.sh" > /dev/null 2>&1; then
  pass_test "All @req references are valid"
else
  fail_test "Some @req references are invalid"
fi

# Test 6: Verify requirements.yaml exists
info_test "Test 6: Verify requirements.yaml exists"
if [ -f "${PROJECT_ROOT}/requirements.yaml" ]; then
  pass_test "requirements.yaml exists"
else
  fail_test "requirements.yaml not found"
fi

# Test 7: Check all requirement IDs follow naming convention
info_test "Test 7: Verify requirement ID naming convention (SCI-XXX-NNN)"
INVALID_REQ_IDS=$(grep -E "^\s+- id: " "${PROJECT_ROOT}/requirements.yaml" | \
  sed -E 's/^\s+- id:\s+//' | \
  grep -v -E '^SCI-[A-Z]+-[0-9]{3}$' || true)

if [ -z "${INVALID_REQ_IDS}" ]; then
  pass_test "All requirement IDs follow naming convention"
else
  fail_test "Invalid requirement IDs found" "${INVALID_REQ_IDS}"
fi

# Test 8: Check Helm templates have annotations
info_test "Test 8: Verify Helm templates have @req annotations"
HELM_NO_ANNOTATIONS=0
while IFS= read -r file; do
  if [ ! -f "$file" ]; then
    continue
  fi
  if ! grep -q "@req " "$file"; then
    HELM_NO_ANNOTATIONS=$((HELM_NO_ANNOTATIONS + 1))
  fi
done < <(find "${PROJECT_ROOT}/charts" -name "*.yaml" -o -name "*.yml" -o -name "*.tpl" 2>/dev/null)

if [ $HELM_NO_ANNOTATIONS -eq 0 ]; then
  pass_test "All Helm templates have @req annotations"
else
  fail_test "Found $HELM_NO_ANNOTATIONS Helm template(s) without @req annotations"
fi

# Test 9: Check Ansible files have annotations
info_test "Test 9: Verify Ansible files have @req annotations"
ANSIBLE_NO_ANNOTATIONS=0
while IFS= read -r file; do
  if [ ! -f "$file" ]; then
    continue
  fi
  if ! grep -q "@req " "$file"; then
    ANSIBLE_NO_ANNOTATIONS=$((ANSIBLE_NO_ANNOTATIONS + 1))
  fi
done < <(find "${PROJECT_ROOT}/ansible" -name "*.yaml" -o -name "*.yml" 2>/dev/null | \
  grep -v "requirements.yml" || true)

if [ $ANSIBLE_NO_ANNOTATIONS -eq 0 ]; then
  pass_test "All Ansible files have @req annotations"
else
  fail_test "Found $ANSIBLE_NO_ANNOTATIONS Ansible file(s) without @req annotations"
fi

# Test 10: Check CI workflows have annotations
info_test "Test 10: Verify CI workflows have @req annotations"
CI_NO_ANNOTATIONS=0
while IFS= read -r file; do
  if [ ! -f "$file" ]; then
    continue
  fi
  if ! grep -q "@req " "$file"; then
    CI_NO_ANNOTATIONS=$((CI_NO_ANNOTATIONS + 1))
  fi
done < <(find "${PROJECT_ROOT}/.github/workflows" -name "*.yaml" -o -name "*.yml" 2>/dev/null)

if [ $CI_NO_ANNOTATIONS -eq 0 ]; then
  pass_test "All CI workflows have @req annotations"
else
  fail_test "Found $CI_NO_ANNOTATIONS CI workflow(s) without @req annotations"
fi

# Test 11: Verify all requirements are referenced at least once
info_test "Test 11: Check for unreferenced requirements"
VALID_REQ_IDS=$(grep -E "^\s+- id: " "${PROJECT_ROOT}/requirements.yaml" | \
  sed -E 's/^\s+- id:\s+//' | sort | uniq)

UNREFERENCED=0
while IFS= read -r req_id; do
  [ -z "$req_id" ] && continue
  REF_COUNT=$(grep -r "@req ${req_id}" "${PROJECT_ROOT}" \
    --include="*.yaml" --include="*.yml" --include="*.tpl" --include="*.sh" \
    --exclude="requirements.yaml" --exclude="tasks.yaml" \
    2>/dev/null | wc -l | xargs || echo 0)
  if [ "$REF_COUNT" -eq 0 ]; then
    UNREFERENCED=$((UNREFERENCED + 1))
  fi
done <<< "${VALID_REQ_IDS}"

if [ $UNREFERENCED -eq 0 ]; then
  pass_test "All requirements are referenced at least once"
else
  fail_test "Found $UNREFERENCED unreferenced requirement(s)"
fi

# Test 13: Verify CI includes traceability checks
info_test "Test 13: Verify CI pipeline includes traceability checks"
if [ -f "${PROJECT_ROOT}/.github/workflows/infra-ci.yml" ]; then
  if grep -q "check-traceability" "${PROJECT_ROOT}/.github/workflows/infra-ci.yml"; then
    pass_test "CI includes traceability checks"
  else
    fail_test "CI does not include traceability checks"
  fi
else
  fail_test "CI workflow file not found"
fi

# Test 14: Check for duplicate requirement IDs
info_test "Test 14: Check for duplicate requirement IDs"
DUPLICATE_IDS=$(grep -E "^\s+- id: " "${PROJECT_ROOT}/requirements.yaml" | \
  sed -E 's/^\s+- id:\s+//' | \
  sort | uniq -d)

if [ -z "${DUPLICATE_IDS}" ]; then
  pass_test "No duplicate requirement IDs found"
else
  fail_test "Duplicate requirement IDs found" "${DUPLICATE_IDS}"
fi

# Test 16: Verify annotation format
info_test "Test 16: Verify @req annotation format"
MALFORMED_ANNOTATIONS=$(grep -r "^[[:space:]]*#[[:space:]]*@req" "${PROJECT_ROOT}" \
  --include="*.yaml" --include="*.yml" --include="*.tpl" \
  --exclude="requirements.yaml" --exclude="tasks.yaml" --exclude-dir="temp" \
  2>/dev/null | \
  grep -v "@req SCI-[A-Z]\+-[0-9]\{3\}" || true)

if [ -z "${MALFORMED_ANNOTATIONS}" ]; then
  pass_test "All @req annotations follow correct format"
else
  fail_test "Found malformed @req annotations"
fi

# Test 17: Check traceability coverage by category
info_test "Test 17: Verify traceability coverage by category"
CATEGORIES=("HELM" "ANS" "CI" "TRACE" "SEC")
MISSING_CATEGORIES=()

for category in "${CATEGORIES[@]}"; do
  CAT_REQS=$(grep -E "^\s+- id: SCI-${category}-" "${PROJECT_ROOT}/requirements.yaml" || true)
  if [ -n "${CAT_REQS}" ]; then
    CAT_REF_COUNT=$(grep -r "@req SCI-${category}-" "${PROJECT_ROOT}" \
      --include="*.yaml" --include="*.yml" --include="*.tpl" \
      --exclude="requirements.yaml" --exclude="tasks.yaml" \
      2>/dev/null | wc -l | xargs || echo 0)
    if [ "$CAT_REF_COUNT" -eq 0 ]; then
      MISSING_CATEGORIES+=("$category")
    fi
  fi
done

if [ ${#MISSING_CATEGORIES[@]} -eq 0 ]; then
  pass_test "All requirement categories have references"
else
  fail_test "Categories without references: ${MISSING_CATEGORIES[*]}"
fi

# Test 18: Verify README mentions traceability
info_test "Test 18: Verify README documents traceability system"
if grep -q "Traceability" "${PROJECT_ROOT}/README.md"; then
  pass_test "README documents traceability system"
else
  fail_test "README does not document traceability"
fi

# Test 19: Check script annotations
info_test "Test 19: Verify validation scripts have @req annotations"
SCRIPT_COUNT=0
SCRIPTS_WITH_ANNOTATIONS=0
for script in "${SCRIPT_DIR}"/*.sh; do
  if [ -f "$script" ]; then
    SCRIPT_COUNT=$((SCRIPT_COUNT + 1))
    if grep -q "@req " "$script"; then
      SCRIPTS_WITH_ANNOTATIONS=$((SCRIPTS_WITH_ANNOTATIONS + 1))
    fi
  fi
done

if [ $SCRIPT_COUNT -eq $SCRIPTS_WITH_ANNOTATIONS ]; then
  pass_test "All validation scripts have @req annotations"
else
  fail_test "Some validation scripts lack @req annotations"
fi

# Test 20: Performance check - ensure validation runs in reasonable time
info_test "Test 20: Performance check - validation time"
START_TIME=$(date +%s)
"${SCRIPT_DIR}/validate-req-references.sh" > /dev/null 2>&1
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

if [ $ELAPSED -lt 10 ]; then
  pass_test "Validation completes in ${ELAPSED}s (acceptable)"
else
  fail_test "Validation takes ${ELAPSED}s (too slow, optimize)"
fi

# Summary
echo ""
printf "${BOLD}===== Test Summary =====${NC}\n"
TOTAL_TESTS=$((TESTS_PASSED + TESTS_FAILED))
printf "Total tests: %d\n" "$TOTAL_TESTS"
printf "${GREEN}Passed: %d${NC}\n" "$TESTS_PASSED"
printf "${RED}Failed: %d${NC}\n" "$TESTS_FAILED"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
  printf "${GREEN}${BOLD}✓ All traceability tests passed!${NC}\n"
  exit 0
else
  printf "${RED}${BOLD}✗ Some traceability tests failed${NC}\n"
  exit 1
fi
