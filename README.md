# SDD Navigator - Kubernetes Deployment Infrastructure

Infrastructure as Code for deploying the SDD Navigator stack (Rust API, Next.js frontend, PostgreSQL) to Kubernetes using Helm and Ansible.

## Project Structure

```
├── charts/sdd-navigator/          # Umbrella Helm chart
│   ├── values.yaml                # Single source of truth for all config
│   ├── templates/
│   │   ├── _helpers.tpl           # Shared labels/selectors
│   │   └── ingress.yaml           # Routes traffic to services
│   └── charts/
│       ├── api/                   # API subchart
│       └── frontend/              # Frontend subchart
├── ansible/
│   ├── playbook.yml               # Orchestrates deployment
│   └── roles/
│       ├── deploy/                # Deploys Helm chart
│       └── validate/              # Post-deployment checks
├── scripts/                       # Validation and testing scripts
└── .github/workflows/             # CI pipeline (lint, validate, test)
```

## Quick Start

```bash
# Build dummy test images (required for testing - not real applications)
./scripts/build-test-images.sh

# Deploy with Ansible (recommended)
export DB_PASSWORD="your-secure-password"
ansible-playbook -i ansible/inventory/local.yml ansible/playbook.yml

# Or deploy with Helm directly
kubectl create namespace sdd-navigator
helm install sdd-navigator charts/sdd-navigator \
  --namespace sdd-navigator \
  --set postgresql.auth.password="${DB_PASSWORD}"

# Verify deployment
kubectl get pods -n sdd-navigator
kubectl port-forward -n sdd-navigator svc/sdd-navigator-api 8080:8080
curl http://localhost:8080/healthcheck
```

**Note:** The `sdd-coverage-api` and `sdd-navigator-frontend` Docker images referenced in the Helm chart do not exist yet. For infrastructure testing, use `scripts/build-test-images.sh` to create minimal dummy images with mock endpoints.

## Scripts

| Script | Purpose |
|--------|---------|
| `scripts/build-test-images.sh` | Build minimal dummy images for testing |
| `scripts/test-e2e-deployment.sh` | Full deployment test with validation |
| `scripts/check-traceability.sh` | Verify @req annotations present |
| `scripts/validate-req-references.sh` | Verify @req references are valid |
| `scripts/lint-local.sh` | Lint all infrastructure code |
| `scripts/run-ci-local.sh` | Run GitHub Actions CI locally with act |

## Running CI Locally

Test GitHub Actions CI locally with [act](https://github.com/nektos/act) (requires Docker):

```bash
# Run all checks (~40s)
./scripts/run-ci-local.sh

# Run specific job
./temp/bin/act -W .github/workflows/infra-ci.yml -j lint-helm
```

First run auto-installs act to `temp/bin/` and downloads ~500MB Docker image. Validates: YAML syntax, Ansible playbooks, Helm charts, K8s manifests, traceability annotations.

## PostgreSQL: Custom StatefulSet

We use a **custom StatefulSet** for PostgreSQL deployment with official `postgres:16.2-alpine` image.

**Rationale:**
- Bitnami recently limited free image availability, creating supply chain risk
- Direct control over PostgreSQL configuration and lifecycle
- Minimal dependencies - only official PostgreSQL Docker image
- Full parsimony compliance - ~150 lines of manifests vs ~1000+ from Bitnami chart
- Kubernetes-native StatefulSet with PVC ensures data persistence
- Standard postgres image widely trusted and maintained by PostgreSQL community

**Implementation:** StatefulSet with persistent volume claim template, credential Secret, readiness/liveness probes, and non-root security context (uid 999).

## Configuration

All values centralized in `charts/sdd-navigator/values.yaml`. Override via `--set` or environment variables. Database password MUST be set (no default).

## Prerequisites

- Kubernetes cluster (v1.28+)
- Helm 3.x (3.14+ recommended, 4.x not yet supported by kubernetes.core)
- Ansible 2.15+ with collections:
  - `kubernetes.core` (>=2.4.0)
  - `ansible.posix` (>=1.5.0)
- Python 3.9+ with libraries:
  - `kubernetes` (>=24.2.0)
  - `PyYAML` (>=3.11)
  - `jsonpatch` (>=1.32)
- kubectl configured with cluster access

```bash
# Install Ansible collections
ansible-galaxy collection install -r ansible/requirements.yml

# Install Python dependencies
pip3 install -r ansible/requirements.txt
```
