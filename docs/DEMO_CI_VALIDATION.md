# CI Validation Demonstration Guide

**Purpose**: Demonstrate the SDD Navigator infrastructure CI pipeline's ability to detect common violations of requirements and best practices.

**Status**: Ready for demonstration  
**Created**: 2026-03-15  
**Requirements**: SCI-TRACE-001, SCI-HELM-001, SCI-HELM-005, SCI-HELM-006

---

## Overview

This document describes five demonstration branches that intentionally violate infrastructure requirements. Each branch showcases the CI pipeline's automated detection capabilities.

The demonstration follows the **SDD Four Pillars**:
1. **Traceability** - Every change references requirements
2. **DRY** - No duplicate configuration values
3. **Deterministic Enforcement** - Automated validation catches violations
4. **Parsimony** - Minimal, meaningful code

---

## Demonstration Branches

### 1. Missing @req Annotation
**Branch**: `demo/violation-missing-req`  
**Task**: TASK-051  
**Requirement**: SCI-TRACE-001  
**Violation**: Deployment manifest without traceability annotation

#### What It Demonstrates
A new Kubernetes Deployment for the API service is added without any `@req` annotation comment. The traceability check script detects this omission.

#### Files Changed
- `charts/sdd-navigator/templates/api-deployment.yaml` (created, no @req)

#### Detection Method
```bash
./scripts/check-traceability.sh
```

#### Expected Output
```
MISSING charts/sdd-navigator/templates/api-deployment.yaml

✗ 1 file(s) missing @req annotations
```

#### How to Test
```bash
git checkout demo/violation-missing-req
./scripts/check-traceability.sh
# Should exit with code 1
```

---

### 2. Hardcoded Port Number
**Branch**: `demo/violation-hardcoded-port`  
**Task**: TASK-052  
**Requirement**: SCI-HELM-006  
**Violation**: Port numbers hardcoded in template instead of referencing values.yaml

#### What It Demonstrates
A Service manifest uses hardcoded port `8080` instead of templating `{{ .Values.api.port }}`. This violates the DRY principle - the same value exists in multiple places.

#### Files Changed
- `charts/sdd-navigator/templates/api-service.yaml` (created with hardcoded ports)

#### Detection Method
Manual code review or grep for hardcoded values:
```bash
grep -rn "8080" charts/sdd-navigator/templates/
```

#### Expected Output
```
charts/sdd-navigator/templates/api-service.yaml:12:    - port: 8080
charts/sdd-navigator/templates/api-service.yaml:13:      targetPort: 8080
```

#### How to Test
```bash
git checkout demo/violation-hardcoded-port
grep -n "8080" charts/sdd-navigator/templates/api-service.yaml
# Should find hardcoded port numbers
```

#### Proper Fix
Replace hardcoded values:
```yaml
- port: {{ .Values.api.port }}
  targetPort: {{ .Values.api.port }}
```

---

### 3. Missing Liveness Probe
**Branch**: `demo/violation-missing-probe`  
**Task**: TASK-053  
**Requirement**: SCI-HELM-001  
**Violation**: Deployment without liveness probe configuration

#### What It Demonstrates
A frontend Deployment is created without liveness or readiness probes. SCI-HELM-001 explicitly requires health checks with specific parameters.

#### Files Changed
- `charts/sdd-navigator/templates/frontend-deployment.yaml` (created without probes)

#### Detection Method
```bash
helm template charts/sdd-navigator | grep -A10 "kind: Deployment" | grep "livenessProbe"
```

#### Expected Output
No output (probes missing from frontend deployment)

#### How to Test
```bash
git checkout demo/violation-missing-probe
grep -A50 "kind: Deployment" charts/sdd-navigator/templates/frontend-deployment.yaml | grep "livenessProbe"
# Should return no results (exit code 1)
```

#### Proper Fix
Add probe configuration:
```yaml
livenessProbe:
  httpGet:
    path: /
    port: http
  initialDelaySeconds: 10
  periodSeconds: 15
readinessProbe:
  httpGet:
    path: /
    port: http
  initialDelaySeconds: 5
  periodSeconds: 5
```

---

### 4. Plaintext Password
**Branch**: `demo/violation-plaintext-password`  
**Task**: TASK-054  
**Requirement**: SCI-HELM-005  
**Violation**: Real password stored in values.yaml instead of placeholder

#### What It Demonstrates
The PostgreSQL password is changed from `PLACEHOLDER_MUST_OVERRIDE` to an actual password `MySecretPassword123!`. SCI-HELM-005 requires placeholder values that fail visibly if not overridden.

#### Files Changed
- `charts/sdd-navigator/values.yaml` (password changed to plaintext)

#### Detection Method
```bash
grep -E "password.*[^PLACEHOLDER]" charts/sdd-navigator/values.yaml
```

#### Expected Output
```
password: "MySecretPassword123!" # VIOLATION: plaintext password
```

