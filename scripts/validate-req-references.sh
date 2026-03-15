#!/bin/bash
# @req SCI-TRACE-001
# Validate that all @req annotations reference existing requirements in requirements.yaml

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
REQUIREMENTS_FILE="${PROJECT_ROOT}/requirements.yaml"

if [ ! -f "${REQUIREMENTS_FILE}" ]; then
  echo -e "${RED}ERROR: requirements.yaml not found at ${REQUIREMENTS_FILE}${NC}"
  exit 1
fi

EXCLUDED_PATTERNS=(
  ".git"
  "node_modules"
  "temp"
)

build_exclude_args() {
  local args=()
  for pattern in "${EXCLUDED_PATTERNS[@]}"; do
    args+=("-not" "-path" "*/${pattern}/*")
  done
  echo "${args[@]}"
}

echo "Validating @req annotations reference existing requirements"
echo "Requirements file: ${REQUIREMENTS_FILE}"
echo ""

EXCLUDE_ARGS=($(build_exclude_args))

FILES=$(find "${PROJECT_ROOT}" \
  \( -name "*.yaml" -o -name "*.yml" -o -name "*.tpl" -o -name "*.sh" \) \
  "${EXCLUDE_ARGS[@]}" \
  -type f \
  -not -name "requirements.yaml" \
  -not -name "tasks.yaml")

VALID_REQ_IDS=$(grep -E "^\s+- id: " "${REQUIREMENTS_FILE}" | sed -E 's/^\s+- id:\s+//' | sort | uniq)

INVALID_COUNT=0
TOTAL_ANNOTATIONS=0
CHECKED_FILES=0

declare -A INVALID_REFS

for file in ${FILES}; do
  if ! grep -q "@req " "${file}"; then
    continue
  fi
  
  CHECKED_FILES=$((CHECKED_FILES + 1))
  REL_PATH="${file#${PROJECT_ROOT}/}"
  
  FOUND_REFS=$(grep -oE "@req [A-Z]+-[A-Z]+-[0-9]+" "${file}" | sed 's/@req //' | sort | uniq)
  
  for ref in ${FOUND_REFS}; do
    TOTAL_ANNOTATIONS=$((TOTAL_ANNOTATIONS + 1))
    
    if ! echo "${VALID_REQ_IDS}" | grep -q "^${ref}$"; then
      INVALID_COUNT=$((INVALID_COUNT + 1))
      if [ -z "${INVALID_REFS[${ref}]+isset}" ]; then
        INVALID_REFS[${ref}]="${REL_PATH}"
      else
        INVALID_REFS[${ref}]="${INVALID_REFS[${ref}]}, ${REL_PATH}"
      fi
      echo -e "${RED}INVALID${NC} ${REL_PATH}: @req ${ref} (requirement does not exist)"
    fi
  done
done

echo ""
echo "===== @req Reference Validation Summary ====="
echo "Files checked: ${CHECKED_FILES}"
echo "Total @req annotations: ${TOTAL_ANNOTATIONS}"
echo ""

if [ ${INVALID_COUNT} -eq 0 ]; then
  echo -e "${GREEN}✓ All @req annotations reference existing requirements${NC}"
  
  echo ""
  echo "Valid requirements referenced:"
  for req_id in ${VALID_REQ_IDS}; do
    REF_COUNT=$(grep -r "@req ${req_id}" "${PROJECT_ROOT}" \
      --include="*.yaml" --include="*.yml" --include="*.tpl" --include="*.sh" \
      --exclude="requirements.yaml" --exclude="tasks.yaml" \
      2>/dev/null | wc -l || echo 0)
    if [ ${REF_COUNT} -gt 0 ]; then
      echo "  - ${req_id}: ${REF_COUNT} reference(s)"
    fi
  done
  
  echo ""
  echo "Unreferenced requirements:"
  UNREFERENCED=0
  for req_id in ${VALID_REQ_IDS}; do
    REF_COUNT=$(grep -r "@req ${req_id}" "${PROJECT_ROOT}" \
      --include="*.yaml" --include="*.yml" --include="*.tpl" --include="*.sh" \
      --exclude="requirements.yaml" --exclude="tasks.yaml" \
      2>/dev/null | wc -l || echo 0)
    if [ ${REF_COUNT} -eq 0 ]; then
      echo -e "  ${YELLOW}- ${req_id}${NC}"
      UNREFERENCED=$((UNREFERENCED + 1))
    fi
  done
  
  if [ ${UNREFERENCED} -eq 0 ]; then
    echo "  (none)"
  fi
  
  exit 0
else
  echo -e "${RED}✗ ${INVALID_COUNT} invalid @req reference(s) found${NC}"
  echo ""
  echo "Invalid references by requirement ID:"
  for ref in "${!INVALID_REFS[@]}"; do
    echo -e "  ${RED}${ref}${NC}: ${INVALID_REFS[${ref}]}"
  done
  exit 1
fi