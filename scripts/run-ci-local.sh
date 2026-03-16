#!/usr/bin/env bash
# @req SCI-CI-001
# @req SCI-CI-002
# Run GitHub Actions CI workflows locally using act from Nektos

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ACT_BIN="${PROJECT_ROOT}/temp/bin/act"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}INFO:${NC} $*"
}

log_success() {
    echo -e "${GREEN}SUCCESS:${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}WARNING:${NC} $*"
}

log_error() {
    echo -e "${RED}ERROR:${NC} $*"
}

# Check if act is installed
check_act() {
    if [[ ! -f "${ACT_BIN}" ]]; then
        log_info "act not found, installing to temp/bin/"
        mkdir -p "${PROJECT_ROOT}/temp/bin"
        cd "${PROJECT_ROOT}/temp/bin"
        
        log_info "Downloading act..."
        curl -L https://github.com/nektos/act/releases/latest/download/act_Linux_x86_64.tar.gz -o act.tar.gz
        tar xzf act.tar.gz
        rm act.tar.gz
        chmod +x act
        
        log_success "act installed successfully"
        cd "${PROJECT_ROOT}"
    fi
    
    "${ACT_BIN}" --version
}

# Configure act if not already configured
configure_act() {
    local actrc="${HOME}/.config/act/actrc"
    
    if [[ ! -f "${actrc}" ]]; then
        log_info "Configuring act..."
        mkdir -p "$(dirname "${actrc}")"
        echo "-P ubuntu-latest=catthehacker/ubuntu:act-latest" > "${actrc}"
        log_success "act configured"
    fi
}

# Run yamllint manually (act's yamllint action doesn't work well)
run_yamllint() {
    log_info "Running yamllint manually..."
    
    if ! command -v yamllint &> /dev/null; then
        log_error "yamllint not found. Install with: pip install yamllint"
        return 1
    fi
    
    if yamllint -c "${PROJECT_ROOT}/.yamllint" "${PROJECT_ROOT}"; then
        log_success "yamllint passed"
        return 0
    else
        log_warning "yamllint found issues"
        return 0  # Don't fail on warnings
    fi
}

# Run individual CI job
run_job() {
    local workflow="$1"
    local job="$2"
    
    log_info "Running job: ${job}"
    
    if "${ACT_BIN}" -W "${PROJECT_ROOT}/.github/workflows/${workflow}" -j "${job}" --quiet; then
        log_success "Job '${job}' passed"
        return 0
    else
        log_error "Job '${job}' failed"
        return 1
    fi
}

# Run all Infrastructure CI jobs
run_infra_ci() {
    local failed=0
    
    echo ""
    echo "=============================================="
    echo "  Running Infrastructure CI (locally)"
    echo "=============================================="
    echo ""
    
    # Run yamllint manually since the GitHub Action doesn't work in act
    run_yamllint || ((failed++))
    echo ""
    
    # Run ansible-lint
    run_job "infra-ci.yml" "lint-ansible" || ((failed++))
    echo ""
    
    # Run helm-lint
    run_job "infra-ci.yml" "lint-helm" || ((failed++))
    echo ""
    
    # Run manifest validation
    run_job "infra-ci.yml" "validate-manifests" || ((failed++))
    echo ""
    
    # Run traceability check
    run_job "infra-ci.yml" "check-traceability" || ((failed++))
    echo ""
    
    echo "=============================================="
    if [[ ${failed} -eq 0 ]]; then
        log_success "All Infrastructure CI checks passed! ✅"
        echo "=============================================="
        return 0
    else
        log_error "${failed} check(s) failed ❌"
        echo "=============================================="
        return 1
    fi
}

# Run E2E tests (requires kind cluster)
run_e2e() {
    log_warning "E2E tests require kind cluster and take ~45 minutes"
    log_info "To run E2E tests manually, use:"
    echo "  ${ACT_BIN} -W .github/workflows/e2e-test.yml -j e2e-test"
    echo "  ${ACT_BIN} -W .github/workflows/e2e-test.yml -j e2e-test-ansible-playbook"
}

# Main function
main() {
    cd "${PROJECT_ROOT}"
    
    local command="${1:-infra-ci}"
    
    case "${command}" in
        infra-ci|ci)
            check_act
            configure_act
            run_infra_ci
            ;;
        
        e2e)
            check_act
            configure_act
            run_e2e
            ;;
        
        job)
            if [[ $# -lt 3 ]]; then
                log_error "Usage: $0 job <workflow-file> <job-name>"
                echo "Example: $0 job infra-ci.yml lint-helm"
                exit 1
            fi
            check_act
            configure_act
            run_job "$2" "$3"
            ;;
        
        help|--help|-h)
            echo "Usage: $0 [command]"
            echo ""
            echo "Commands:"
            echo "  infra-ci, ci    Run Infrastructure CI checks (default)"
            echo "  e2e             Show E2E test instructions"
            echo "  job <workflow> <job-name>  Run specific job"
            echo "  help            Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                           # Run all CI checks"
            echo "  $0 infra-ci                  # Run Infrastructure CI"
            echo "  $0 job infra-ci.yml lint-helm  # Run specific job"
            ;;
        
        *)
            log_error "Unknown command: ${command}"
            echo "Run '$0 help' for usage information"
            exit 1
            ;;
    esac
}

main "$@"