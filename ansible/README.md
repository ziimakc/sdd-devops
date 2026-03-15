# @req SCI-ANS-001
# @req SCI-ANS-002
# @req SCI-ANS-003
# SDD Navigator Ansible Orchestration

Ansible playbook for deploying and validating the SDD Navigator stack to Kubernetes.

## Requirements

- Ansible >= 2.14
- Python >= 3.8
- kubectl configured with cluster access
- Helm >= 3.8

## Installation

Install required Ansible collections:

```bash
ansible-galaxy collection install -r requirements.yml
```

## Usage

### Environment Variables

- `DB_PASSWORD` - PostgreSQL password (required, no default)

Example:
```bash
export DB_PASSWORD="your-secure-password"
```

### Deploy

Deploy the full stack:

```bash
ansible-playbook -i inventory/local.yml playbook.yml
```

### Configuration

Edit `group_vars/all.yml` to customize:

- Kubernetes namespace
- Helm chart path
- Database credentials (user, name, port)
- Validation settings (retry count, timeout)
- Resource wait timeout

## Idempotency (SCI-ANS-003)

Per requirement **SCI-ANS-003**, this playbook MUST be idempotent:

> Running the playbook twice MUST produce zero changes on the second run. All Ansible tasks MUST report ok (not changed) when the desired state already exists.

### Testing Idempotency

Run the idempotency test script:

```bash
../scripts/test-idempotency.sh
```

This script:
1. Runs the playbook to perform initial deployment
2. Waits for system stabilization
3. Runs the playbook again
4. Verifies zero tasks reported "changed" on second run
5. Exits with code 0 if idempotent, 1 if not

### Idempotency Implementation

All tasks use idempotent Ansible modules:

| Task | Module | Idempotency Mechanism |
|------|--------|----------------------|
| Create namespace | `kubernetes.core.k8s` | `state: present` only creates if missing |
| Create secrets | `kubernetes.core.k8s` | `state: present` only updates if changed |
| Deploy Helm chart | `kubernetes.core.helm` | Helm's native 3-way merge |
| Wait for pods | `kubernetes.core.k8s_info` | Read-only query, no state change |
| Validation checks | `kubernetes.core.k8s_exec` | Read-only HTTP/pg_isready checks |

## Roles

### deploy

Deploys the SDD Navigator stack in the correct order:

1. **Create namespace** - Creates `sdd-navigator` namespace
2. **Create secrets** - Deploys database credentials secret
3. **Deploy Helm chart** - Installs/upgrades the chart with wait
4. **Wait for pods** - Ensures API, frontend, and database pods reach Ready state

All tasks reference **@req SCI-ANS-001** and **@req SCI-ANS-003**.

### validate

Post-deployment validation checks per **SCI-ANS-002**:

1. **API /healthcheck** - Verifies HTTP 200 response
2. **API /stats** - Verifies HTTP 200 response
3. **All pods Running** - Checks all pods in Running state
4. **PostgreSQL** - Verifies connection with `pg_isready`

Each check:
- Retries up to 10 times with 5s delay (configurable)
- Reports PASS/FAIL in debug output
- Fails the playbook if any check fails

## Deployment Order (SCI-ANS-001)

The playbook deploys components in this sequence:

```
namespace → secrets → helm chart (database, API, frontend, ingress) → wait for ready → validate
```

Each component waits for the previous to reach ready state before proceeding.

## Traceability

Every task file contains `# @req` annotations linking back to requirements:

- **SCI-ANS-001**: Ansible orchestration with correct deployment order
- **SCI-ANS-002**: Post-deploy validation with pass/fail reporting
- **SCI-ANS-003**: Idempotency enforcement

## Directory Structure

```
ansible/
├── README.md              # This file
├── playbook.yml           # Main playbook
├── requirements.yml       # Ansible Galaxy dependencies
├── inventory/
│   └── local.yml          # Localhost inventory
├── group_vars/
│   └── all.yml            # Deployment variables (DRY single source)
└── roles/
    ├── deploy/
    │   └── tasks/
    │       └── main.yml   # Deployment tasks
    └── validate/
        └── tasks/
            └── main.yml   # Validation tasks
```

## Troubleshooting

### Playbook fails on first run

Check:
1. kubectl can connect to cluster: `kubectl cluster-info`
2. DB_PASSWORD is set: `echo $DB_PASSWORD`
3. Helm chart exists: `ls ../charts/sdd-navigator/Chart.yaml`

### Validation fails

Check pod logs:
```bash
kubectl -n sdd-navigator logs -l app.kubernetes.io/component=api
kubectl -n sdd-navigator get pods
```

### Playbook not idempotent

Run with verbose mode to see which tasks change:
```bash
ansible-playbook -i inventory/local.yml playbook.yml -vv
```

Tasks should show `ok:` not `changed:` on subsequent runs.

## CI Integration

This playbook is linted in CI via:
- `ansible-lint playbook.yml`
- Traceability checks for `@req` annotations

See `.github/workflows/` for CI configuration.