#### How to Test
```bash
git checkout demo/violation-plaintext-password
grep "password:" charts/sdd-navigator/values.yaml
# Should show real password instead of PLACEHOLDER
```

#### Security Impact
- Credentials exposed in version control
- Violates secrets management best practices
- Creates security audit trail exposure

#### Proper Approach
```yaml
password: "PLACEHOLDER_MUST_OVERRIDE"  # Must be set via --set or secret values file
```

---

### 5. Orphan @req Reference
**Branch**: `demo/violation-orphan-req`  
**Task**: TASK-055  
**Requirement**: SCI-TRACE-001  
**Violation**: Annotation references non-existent requirement ID

#### What It Demonstrates
A ConfigMap includes `@req SCI-NONEXISTENT-999` which does not exist in `requirements.yaml`. This breaks bidirectional traceability.

#### Files Changed
- `charts/sdd-navigator/templates/configmap.yaml` (created with invalid @req)

#### Detection Method
```bash
./scripts/validate-req-references.sh
```

#### Expected Output
```
INVALID charts/sdd-navigator/templates/configmap.yaml: @req SCI-NONEXISTENT-999 (requirement does not exist)

✗ 1 invalid @req reference(s) found
```

#### How to Test
```bash
git checkout demo/violation-orphan-req
./scripts/validate-req-references.sh
# Should exit with code 1, reporting orphan reference
```

#### Impact
- Breaks traceability chain
- Creates confusion about requirement sources
- Suggests incomplete requirements documentation

---

## Running Full Demo

Execute all demonstrations in sequence:

```bash
#!/bin/bash
# @req SCI-TRACE-001
# @req SCI-CI-001

echo "=== SDD Navigator CI Validation Demo ==="
echo ""

BRANCHES=(
  "demo/violation-missing-req:./scripts/check-traceability.sh"
  "demo/violation-hardcoded-port:grep -n 8080 charts/sdd-navigator/templates/api-service.yaml"
  "demo/violation-missing-probe:! grep -q livenessProbe charts/sdd-navigator/templates/frontend-deployment.yaml"
  "demo/violation-plaintext-password:grep 'MySecretPassword' charts/sdd-navigator/values.yaml"
  "demo/violation-orphan-req:./scripts/validate-req-references.sh"
)

for entry in "${BRANCHES[@]}"; do
  IFS=':' read -r branch cmd <<< "$entry"
  echo "Testing: $branch"
  git checkout "$branch" 2>&1 | grep "Switched"
  
  if eval "$cmd" 2>&1 | head -20; then
    echo "✗ Violation detected successfully"
  else
    echo "✓ Violation detected (non-zero exit)"
  fi
  echo "---"
done

git checkout main
echo "Demo complete. Return to main branch."
```

Save as `scripts/run-demo.sh` and execute:
```bash
chmod +x scripts/run-demo.sh
./scripts/run-demo.sh
```

---

## CI Pipeline Integration

These violations are automatically caught in the GitHub Actions workflow:

### `.github/workflows/validate.yml` Jobs

1. **lint-yaml** - Catches syntax errors
2. **lint-helm** - Validates Helm chart structure
3. **lint-ansible** - Validates playbook syntax
4. **validate-manifests** - Schema validation with kubeconform
5. **check-traceability** - Detects missing @req annotations
6. **validate-requirements** - Detects orphan @req references

### Workflow Behavior

- **On Pull Request**: All checks run in parallel
- **Failure Mode**: PR blocked if any check fails
- **Status Checks**: Required for merge to main branch

---

## Verification

To verify the main branch passes all checks:

```bash
git checkout main

# YAML syntax
yamllint .

# Helm validation
helm lint charts/sdd-navigator
helm template charts/sdd-navigator | kubeconform -strict -

# Ansible validation
ansible-lint ansible/

# Traceability
./scripts/check-traceability.sh
./scripts/validate-req-references.sh

# All checks should pass with exit code 0
```

---

## Key Takeaways

1. **Deterministic Enforcement**: Tools catch violations automatically, no manual review needed for common errors
2. **Fast Feedback**: Violations detected in seconds during CI
3. **Bidirectional Traceability**: Both missing annotations and invalid references caught
4. **DRY Validation**: While harder to automate fully, templating patterns enforce single source of truth
5. **Security**: Secrets management validated programmatically

---

## Next Steps

After demonstrating violations:

1. Push violation branches to GitHub (optional, for CI demonstration)
2. Create pull requests from violation branches → main
3. Observe CI workflow failures in GitHub Actions
4. Review failed check details and logs
5. Compare with main branch (all checks pass)

---

## Documentation References

- `requirements.yaml` - All infrastructure requirements
- `.github/workflows/validate.yml` - CI pipeline definition
- `scripts/check-traceability.sh` - Annotation coverage check
- `scripts/validate-req-references.sh` - Orphan reference detection
- `docs/TRACEABILITY_QUICKREF.md` - Annotation syntax guide

---

**End of Demonstration Guide**