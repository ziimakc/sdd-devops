#!/bin/bash
# @req SCI-TRACE-001
# Scan infrastructure files for @req traceability annotations

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

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

echo "Checking traceability annotations in ${PROJECT_ROOT}"
echo "Files must contain: @req REQ-ID (in # or {{/* comments)"
echo ""

EXCLUDE_ARGS=($(build_exclude_args))

FILES=$(find "${PROJECT_ROOT}" \
  \( -name "*.yaml" -o -name "*.yml" -o -name "*.tpl" \) \
  "${EXCLUDE_ARGS[@]}" \
  -type f)

MISSING_COUNT=0
TOTAL_COUNT=0

for file in ${FILES}; do
  TOTAL_COUNT=$((TOTAL_COUNT + 1))
  REL_PATH="${file#${PROJECT_ROOT}/}"
  
  if ! grep -q "@req " "${file}"; then
    echo -e "${RED}MISSING${NC} ${REL_PATH}"
    MISSING_COUNT=$((MISSING_COUNT + 1))
  fi
done

echo ""
echo "===== Traceability Check Summary ====="
echo "Total files scanned: ${TOTAL_COUNT}"

if [ ${MISSING_COUNT} -eq 0 ]; then
  echo -e "${GREEN}✓ All files have @req annotations${NC}"
  exit 0
else
  echo -e "${RED}✗ ${MISSING_COUNT} file(s) missing @req annotations${NC}"
  exit 1
fi