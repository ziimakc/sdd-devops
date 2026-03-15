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

## Scripts

| Script | Purpose |
|--------|---------|
| `scripts/test-e2e-deployment.sh` | Full deployment test with validation |
| `scripts/check-traceability.sh` | Verify @req annotations present |
| `scripts/validate-req-references.sh` | Verify @req references are valid |
| `scripts/lint-local.sh` | Lint all infrastructure code |
| `scripts/run-demo.sh` | Demonstrate CI violation detection |

## PostgreSQL: Bitnami Chart Choice

We use the **Bitnami PostgreSQL Helm chart** as a dependency rather than a custom StatefulSet.

**Rationale:**
- Battle-tested in thousands of production deployments
- Regular security patches and updates from Bitnami
- Feature-complete (replication, backups, metrics exporters, init scripts)
- Reduced maintenance burden for Kubernetes API changes
- Industry standard with extensive community support

**Trade-off:** More configuration surface (~100 options vs ~50 lines of custom YAML) and external dependency, but production-readiness outweighs parsimony for database infrastructure.

## Configuration

All values centralized in `charts/sdd-navigator/values.yaml`. Override via `--set` or environment variables. Database password MUST be set (no default).

## Prerequisites

- Kubernetes cluster (v1.28+)
- Helm 3.14+
- Ansible 2.15+ with `kubernetes.core` collection
- kubectl configured with cluster access