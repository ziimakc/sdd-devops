# SDD Navigator - Kubernetes Deployment Infrastructure

Infrastructure as Code for deploying the SDD Navigator stack (Rust API, Next.js frontend, PostgreSQL) to Kubernetes using Helm and Ansible.

## Overview

This repository implements the DevOps layer for the SDD (Software-Defined Development) Navigator toolchain. It deploys a full observability stack consisting of:

- **API Service**: Rust-based code analysis API (`sdd-coverage`)
- **Frontend**: nginx serving Next.js static export
- **Database**: PostgreSQL with persistent storage

## Architecture

```
├── charts/sdd-navigator/          # Umbrella Helm chart
│   ├── templates/
│   │   ├── _helpers.tpl           # Shared labels/selectors (@req SCI-HELM-006)
│   │   └── ingress.yaml           # Route /api/* → API, / → frontend (@req SCI-HELM-004)
│   └── charts/
│       ├── api/                   # API subchart (@req SCI-HELM-001)
│       └── frontend/              # Frontend subchart (@req SCI-HELM-003)
├── ansible/
│   ├── playbook.yml               # Orchestrates deployment (@req SCI-ANS-001)
│   └── roles/
│       ├── deploy/                # Deploys Helm chart
│       └── validate/              # Post-deployment checks (@req SCI-ANS-002)
├── scripts/
│   └── check-traceability.sh      # Enforces @req annotations (@req SCI-TRACE-001)
└── .github/workflows/
    └── infra-ci.yml               # Lint, validate, dry-run (@req SCI-CI-001, SCI-CI-002)
```

## Requirements Traceability

Every artifact references requirements from `requirements.yaml`:

| Requirement | Description | Implementation |
|-------------|-------------|----------------|
| `SCI-HELM-001` | API deployment with probes | `charts/sdd-navigator/charts/api/` |
| `SCI-HELM-002` | PostgreSQL StatefulSet/PVC | `charts/sdd-navigator/values.yaml` |
| `SCI-HELM-003` | Frontend nginx deployment | `charts/sdd-navigator/charts/frontend/` |
| `SCI-HELM-004` | Ingress routing | `charts/sdd-navigator/templates/ingress.yaml` |
| `SCI-HELM-005` | Secrets/ConfigMaps | `*/templates/{secret,configmap}.yaml` |
| `SCI-HELM-006` | DRY via values.yaml | All `values.yaml` + `_helpers.tpl` |
| `SCI-ANS-001` | Ansible orchestration | `ansible/roles/deploy/tasks/main.yml` |
| `SCI-ANS-002` | Post-deploy validation | `ansible/roles/validate/tasks/main.yml` |
| `SCI-ANS-003` | Idempotent playbooks | All Ansible tasks use `state: present` |
| `SCI-CI-001` | Lint pipeline | `.github/workflows/infra-ci.yml` |
| `SCI-CI-002` | Manifest validation | CI job `validate-manifests` |
| `SCI-TRACE-001` | @req annotations | `scripts/check-traceability.sh` |
| `SCI-SEC-001` | Security baseline | `securityContext` in all deployments |

## Prerequisites

- Kubernetes cluster (v1.28+)
- Helm 3.14+
- Ansible 2.15+ with `kubernetes.core` collection
- kubectl configured with cluster access

## Quick Start

### 1. Deploy with Ansible

```bash
# Set database password (required - no defaults per SCI-HELM-005)
export DB_PASSWORD="your-secure-password"

# Run deployment
ansible-playbook -i ansible/inventory/local.yml ansible/playbook.yml
```

### 2. Deploy with Helm Directly

```bash
# Create namespace
kubectl create namespace sdd-navigator

# Install chart
helm install sdd-navigator charts/sdd-navigator \
  --namespace sdd-navigator \
  --set database.password="${DB_PASSWORD}"
```

### 3. Verify Deployment

```bash
# Check pod status
kubectl get pods -n sdd-navigator

# Test API healthcheck
kubectl port-forward -n sdd-navigator svc/sdd-navigator-api 8080:8080
curl http://localhost:8080/healthcheck

# Access frontend
kubectl port-forward -n sdd-navigator svc/sdd-navigator-frontend 8080:80
open http://localhost:8080
```

## Configuration

### DRY Principle (@req SCI-HELM-006)

All configurable values reside in `charts/sdd-navigator/values.yaml`:

