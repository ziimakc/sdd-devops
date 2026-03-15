# @req SCI-ANS-001
# @req SCI-ANS-002
# @req SCI-ANS-003

# End-to-End Deployment Test

This directory contains the Ansible playbook for end-to-end testing of the SDD Navigator deployment.

## Purpose

The `test-e2e.yml` playbook validates complete deployment workflow from scratch to fully operational stack, verifying:

- **SCI-ANS-001**: Ansible orchestration with correct deployment order
- **SCI-ANS-002**: Post-deploy validation with pass/fail reporting
- **SCI-ANS-003**: Idempotency (second run produces zero changes)

## Usage

### Basic Test Run

```bash
# Set database password
export DB_PASSWORD='your-secure-test-password'

# Run E2E test
ansible-playbook \
  -i inventory/local.yml \
  test-e2e.yml
```

### With Verbose Output

```bash
export DB_PASSWORD='test-password'
ansible-playbook -i inventory/local.yml test-e2e.yml -v
```

### With Extra Verbosity (debugging)

```bash
export DB_PASSWORD='test-password'
ansible-playbook -i inventory/local.yml test-e2e.yml -vvv
```

### Skip Cleanup (for debugging)

```bash
export DB_PASSWORD='test-password'
export SKIP_CLEANUP=true
ansible-playbook -i inventory/local.yml test-e2e.yml
```

Then inspect the test namespace:
```bash
kubectl get all -n sdd-navigator-e2e-test
kubectl -n sdd-navigator-e2e-test logs -l app.kubernetes.io/component=api
```

## Test Workflow

1. **Prerequisites Check**
   - Validates Ansible version >= 2.14
   - Ensures DB_PASSWORD is set

2. **Environment Setup**
   - Cleans up any existing test namespace
   - Creates fresh test namespace: `sdd-navigator-e2e-test`
   - Creates database secret

3. **Initial Deployment (SCI-ANS-001)**
   - Deploys Helm chart with wait enabled
   - Waits for all pods to be ready
   - Verifies deployment order

4. **Post-Deploy Validation (SCI-ANS-002)**
   - Tests API `/healthcheck` endpoint
   - Tests API `/stats` endpoint
   - Verifies all pods are Running
   - Tests PostgreSQL connectivity with `pg_isready`
   - Reports PASS/FAIL for each check

5. **Idempotency Test (SCI-ANS-003)**
   - Waits 5 seconds for system stabilization
   - Deploys Helm chart again (second run)
   - Asserts that no changes were made
   - Verifies `changed == false`

6. **Final Report & Cleanup**
   - Displays comprehensive test summary
   - Reports requirement satisfaction
   - Cleans up test namespace (unless SKIP_CLEANUP=true)

## Expected Output

### Success

```
TASK [Final test summary] ***********************
ok: [localhost] => {
    "msg": "===== E2E Test Summary =====\nStatus: SUCCESS\n\nRequirements Verified:\n  ✓ SCI-ANS-001: Ansible orchestration with correct deployment order\n  ✓ SCI-ANS-002: Post-deploy validation with pass/fail reporting\n  ✓ SCI-ANS-003: Idempotency (second run produces zero changes)\n..."
}

PLAY RECAP **************************************
localhost                  : ok=20   changed=3    failed=0
```

### Failure Example

```
TASK [Verify idempotency] ***********************
fatal: [localhost]: FAILED! => {
    "assertion": "not helm_deploy_second.changed",
    "msg": "Idempotency test FAILED - second deployment reported changes"
}
```

## Prerequisites

- Ansible >= 2.14
- kubernetes.core collection installed
- kubectl with cluster access
- Helm >= 3.8
- Kubernetes cluster (kind, minikube, or real cluster)

### Install Collections

```bash
ansible-galaxy collection install -r requirements.yml
```

## Variables

Test uses variables from `group_vars/all.yml`:

```yaml
kubernetes:
  namespace: sdd-navigator  # Overridden to sdd-navigator-e2e-test in test

helm:
  chart_path: "../charts/sdd-navigator"
  wait: true
  wait_timeout: 300s

api:
  port: 8080

database:
  user: sdd_user
  name: sdd_navigator
  port: 5432
```

