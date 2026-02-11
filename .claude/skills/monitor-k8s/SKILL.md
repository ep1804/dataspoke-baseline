---
name: monitor-k8s
description: Run a comprehensive health check of the local DataHub/DataSpoke Kubernetes cluster. Use when the user asks about cluster status, pod health, resource capacity, or when troubleshooting deployment issues.
argument-hint: [focus-area]
context: fork
agent: Explore
allowed-tools: Bash(kubectl *), Bash(helm *), Read
---

1. Read `dev_env/.env` for kube context and namespace names.

2. **Verify prerequisites and context**:
```bash
kubectl version --client
kubectl config current-context
kubectl get nodes
```

3. **Run full health checks** in this order:

```bash
# Node health
kubectl get nodes -o custom-columns=\
NAME:.metadata.name,\
STATUS:.status.conditions[-1].type,\
CPU:.status.capacity.cpu,\
MEMORY:.status.capacity.memory
kubectl top nodes 2>/dev/null || echo "metrics-server not available"

# Component status
kubectl get componentstatuses 2>/dev/null

# Pod status — both namespaces
kubectl get pods -n datahub -o wide
kubectl get pods -n dataspoke -o wide 2>/dev/null || echo "dataspoke namespace not found"

# Resource usage
kubectl top pods -n datahub --sort-by=cpu 2>/dev/null
kubectl top pods -n dataspoke 2>/dev/null

# Helm releases
helm list -n datahub
helm list -n dataspoke 2>/dev/null
helm list --all-namespaces --failed 2>/dev/null

# Warning events (both namespaces)
kubectl get events -n datahub --field-selector type=Warning --sort-by='.lastTimestamp' | tail -20
kubectl get events -n dataspoke --field-selector type=Warning --sort-by='.lastTimestamp' 2>/dev/null | tail -20
```

4. **If `$ARGUMENTS` specifies a focus area**, run the troubleshooting workflow from [troubleshooting.md](troubleshooting.md):
   - Find matching pods/releases
   - Show `kubectl describe` output
   - Show logs (last 100 lines)
   - Show helm history and values if it's a release

5. **Output this report**:

```
## Cluster Health Report — <timestamp>

**Context**: <context-name>

### Nodes
| Node | Status | CPU | Memory |
...

### DataHub Namespace
| Pod | Status | Restarts | Age | CPU | Memory |
...

### DataSpoke Namespace
(not yet deployed / pod table)

### Helm Releases
| Release | Chart | Status | Revision | Updated |
...

### Warnings
- <warning events, newest first>

### Resource Pressure
- <any nodes near capacity, pods without limits>

### Summary
✅ / ⚠️ / ❌  <overall status with brief notes and suggested next steps>
```

See [troubleshooting.md](troubleshooting.md) for deep-dive workflows and error reference.
