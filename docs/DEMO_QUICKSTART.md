# CI Validation Demo - Quick Start

**Purpose**: Quick reference for testing violation detection in CI pipeline  
**Time Required**: ~2 minutes  
**Requirements**: bash, git, grep

---

## One-Line Demo

```bash
./scripts/run-demo.sh
```

Expected: All 5 violations detected, script exits with code 0

---

## Manual Testing

### 1. Missing @req Annotation
```bash
git checkout demo/violation-missing-req
./scripts/check-traceability.sh
# Expected: ✗ 1 file(s) missing @req annotations
```

### 2. Hardcoded Port (DRY Violation)
```bash
git checkout demo/violation-hardcoded-port
grep -n "8080" charts/sdd-navigator/templates/api-service.yaml
# Expected: Lines 12-13 show hardcoded ports
```

### 3. Missing Liveness Probe
```bash
git checkout demo/violation-missing-probe
grep "livenessProbe" charts/sdd-navigator/templates/frontend-deployment.yaml
# Expected: No output (probe missing)
```

### 4. Plaintext Password
```bash
git checkout demo/violation-plaintext-password
grep "password:" charts/sdd-navigator/values.yaml
# Expected: Shows "MySecretPassword123!" instead of PLACEHOLDER
```

### 5. Orphan @req Reference
```bash
git checkout demo/violation-orphan-req
./scripts/validate-req-references.sh
# Expected: ✗ 1 invalid @req reference(s) found (SCI-NONEXISTENT-999)
```

### Return to Main
```bash
git checkout main
```

---

## Verify Main Branch Passes

```bash
git checkout main

# All checks should pass:
./scripts/check-traceability.sh        # Exit 0
./scripts/validate-req-references.sh   # Exit 0
yamllint .                             # Exit 0
helm lint charts/sdd-navigator         # Exit 0
ansible-lint ansible/                  # Exit 0
```

---

## Branch Summary

| Branch | File Changed | Violation | Detection |
|--------|--------------|-----------|-----------|
| `demo/violation-missing-req` | `api-deployment.yaml` (new) | No @req | check-traceability.sh |
| `demo/violation-hardcoded-port` | `api-service.yaml` (new) | Port 8080 hardcoded | grep/manual |
| `demo/violation-missing-probe` | `frontend-deployment.yaml` (new) | No health checks | grep/validation |
| `demo/violation-plaintext-password` | `values.yaml` (modified) | Real password | grep/pattern |
| `demo/violation-orphan-req` | `configmap.yaml` (new) | @req SCI-NONEXISTENT-999 | validate-req-references.sh |

---

## What This Demonstrates

✓ **Traceability Enforcement** - Missing and invalid @req caught automatically  
✓ **DRY Validation** - Hardcoded values detected (manual review still needed)  
✓ **Security** - Plaintext credentials caught by pattern matching  
✓ **Health Checks** - Missing probes violate requirements  
✓ **Deterministic CI** - Same violations always caught the same way

---

## Full Documentation

See `docs/DEMO_CI_VALIDATION.md` for:
- Detailed explanation of each violation
- Expected CI behavior
- How to fix violations
- Integration with GitHub Actions workflow

---

**Ready to demonstrate? Run: `./scripts/run-demo.sh`**