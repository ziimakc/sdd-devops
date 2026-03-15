# Demonstration Branch Comparison

**Purpose**: Visual reference showing what each demo branch contains and how violations are detected

---

## Branch Overview

```
main (clean)
├── demo/violation-missing-req      [TASK-051]
├── demo/violation-hardcoded-port   [TASK-052]
├── demo/violation-missing-probe    [TASK-053]
├── demo/violation-plaintext-password [TASK-054]
└── demo/violation-orphan-req       [TASK-055]
```

---

## File Changes by Branch

### `main` Branch (Baseline - All Checks Pass)

```
✓ All files have @req annotations
✓ All values templated from values.yaml
✓ All deployments have health probes
✓ Password is PLACEHOLDER_MUST_OVERRIDE
✓ All @req references valid
```

**Validation Results:**
```bash
./scripts/check-traceability.sh        # EXIT 0
./scripts/validate-req-references.sh   # EXIT 0
yamllint .                             # EXIT 0
helm lint charts/sdd-navigator         # EXIT 0
```

---

### `demo/violation-missing-req` [TASK-051]

**Requirement**: SCI-TRACE-001  
**File Added**: `charts/sdd-navigator/templates/api-deployment.yaml`

**Violation**: Complete Deployment manifest without any `@req` annotation

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "sdd-navigator.fullname" . }}-api
  # ❌ NO @req ANNOTATION
spec:
  replicas: {{ .Values.api.replicaCount }}
  # ... rest of deployment
```

**Detection:**
```bash
./scripts/check-traceability.sh
# Output: MISSING charts/sdd-navigator/templates/api-deployment.yaml
# Exit Code: 1
```

**How to Fix:**
```yaml
# @req SCI-HELM-001
# @req SCI-HELM-006
apiVersion: apps/v1
kind: Deployment
```

---

### `demo/violation-hardcoded-port` [TASK-052]

**Requirement**: SCI-HELM-006 (DRY principle)  
**File Added**: `charts/sdd-navigator/templates/api-service.yaml`

**Violation**: Hardcoded port `8080` instead of templating from values.yaml

```yaml
# @req SCI-HELM-006
apiVersion: v1
kind: Service
metadata:
  name: {{ include "sdd-navigator.fullname" . }}-api
spec:
  type: ClusterIP
  ports:
    - port: 8080              # ❌ HARDCODED
      targetPort: 8080        # ❌ HARDCODED
      protocol: TCP
      name: http
```

**Detection:**
```bash
grep -n "8080" charts/sdd-navigator/templates/api-service.yaml
# Output: 
# 12:    - port: 8080
# 13:      targetPort: 8080
```

**Impact**: 
- Violates DRY (port defined in values.yaml AND template)
- Configuration drift if port changes in values.yaml
- No single source of truth

**How to Fix:**
```yaml
ports:
  - port: {{ .Values.api.port }}
    targetPort: {{ .Values.api.port }}
```

---

### `demo/violation-missing-probe` [TASK-053]

**Requirement**: SCI-HELM-001 (health checks mandatory)  
**File Added**: `charts/sdd-navigator/templates/frontend-deployment.yaml`

**Violation**: Deployment without liveness or readiness probes

```yaml
# @req SCI-HELM-003
# @req SCI-HELM-006
# @req SCI-SEC-001
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      containers:
        - name: frontend
          image: "{{ .Values.frontend.image.repository }}:{{ .Values.frontend.image.tag }}"
          ports:
            - name: http
              containerPort: {{ .Values.frontend.port }}
          # ❌ NO livenessProbe
          # ❌ NO readinessProbe
          resources:
            {{- toYaml .Values.frontend.resources | nindent 12 }}
```

**Detection:**
```bash
grep "livenessProbe" charts/sdd-navigator/templates/frontend-deployment.yaml
# Output: (empty - no probe found)
# Exit Code: 1
```

**Impact**:
- Container failures not detected automatically
- Traffic routed to unhealthy pods
- No automatic restart on failure
- Violates SCI-HELM-001 requirements

**How to Fix:**
```yaml
containers:
  - name: frontend
    # ... existing config
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

### `demo/violation-plaintext-password` [TASK-054]

**Requirement**: SCI-HELM-005 (secrets management)  
**File Modified**: `charts/sdd-navigator/values.yaml`

**Violation**: Real password instead of fail-fast placeholder

```yaml
postgresql:
  enabled: true
  auth:
    username: sdd_user
    password: "MySecretPassword123!"  # ❌ PLAINTEXT PASSWORD
    database: sdd_navigator
```

**Original (Correct):**
```yaml
postgresql:
  auth:
    password: "PLACEHOLDER_MUST_OVERRIDE"  # ✓ Fail-fast placeholder
```

**Detection:**
```bash
grep "password:" charts/sdd-navigator/values.yaml
# Output: password: "MySecretPassword123!" # VIOLATION: plaintext password

# Pattern matching
grep -E "password.*[^PLACEHOLDER]" charts/sdd-navigator/values.yaml
```

**Impact**:
- Credentials exposed in version control
- Security audit trail violation
- Secrets not managed properly
- Violates SCI-HELM-005 requirements

**Security Implications**:
1. Password visible in git history forever
2. Anyone with repo access has DB credentials
3. No rotation without code changes
4. Violates secrets management best practices

