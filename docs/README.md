# SDD Navigator Documentation

This directory contains documentation for the SDD Navigator infrastructure deployment and CI validation demonstration.

## Contents

### CI Validation Demonstration
- **[DEMO_CI_VALIDATION.md](DEMO_CI_VALIDATION.md)** - Comprehensive guide to demonstration branches showcasing CI pipeline violation detection

### Demonstration Materials

The demonstration consists of 5 intentionally flawed branches that showcase the CI pipeline's ability to detect common violations:

| Branch | Violation | Requirement | Detection Method |
|--------|-----------|-------------|------------------|
| `demo/violation-missing-req` | Missing @req annotation | SCI-TRACE-001 | `check-traceability.sh` |
| `demo/violation-hardcoded-port` | Hardcoded port number | SCI-HELM-006 | Manual grep / code review |
| `demo/violation-missing-probe` | No liveness probe | SCI-HELM-001 | Manifest validation |
| `demo/violation-plaintext-password` | Plaintext credentials | SCI-HELM-005 | Pattern matching |
| `demo/violation-orphan-req` | Invalid @req reference | SCI-TRACE-001 | `validate-req-references.sh` |

### Quick Start

Run the automated demonstration:

```bash
./scripts/run-demo.sh
```

This script checks out each violation branch sequentially and verifies that the CI validation scripts correctly detect the violations.

### SDD Four Pillars

All infrastructure follows **Specification-Driven Development** principles:

1. **Traceability** - Every artifact annotated with `@req REQ-ID`
2. **DRY** - Single source of truth for all configuration
3. **Deterministic Enforcement** - Automated validation in CI
4. **Parsimony** - Minimal, meaningful code only

### Project Structure

```
sdd-devops/
├── charts/                    # Helm charts
│   └── sdd-navigator/        # Main umbrella chart
├── ansible/                   # Deployment playbooks
├── scripts/                   # Validation and deployment scripts
├── .github/workflows/         # CI pipeline definitions
├── docs/                      # This directory
├── requirements.yaml          # All infrastructure requirements
└── tasks.yaml                # Development task tracking
```

### Requirements

See `../requirements.yaml` for the complete list of functional and architectural requirements that the infrastructure must satisfy.

### Related Scripts

- `scripts/check-traceability.sh` - Scan for missing @req annotations
- `scripts/validate-req-references.sh` - Validate @req references exist
- `scripts/run-demo.sh` - Run automated demonstration
- `scripts/lint-local.sh` - Run all linters locally
- `scripts/deploy.sh` - Deploy to Kubernetes cluster

### CI Pipeline

The GitHub Actions workflow (`.github/workflows/validate.yml`) runs:
- YAML linting
- Helm chart validation
- Ansible playbook validation
- Kubernetes manifest schema validation
- Traceability annotation checks
- Requirement reference validation

All checks must pass before code can be merged to main branch.

---

**Last Updated**: 2026-03-15