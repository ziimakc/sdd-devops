# SDD Navigator - Kubernetes Deployment Infrastructure

Infrastructure as Code for deploying the SDD Navigator stack (Rust API, Next.js frontend, PostgreSQL) to Kubernetes using Helm and Ansible.

## 🎯 Quick Demo

**Want to see automated CI validation in action?**

```bash
./scripts/run-demo.sh
```

This demonstrates 5 intentional violations caught by the CI pipeline:
- Missing `@req` annotations
- Hardcoded values (DRY violations)
- Missing health checks
- Plaintext credentials
- Broken traceability references

**See**: [docs/DEMO_QUICKSTART.md](docs/DEMO_QUICKSTART.md) | [docs/DEMO_SUMMARY.md](docs/DEMO_SUMMARY.md)

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

## PostgreSQL: Bitnami Chart vs Custom StatefulSet (@req SCI-HELM-002)

We use the **Bitnami PostgreSQL Helm chart** as a dependency rather than a custom StatefulSet.

**Rationale:**

1. **Battle-tested** - Thousands of production deployments, edge cases handled
2. **Security maintenance** - Regular security patches and updates from Bitnami
3. **Feature-complete** - Replication, backups, metrics exporters, init scripts included
4. **Community support** - Extensive documentation and issue resolution
5. **Reduced maintenance** - Chart updates handle Kubernetes API changes automatically
6. **Industry standard** - Expected and recognized by engineering teams

**Trade-offs:**

- Adds ~100 configuration options vs ~50 lines of custom YAML
- External dependency on Bitnami chart repository
- More abstraction layers between values and K8s resources

**When custom StatefulSet makes sense:**

- Learning exercises or minimal deployments
- Air-gapped environments without external chart access
- Extreme parsimony requirements (embedded/edge computing)

**Decision:** Production-readiness outweighs parsimony for this infrastructure.

## Prerequisites

- Kubernetes cluster (v1.28+)
- Helm 3.14+
- Ansible 2.15+ with `kubernetes.core` collection
- kubectl configured with cluster access

## Deployment

### With Ansible (recommended)

```bash
export DB_PASSWORD="your-secure-password"
ansible-playbook -i ansible/inventory/local.yml ansible/playbook.yml
```

### With Helm directly

```bash
kubectl create namespace sdd-navigator
helm install sdd-navigator charts/sdd-navigator \
  --namespace sdd-navigator \
  --set postgresql.auth.password="${DB_PASSWORD}"
```

### Verify

```bash
kubectl get pods -n sdd-navigator
kubectl port-forward -n sdd-navigator svc/sdd-navigator-api 8080:8080
curl http://localhost:8080/healthcheck
```

## Configuration (@req SCI-HELM-006)

All values centralized in `charts/sdd-navigator/values.yaml` (DRY principle):

```yaml
api:
  image:
    tag: "0.1.0"
  replicaCount: 2
  resources:
    limits:
      memory: "512Mi"
      cpu: "500m"

postgresql:
  auth:
    password: "PLACEHOLDER_MUST_OVERRIDE" # MUST set via --set or env
    username: sdd_user
    database: sdd_navigator
  primary:
    persistence:
      size: 10Gi
  image:
    tag: "15.4.0-debian-11-r45" # Explicit version (@req SCI-SEC-001)
```

## CI/CD Pipeline (@req SCI-CI-001, SCI-CI-002)

GitHub Actions validates on push:

1. Lint (yamllint, ansible-lint, helm lint)
2. Manifest validation (kubeconform schema checks)
3. Traceability check (`@req` annotation coverage)
4. Dry-run deployment

## Security (@req SCI-SEC-001)

- All containers run as non-root
- No `latest` tags - explicit versions only
- Secrets in Kubernetes Secrets, never hardcoded
- Placeholder password fails deployment if not overridden

## Validation (@req SCI-ANS-002)

Post-deployment checks:

- API healthcheck (`/healthcheck` returns 200)
- API stats endpoint (`/stats` returns 200)
- All pods in `Running` state
- Database responds to `pg_isready`

## Traceability (@req SCI-TRACE-001)

Every infrastructure file contains `@req` annotations linking to requirements in `requirements.yaml`. This enables bidirectional traceability, impact analysis, and coverage metrics.

### Validation Scripts

**Check for missing annotations:**

```bash
./scripts/check-traceability.sh
```

**Validate references are valid:**

```bash
./scripts/validate-req-references.sh
```

**Generate coverage report:**

```bash
./scripts/traceability-report.sh
```

## Troubleshooting

**"PLACEHOLDER_MUST_OVERRIDE" error**: Set `DB_PASSWORD` environment variable or use `--set postgresql.auth.password=...`

**API healthcheck fails**: Check `kubectl logs -n sdd-navigator deployment/sdd-navigator-api` for database connection issues

**Missing @req annotations**: Add `# @req REQ-ID` at top of files, run `./scripts/check-traceability.sh`

**Invalid @req reference**: Check `requirements.yaml` for correct requirement IDs, run `./scripts/validate-req-references.sh`

## Demonstration Materials

This repository includes demonstration branches that showcase CI validation capabilities:

| Branch | Violation | Status |
|--------|-----------|--------|
| `demo/violation-missing-req` | Missing @req annotation | ✓ Detected by check-traceability.sh |
| `demo/violation-hardcoded-port` | Hardcoded port number | ✓ Detected by code review |
| `demo/violation-missing-probe` | No liveness probe | ✓ Detected by validation |
| `demo/violation-plaintext-password` | Plaintext credentials | ✓ Detected by pattern matching |
| `demo/violation-orphan-req` | Invalid @req reference | ✓ Detected by validate-req-references.sh |

**Quick Start**: Run `./scripts/run-demo.sh` to test all violations  
**Documentation**: See [docs/](docs/) directory for complete demonstration guide

## SDD Four Pillars

This infrastructure follows **Specification-Driven Development** principles:

1. **Traceability** - Every artifact annotated with `@req REQ-ID`
2. **DRY** - Single source of truth in `values.yaml`
3. **Deterministic Enforcement** - Automated CI validation
4. **Parsimony** - Minimal, meaningful code only

All infrastructure requirements are defined in `requirements.yaml` and enforced through CI.