## Test Namespace

The playbook uses a dedicated test namespace: `sdd-navigator-e2e-test`

This prevents interference with:
- Production deployments in `sdd-navigator`
- Other test runs
- Manual deployments

## Debugging Failed Tests

### Check Pod Status

```bash
kubectl -n sdd-navigator-e2e-test get pods
kubectl -n sdd-navigator-e2e-test describe pod <pod-name>
```

### Check Pod Logs

```bash
# API logs
kubectl -n sdd-navigator-e2e-test logs -l app.kubernetes.io/component=api

# PostgreSQL logs
kubectl -n sdd-navigator-e2e-test logs -l app.kubernetes.io/name=postgresql

# Frontend logs
kubectl -n sdd-navigator-e2e-test logs -l app.kubernetes.io/component=frontend
```

### Check Events

```bash
kubectl -n sdd-navigator-e2e-test get events --sort-by='.lastTimestamp'
```

### Port-Forward for Manual Testing

```bash
# API service
kubectl -n sdd-navigator-e2e-test port-forward svc/sdd-navigator-test-api 8080:8080

# Test endpoints
curl http://localhost:8080/healthcheck
curl http://localhost:8080/stats
```

### Check Helm Release

```bash
helm list -n sdd-navigator-e2e-test
helm get values sdd-navigator-test -n sdd-navigator-e2e-test
helm get manifest sdd-navigator-test -n sdd-navigator-e2e-test
```

## Manual Cleanup

If test fails or SKIP_CLEANUP=true:

```bash
# Delete test namespace
kubectl delete namespace sdd-navigator-e2e-test --wait=true

# Force delete if stuck
kubectl delete namespace sdd-navigator-e2e-test --grace-period=0 --force
```

## Integration with CI

This playbook is used in `.github/workflows/e2e-test.yml`:

```yaml
- name: Run Ansible E2E test playbook
  env:
    DB_PASSWORD: test-e2e-ansible-${{ github.run_id }}
  run: |
    ansible-playbook \
      -i ansible/inventory/local.yml \
      ansible/test-e2e.yml \
      -v
```

## Comparison with Bash Script

| Feature | Ansible Playbook | Bash Script |
|---------|------------------|-------------|
| Implementation | Native Ansible | Bash + Ansible calls |
| Output format | Ansible task format | Custom formatted |
| Test artifacts | Via Ansible callbacks | Saved to temp/ |
| Idiomatic | Yes | No |
| Learning curve | Ansible knowledge required | Shell scripting |
| CI integration | Direct playbook call | Script wrapper |
| Debugging | Ansible verbosity | Custom logging |

Both implementations test the same requirements and produce equivalent results.

## Exit Codes

- `0` - All tests passed
- `1` - One or more tests failed
- `2` - Prerequisites not met

## Common Issues

### "DB_PASSWORD not set"

```
TASK [Check prerequisites] **********************
fatal: [localhost]: FAILED! => {
    "msg": "Prerequisites not met. Ensure Ansible >= 2.14 and DB_PASSWORD is set."
}
```

**Fix**: Export DB_PASSWORD before running

### "Cannot connect to Kubernetes cluster"

```
TASK [Create test namespace] ********************
fatal: [localhost]: FAILED! => {
    "msg": "Failed to retrieve requested object..."
}
```

**Fix**: Check kubectl connectivity
```bash
kubectl cluster-info
kubectl get nodes
```

### "Timeout waiting for pods"

```
TASK [Wait for all pods to be ready] ************
fatal: [localhost]: FAILED! => {
    "msg": "Timed out waiting for the condition"
}
```

**Fix**: Check pod status and logs, increase wait_timeout if needed

## References

- Main playbook: `playbook.yml`
- Deploy role: `roles/deploy/tasks/main.yml`
- Validate role: `roles/validate/tasks/main.yml`
- Bash E2E test: `../scripts/test-e2e-deployment.sh`
- Full documentation: `../docs/E2E-TESTING.md`
- Requirements: `../requirements.yaml`
