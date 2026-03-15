# SDD Navigator - Kubernetes Deployment Infrastructure

Deploy Rust API, Next.js frontend, and PostgreSQL to Kubernetes using Helm charts orchestrated by Ansible.

## Architecture

```
├── charts/sdd-navigator/          # Umbrella Helm chart
│   ├── templates/
│   │   ├── _helpers.tpl           # @req SCI-HELM-006
│   │   └── ingress.yaml           # @req SCI-HELM-004
│   └── charts/
│       ├── api/                   # @req SCI-HELM-001
│       ├── frontend/              # @req SCI-HELM-003
│       └── postgresql/            # @req SCI-HELM-002 (Bitnami dependency)
├── ansible/
│   ├── playbook.yml               # @req SCI-ANS-001
│   └── roles/
│       ├── deploy/
│       └── validate/              # @req SCI-ANS-002
├── scripts/
│   └── check-traceability.sh      # @req SCI-TRACE-001
└── .github/workflows/
    └── infra-ci.yml               # @req SCI-CI-001, SCI-CI-002
```

## Scripts

- `check-traceability.sh` - Verify `@req` annotation coverage
- `validate-req-references.sh` - Check @req IDs exist in requirements.yaml
- `lint-local.sh` - Run all linters locally (yamllint, ansible-lint, helm lint)
- `validate-ansible.sh` - Ansible playbook syntax check
- `deploy.sh` - Deploy wrapper script
- `test-idempotency.sh` - Verify Ansible idempotency
- `test-traceability.sh` - Full traceability test suite

## Prerequisites

- Kubernetes v1.28+
- Helm 3.14+
- Ansible 2.15+ with `kubernetes.core` collection
- kubectl configured

## Deployment

```bash
export DB_PASSWORD="your-secure-password"
ansible-playbook -i ansible/inventory/local.yml ansible/playbook.yml
```

## Configuration (@req SCI-HELM-006)

Single source of truth: `charts/sdd-navigator/values.yaml`

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
    password: "PLACEHOLDER_MUST_OVERRIDE" # MUST override via --set
```

## CI/CD (@req SCI-CI-001, SCI-CI-002)

1. Lint (yamllint, ansible-lint, helm lint)
2. Schema validation (kubeconform)
3. Traceability check (`@req` coverage)
4. Dry-run deployment

## Traceability (@req SCI-TRACE-001)

Every file MUST contain `# @req REQ-ID` annotations:

```bash
./scripts/check-traceability.sh
./scripts/validate-req-references.sh
```

## Security (@req SCI-SEC-001)

- Non-root containers
- Explicit image versions (no `latest`)
- Secrets via Kubernetes Secrets only

## Validation (@req SCI-ANS-002)

Post-deployment checks:
- API `/healthcheck` returns 200
- All pods `Running`
- DB `pg_isready` succeeds