```yaml
api:
  image:
    tag: "0.1.0"          # Single source for API version
  replicaCount: 2
  port: 8080
  resources:
    limits:
      memory: "512Mi"
      cpu: "500m"

database:
  password: "PLACEHOLDER_MUST_OVERRIDE"  # Fails visibly if not set
```

Override via Helm:

```bash
helm install sdd-navigator charts/sdd-navigator \
  --set api.replicaCount=3 \
  --set database.password="${DB_PASSWORD}"
```

Override via Ansible (`ansible/group_vars/all.yml`):

```yaml
database:
  password: "{{ lookup('env', 'DB_PASSWORD') }}"
```

## Development Workflow

### 1. Make Changes

Edit Helm charts, Ansible playbooks, or CI config.

### 2. Add Traceability Annotations

Every file MUST have `# @req REQ-ID`:

```yaml
# @req SCI-HELM-001
apiVersion: apps/v1
kind: Deployment
...
```

### 3. Validate Locally

```bash
# Lint Helm charts
helm lint charts/sdd-navigator

# Render templates (catch template errors)
helm template sdd-navigator charts/sdd-navigator \
  --set database.password=test

# Check traceability
./scripts/check-traceability.sh

# Lint Ansible
ansible-lint ansible/playbook.yml

# Validate YAML syntax
yamllint .
```

### 4. CI/CD Pipeline

On push, GitHub Actions runs:

1. **Parallel linting**: yamllint, ansible-lint, helm lint
2. **Manifest validation**: Render + kubeconform schema checks
3. **Traceability check**: Enforces `@req` annotations
4. **Dry-run deployment**: Helm install with `--dry-run`

Pipeline fails if:
- Any linter reports errors
- Rendered manifests violate Kubernetes schemas
- Files missing `@req` annotations
- Dry-run reveals template errors

## Security (@req SCI-SEC-001)

- All containers run as non-root (`runAsUser: 1000` / `101`)
- No `latest` tags - explicit versions only
- Secrets stored in Kubernetes Secrets, not values.yaml
- Placeholder password fails deployment if not overridden

## Idempotency (@req SCI-ANS-003)

Running `ansible-playbook` twice produces zero changes:

```bash
# First run: creates resources
ansible-playbook -i ansible/inventory/local.yml ansible/playbook.yml
# PLAY RECAP: changed=5

# Second run: no changes
ansible-playbook -i ansible/inventory/local.yml ansible/playbook.yml
# PLAY RECAP: changed=0
```

Achieved via:
- `kubernetes.core.k8s` with `state: present`
- `kubernetes.core.helm` detects existing releases
- ConfigMaps/Secrets use declarative state

## Validation Checks (@req SCI-ANS-002)

Post-deployment, Ansible verifies:

| Check | Validation |
|-------|------------|
| API health | `/healthcheck` returns HTTP 200 |
| API stats | `/stats` returns HTTP 200 |
| Pods running | All pods in `Running` state |
| Database ready | `pg_isready` succeeds |

Failures cause playbook to exit with error.

## Troubleshooting

### Deployment Fails: "PLACEHOLDER_MUST_OVERRIDE"

**Cause**: Database password not set (intentional fail-fast per SCI-HELM-005)

**Fix**: Set password via environment variable or Helm values

```bash
export DB_PASSWORD="secure-password"
ansible-playbook ...
```

### Validation Fails: API Healthcheck Timeout

**Check pod logs**:
```bash
kubectl logs -n sdd-navigator deployment/sdd-navigator-api
```

**Common causes**:
- Database connection failed (check credentials)
- API port mismatch (verify ConfigMap)
- Resource limits too low (increase in values.yaml)

### Traceability Check Fails

**Cause**: File missing `# @req` annotation

**Fix**: Add annotation at top of file:

```yaml
# @req SCI-HELM-001
apiVersion: apps/v1
...
```

## Parsimony-Driven Development (PDD)

This project follows PDD principles:

1. **Justify existence**: Every line has a purpose - removing it loses meaning
2. **No redundancy**: Comments explain *why*, not *what* (code is self-documenting)
3. **DRY enforcement**: Values defined once, referenced everywhere
4. **Deterministic checks**: Linters/validators run in CI, not manual review

## Contributing

1. Read `requirements.yaml` - understand *what* you're implementing
2. Add `# @req REQ-ID` annotations
3. Run local validation (`helm lint`, `./scripts/check-traceability.sh`)
4. Ensure CI passes before merging

## License

MIT