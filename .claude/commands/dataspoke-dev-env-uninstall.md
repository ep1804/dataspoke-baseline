Tear down the local DataSpoke development environment.

## Step 1 — Load configuration

1. Read `dev_env/.env` to get namespace names and cluster context.
2. If `.env` does not exist, ask the user for the cluster context and namespace names.

## Step 2 — Show current state

1. Show what is currently deployed:
   - `helm list` across all dev_env namespaces
   - `kubectl get all` in each namespace
   - `kubectl get pvc` in each namespace
2. **Ask the user to confirm** they want to remove all dev_env resources before proceeding.

## Step 3 — Uninstall

1. **Ask the user** whether to also delete the namespaces and their PVCs (in addition to removing Helm releases and workloads).
2. Execute the top-level uninstall script with flags based on the user's answer:
   - Always pass `--yes` (user already confirmed in Step 2).
   - If user wants namespace deletion, also pass `--delete-namespaces`: `bash dev_env/uninstall.sh --yes --delete-namespaces`
   - Otherwise: `bash dev_env/uninstall.sh --yes`
   - If the uninstall script does not exist or fails, fall back to manual teardown:
     a. Run `dev_env/dataspoke-example/uninstall.sh` (or `kubectl delete -f dev_env/dataspoke-example/manifests/`)
     b. Run `dev_env/datahub/uninstall.sh` (or `helm uninstall` the datahub and datahub-prerequisites releases)
3. Clean up any orphaned PersistentVolumes in `Released` state that were bound to dev_env PVCs.

## Step 4 — Verify

1. Confirm namespaces are gone (or cleaned, if user chose to keep them).
2. Confirm no orphaned PVs remain.
3. Use `/monitor-k8s` to do a final cluster health check and report the clean state.
