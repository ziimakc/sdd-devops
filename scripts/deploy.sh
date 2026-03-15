#!/usr/bin/env bash
# @req SCI-ANS-001
# @req SCI-ANS-002
# Convenience script to deploy SDD Navigator using Ansible

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

# Print usage
usage() {
  cat << EOF
Usage: $0 [OPTIONS]

Deploy SDD Navigator to Kubernetes using Ansible

OPTIONS:
  -h, --help              Show this help message
  -v, --verbose           Run Ansible with verbose output (-vv)
  -c, --check             Run in check mode (dry-run, no changes)
  -t, --tags TAGS         Run only tasks with specified tags
  --skip-tags TAGS        Skip tasks with specified tags
  --skip-validation       Skip validation role (deploy only)

ENVIRONMENT VARIABLES:
  DB_PASSWORD             PostgreSQL password (required)
  KUBECONFIG              Path to kubectl config (optional, uses default)

EXAMPLES:
  # Deploy with password
  DB_PASSWORD=secret123 $0

  # Deploy with verbose output
  DB_PASSWORD=secret123 $0 --verbose

  # Dry-run deployment
  DB_PASSWORD=secret123 $0 --check

  # Deploy without validation
  DB_PASSWORD=secret123 $0 --skip-validation

REQUIREMENTS:
  - Ansible >= 2.14
  - kubectl with cluster access
  - Helm >= 3.8
  - kubernetes.core Ansible collection

EOF
}

# Parse arguments
VERBOSE=""
CHECK_MODE=""
TAGS=""
SKIP_TAGS=""
ANSIBLE_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      usage
      exit 0
      ;;
    -v|--verbose)
      VERBOSE="-vv"
      shift
      ;;
    -c|--check)
      CHECK_MODE="--check"
      shift
      ;;
    -t|--tags)
      TAGS="--tags $2"
      shift 2
      ;;
    --skip-tags)
      SKIP_TAGS="--skip-tags $2"
      shift 2
      ;;
    --skip-validation)
      SKIP_TAGS="--skip-tags validate"
      shift
      ;;
    *)
      echo -e "${RED}ERROR: Unknown option: $1${NC}"
      echo ""
      usage
      exit 1
      ;;
  esac
done

# Build ansible-playbook arguments
if [[ -n "${VERBOSE}" ]]; then
  ANSIBLE_ARGS+=("${VERBOSE}")
fi

if [[ -n "${CHECK_MODE}" ]]; then
  ANSIBLE_ARGS+=("${CHECK_MODE}")
fi

if [[ -n "${TAGS}" ]]; then
  ANSIBLE_ARGS+=(${TAGS})
fi

if [[ -n "${SKIP_TAGS}" ]]; then
  ANSIBLE_ARGS+=(${SKIP_TAGS})
fi

# Header
echo -e "${BLUE}===== SDD Navigator Deployment =====${NC}"
echo ""

# Validate prerequisites
echo "Checking prerequisites..."

# Check Ansible
if ! command -v ansible-playbook &> /dev/null; then
  echo -e "${RED}ERROR: ansible-playbook not found${NC}"
  echo "Install: pip install ansible"
  exit 1
fi
echo -e "${GREEN}✓${NC} ansible-playbook found"

# Check kubectl
if ! command -v kubectl &> /dev/null; then
  echo -e "${RED}ERROR: kubectl not found${NC}"
  echo "Install: https://kubernetes.io/docs/tasks/tools/"
  exit 1
fi
echo -e "${GREEN}✓${NC} kubectl found"

# Check kubectl cluster access
if ! kubectl cluster-info &> /dev/null; then
  echo -e "${RED}ERROR: Cannot connect to Kubernetes cluster${NC}"
  echo "Check: kubectl cluster-info"
  exit 1
fi
echo -e "${GREEN}✓${NC} kubectl cluster access"

# Check Helm
if ! command -v helm &> /dev/null; then
  echo -e "${YELLOW}WARNING: helm not found (Ansible will use helm module)${NC}"
