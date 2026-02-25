---
name: monitor-k8s
description: Run a comprehensive monitoring of local development cluster. Use when developing and testing kubernetes scripts and helm charts based on the local cluster. Use when installing or uninstalling the local cluster.
argument-hint: [focus-area]
context: fork
agent: general-purpose
allowed-tools: Bash(kubectl *), Bash(helm *), Bash(minikube *), Bash(sleep *), Bash(date *), Read
---

1. Read `dev_env/.env` for kube context and namespace names:
   - `DATASPOKE_DEV_KUBE_CLUSTER` — kube context (e.g., `docker-desktop`)
   - `DATASPOKE_DEV_KUBE_DATAHUB_NAMESPACE` — DataHub namespace (e.g., `datahub-01`)
   - `DATASPOKE_DEV_KUBE_DATASPOKE_NAMESPACE` — DataSpoke namespace (e.g., `dataspoke-01`)
   - `DATASPOKE_DEV_KUBE_DUMMY_DATA_NAMESPACE` — Example sources namespace (e.g., `dummy-data1`)

   **Use these variable values in all kubectl/helm commands below.** Do NOT hardcode namespace names.

2. **Verify prerequisites and context**:
```bash
kubectl version --client
kubectl config current-context
kubectl get nodes
```

3. **Run full health checks** in this order (substitute `$NS_DH`, `$NS_DS`, `$NS_EX` with the namespace names from `.env`):

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

# Pod status — all three namespaces
kubectl get pods -n $NS_DH -o wide
kubectl get pods -n $NS_DS -o wide 2>/dev/null || echo "$NS_DS namespace not found or empty"
kubectl get pods -n $NS_EX -o wide 2>/dev/null || echo "$NS_EX namespace not found or empty"

# PVC status
kubectl get pvc -n $NS_DH 2>/dev/null
kubectl get pvc -n $NS_DS 2>/dev/null
kubectl get pvc -n $NS_EX 2>/dev/null

# Resource usage
kubectl top pods -n $NS_DH --sort-by=cpu 2>/dev/null
kubectl top pods -n $NS_DS --sort-by=cpu 2>/dev/null
kubectl top pods -n $NS_EX 2>/dev/null

# Helm releases
helm list -n $NS_DH
helm list -n $NS_DS 2>/dev/null
helm list --all-namespaces --failed 2>/dev/null

# Warning events (all namespaces)
kubectl get events -n $NS_DH --field-selector type=Warning --sort-by='.lastTimestamp' | tail -20
kubectl get events -n $NS_DS --field-selector type=Warning --sort-by='.lastTimestamp' 2>/dev/null | tail -20
kubectl get events -n $NS_EX --field-selector type=Warning --sort-by='.lastTimestamp' 2>/dev/null | tail -20
```

4. **If `$ARGUMENTS` specifies a focus area**, run the troubleshooting workflow from [troubleshooting.md](troubleshooting.md):
   - Find matching pods/releases
   - Show `kubectl describe` output
   - Show logs (last 100 lines)
   - Show helm history and values if it's a release

5. **Active monitoring during installation or modification**: When any pod is not fully ready (e.g., `0/1 Running`, `Init`, `Pending`, `CrashLoopBackOff`) or any Helm release is in `pending-install`/`pending-upgrade`, you MUST poll repeatedly. Do NOT just collect a one-time snapshot and return.

   **Polling procedure** — repeat up to 15 iterations (total ~5 minutes):
   a. `sleep 20` (wait 20 seconds between checks)
   b. `kubectl get pods -n $NS_DH` to get current pod status
   c. For each pod that is NOT ready (Ready != True, or status != Running/Completed):
      - `kubectl logs <pod-name> -n $NS_DH --tail=15` to see latest log output
      - If pod is in `Pending` or `Init*`, run `kubectl describe pod <pod-name> -n $NS_DH | tail -20` for events
   d. `helm list -n $NS_DH --all` to check release status
   e. Note the progress since last check (e.g., "system-update: now loading plugins...", "GMS: readiness probe passing")

   **Stop conditions** — exit the loop early when ANY of these are true:
   - All running pods show `Ready` and all jobs show `Completed`
   - A pod enters `CrashLoopBackOff` with 3+ restarts (report the error and stop)
   - A pod is stuck in `Error` or `OOMKilled` (report and stop)

   **IMPORTANT**: Each iteration must sleep ≤25 seconds and make at least one `kubectl` call — the user expects incremental progress updates, not a single final report.

6. **Output this report**:

```
## Cluster Health Report — <timestamp>

**Context**: <context-name>

### Nodes
| Node | Status | CPU | Memory |
...

### DataHub Namespace ($NS_DH)
| Pod | Status | Restarts | Age | CPU | Memory |
...

### DataSpoke Namespace ($NS_DS)
(not yet deployed / pod table)

### Example Sources Namespace ($NS_EX)
| Pod | Status | Restarts | Age | CPU | Memory |
...

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