**How to Fix:**
```yaml
password: "PLACEHOLDER_MUST_OVERRIDE"  # Deployment fails without --set override
```

**Proper Usage:**
```bash
helm install sdd-navigator charts/sdd-navigator \
  --set postgresql.auth.password="${DB_PASSWORD}"
```

---

### `demo/violation-orphan-req` [TASK-055]

**Requirement**: SCI-TRACE-001 (bidirectional traceability)  
**File Added**: `charts/sdd-navigator/templates/configmap.yaml`

**Violation**: Annotation references non-existent requirement

```yaml
# @req SCI-HELM-005
# @req SCI-NONEXISTENT-999  # ❌ ORPHAN REFERENCE
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "sdd-navigator.fullname" . }}-config
data:
  logLevel: {{ .Values.api.config.logLevel | quote }}
  dbHost: {{ .Values.api.config.dbHost | quote }}
```

**Detection:**
```bash
./scripts/validate-req-references.sh
# Output:
# INVALID charts/sdd-navigator/templates/configmap.yaml: 
#   @req SCI-NONEXISTENT-999 (requirement does not exist)
# Exit Code: 1
```

**Impact**:
- Breaks bidirectional traceability
- Cannot trace requirement → implementation
- Suggests missing requirements documentation
- Creates confusion about requirement source

**How to Fix:**
```yaml
# @req SCI-HELM-005
# Remove orphan reference or add missing requirement to requirements.yaml
apiVersion: v1
kind: ConfigMap
```

---

## Detection Summary

| Branch | Detection Method | Tool | Exit Code | Automation |
|--------|------------------|------|-----------|------------|
| `violation-missing-req` | Scan for @req | `check-traceability.sh` | 1 | ✓ Deterministic |
| `violation-hardcoded-port` | Pattern match | `grep` / manual review | N/A | △ Semi-automated |
| `violation-missing-probe` | Field presence | `grep` / schema validation | 1 | ✓ Deterministic |
| `violation-plaintext-password` | Pattern match | `grep` / secrets scan | 0* | △ Semi-automated |
| `violation-orphan-req` | Cross-reference | `validate-req-references.sh` | 1 | ✓ Deterministic |

*Note: Plaintext password detection requires pattern matching rules, not purely deterministic

---

## Testing All Violations

### Automated (Recommended)
```bash
./scripts/run-demo.sh
```

### Manual Testing
```bash
# Test 1: Missing annotation
git checkout demo/violation-missing-req
./scripts/check-traceability.sh
# Expected: Exit 1, reports missing annotation

# Test 2: Hardcoded port
git checkout demo/violation-hardcoded-port
grep "8080" charts/sdd-navigator/templates/api-service.yaml
# Expected: Lines 12-13 show hardcoded ports

# Test 3: Missing probe
git checkout demo/violation-missing-probe
grep "livenessProbe" charts/sdd-navigator/templates/frontend-deployment.yaml
# Expected: No output (probe missing)

# Test 4: Plaintext password
git checkout demo/violation-plaintext-password
grep "MySecretPassword" charts/sdd-navigator/values.yaml
# Expected: Shows plaintext password

# Test 5: Orphan reference
git checkout demo/violation-orphan-req
./scripts/validate-req-references.sh
# Expected: Exit 1, reports orphan reference

# Return to main
git checkout main
```

---

## CI Pipeline Behavior

When any violation branch is pushed to GitHub:

1. **YAML Lint**: ✓ Passes (syntax correct)
2. **Helm Lint**: ✓ Passes (chart structure valid)
3. **Ansible Lint**: ✓ Passes (playbooks valid)
4. **Check Traceability**: ✗ Fails on missing-req, orphan-req
5. **Validate References**: ✗ Fails on orphan-req
6. **Kubeconform**: ✓ Passes (schema valid)

**Result**: PR blocked, merge prevented

---

## Violation Statistics

```
Total Branches: 6 (1 main + 5 demo)
Total Violations Demonstrated: 5
Detection Methods:
  - Deterministic (automated): 3
  - Semi-automated (patterns): 2
  - Manual review required: 0

Coverage:
  - Traceability violations: 2 (missing, orphan)
  - DRY violations: 1 (hardcoded)
  - Security violations: 1 (plaintext)
  - Health check violations: 1 (missing probe)
```

---

## Requirements Mapping

| Requirement | Violation Branch | Detection | Status |
|-------------|------------------|-----------|--------|
| SCI-TRACE-001 | missing-req, orphan-req | Scripts | ✓ Detected |
| SCI-HELM-001 | missing-probe | Validation | ✓ Detected |
| SCI-HELM-005 | plaintext-password | Pattern | ✓ Detected |
| SCI-HELM-006 | hardcoded-port | Review | ✓ Detected |

---

## Related Documentation

- **[DEMO_QUICKSTART.md](DEMO_QUICKSTART.md)** - 2-minute quick start
- **[DEMO_CI_VALIDATION.md](DEMO_CI_VALIDATION.md)** - Detailed guide
- **[DEMO_SUMMARY.md](DEMO_SUMMARY.md)** - Executive summary
- **[README.md](README.md)** - Documentation index
- **[../requirements.yaml](../requirements.yaml)** - All requirements
- **[../tasks.yaml](../tasks.yaml)** - Task tracking

---

**Last Updated**: 2026-03-15