else
  echo -e "${GREEN}✓${NC} helm found"
fi

# Check Ansible collection
if ! ansible-galaxy collection list | grep -q "kubernetes.core" 2>/dev/null; then
  echo -e "${YELLOW}WARNING: kubernetes.core collection not found${NC}"
  echo "Installing collection..."
  ansible-galaxy collection install -r "${ANSIBLE_DIR}/requirements.yml"
else
  echo -e "${GREEN}✓${NC} kubernetes.core collection installed"
fi

# Check DB_PASSWORD
if [[ -z "${DB_PASSWORD:-}" ]]; then
  echo ""
  echo -e "${RED}ERROR: DB_PASSWORD environment variable not set${NC}"
  echo ""
  echo "Set password:"
  echo "  export DB_PASSWORD='your-secure-password'"
  echo ""
  echo "Then run:"
  echo "  $0"
  echo ""
  exit 1
fi
echo -e "${GREEN}✓${NC} DB_PASSWORD is set"

# Check playbook exists
if [[ ! -f "${ANSIBLE_DIR}/playbook.yml" ]]; then
  echo -e "${RED}ERROR: playbook.yml not found at ${ANSIBLE_DIR}/playbook.yml${NC}"
  exit 1
fi
echo -e "${GREEN}✓${NC} playbook.yml found"

# Summary
echo ""
echo "Configuration:"
echo "  Playbook:   ${ANSIBLE_DIR}/playbook.yml"
echo "  Inventory:  ${ANSIBLE_DIR}/inventory/local.yml"
echo "  Mode:       ${CHECK_MODE:-normal (apply changes)}"
echo "  Verbose:    ${VERBOSE:-no}"
if [[ -n "${TAGS}" ]]; then
  echo "  Tags:       ${TAGS#--tags }"
fi
if [[ -n "${SKIP_TAGS}" ]]; then
  echo "  Skip tags:  ${SKIP_TAGS#--skip-tags }"
fi
echo ""

# Confirmation for production mode
if [[ -z "${CHECK_MODE}" ]]; then
  echo -e "${YELLOW}This will deploy SDD Navigator to the cluster.${NC}"
  read -p "Continue? (y/N) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 0
  fi
fi

# Run playbook
echo ""
echo -e "${BLUE}Running Ansible playbook...${NC}"
echo ""

if ansible-playbook \
  -i "${ANSIBLE_DIR}/inventory/local.yml" \
  "${ANSIBLE_DIR}/playbook.yml" \
  "${ANSIBLE_ARGS[@]}"; then
  
  echo ""
  echo -e "${GREEN}===== Deployment Successful =====${NC}"
  echo ""
  
  if [[ -z "${CHECK_MODE}" ]]; then
    echo "SDD Navigator is deployed to namespace: sdd-navigator"
    echo ""
    echo "Check status:"
    echo "  kubectl -n sdd-navigator get pods"
    echo "  kubectl -n sdd-navigator get svc"
    echo ""
    echo "View logs:"
    echo "  kubectl -n sdd-navigator logs -l app.kubernetes.io/component=api"
    echo ""
    echo "Access application (if ingress enabled):"
    echo "  kubectl -n sdd-navigator get ingress"
    echo ""
  else
    echo "Check mode completed successfully (no changes made)"
  fi
  
  exit 0
else
  EXIT_CODE=$?
  echo ""
  echo -e "${RED}===== Deployment Failed =====${NC}"
  echo ""
  echo "Check logs above for errors."
  echo ""
  echo "Common issues:"
  echo "  - DB_PASSWORD not set or incorrect"
  echo "  - Kubernetes cluster not accessible"
  echo "  - Helm chart not found at ../charts/sdd-navigator"
  echo "  - Insufficient permissions in cluster"
  echo ""
  echo "Debug:"
  echo "  kubectl cluster-info"
  echo "  kubectl -n sdd-navigator get pods"
  echo ""
  exit ${EXIT_CODE}
fi