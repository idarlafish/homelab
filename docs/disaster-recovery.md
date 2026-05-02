# Disaster recovery

Velero handles application/data backups; Talos etcd snapshots and Tofu handle cluster control plane. Recovery scenarios in increasing order of severity.

## Layers

| Layer | Tool | Source of truth | Restore vector |
|---|---|---|---|
| Cluster control plane (etcd) | `talos-backup` CronJob | `kube-system/talos-backup` | `talosctl etcd recover` |
| Workload manifests + state | Velero | `velero/` namespace, schedules in `k8s/apps/velero/schedules/` | `velero restore create` |
| Cluster config / infra | Tofu | `infra/tools/`, `infra/tools-staging/` | `tofu apply` |
| Backup data store | R2 (Cloudflare) | bucket `<cluster>-backups` prefix `velero/` | independent of cluster |

## Routine: schedules + retention

Per-app Velero Schedules at `k8s/apps/velero/schedules/{paperless,booklore,pocket-id}.yaml` run daily 03:00 UTC with 720h (30d) retention. Each Schedule:
- Captures every namespaced resource in the included namespace
- Runs pre-hooks for app-consistent dumps (paperless: `document_exporter` + `pg_dump`; booklore: `mariadb-dump`; pocket-id: relies on SQLite WAL safety)
- File-system backs the PVC content via Kopia → R2

Inspect from CLI:
```
KUBECONFIG=infra/<cluster>/kubeconfig velero backup get
KUBECONFIG=infra/<cluster>/kubeconfig velero schedule get
```

## Recovery — single namespace, alternate destination (drill-safe)

Restores configmaps/secrets/etc. to a new namespace without touching the live one. Validates backup integrity. Cannot restore PVs because of the static-PV `volumeName` binding.

```
velero restore create drill-$(date +%s) \
  --from-backup <backup-name> \
  --namespace-mappings <ns>:<ns>-restore \
  --include-resources configmaps,secrets \
  --wait

kubectl -n <ns>-restore get all
kubectl delete ns <ns>-restore
```

## Recovery — full namespace, in-place (true DR drill or real incident)

Replaces the live namespace with the backup. Workload offline for the duration.

```
flux suspend kustomization content    # or whichever owns the namespace
kubectl delete ns <ns>
velero restore create incident-$(date +%s) \
  --from-backup <backup-name> \
  --wait
flux resume kustomization content
```

The static PV (`pv-<app>-<role>`) survives the namespace delete (reclaim policy `Retain`); the restored PVC re-binds to it via `volumeName`. Flux resume reapplies any drift.

## Recovery — full cluster gone

Cluster destroyed (region failure, accidental Tofu destroy, etc.). Velero state is in R2, independent of cluster.

```
# 1. Rebuild infra
cd infra/<cluster>
source ../../.env
tofu apply -target='module.cluster.module.talos'   # phase 1
tofu apply                                          # phase 2

# 2. Wait for Flux bootstrap to apply Velero from git (~5 min)
KUBECONFIG=$PWD/kubeconfig flux get kustomizations -A

# 3. Restore each namespace from the latest backup
velero backup get   # find the most recent paperless/booklore/pocket-id backups
velero restore create paperless-recover --from-backup <name> --wait
velero restore create booklore-recover  --from-backup <name> --wait
velero restore create pocket-id-recover --from-backup <name> --wait
```

## Sanity checks

After restore, before declaring success:

- `kubectl -n <ns> get pods` — all Running 1/1
- For paperless: log into UI, verify document count matches pre-incident
- For booklore: book count + library accessible
- For pocket-id: log in via OIDC from a dependent app (e.g., Grafana)

## What Velero does NOT cover

- **Talos machine config** — back up via `talosctl gen secrets` periodically; store offline
- **etcd state** — covered by `kube-system/talos-backup` hourly CronJob
- **R2 itself** — single point of failure for backups. Cross-account replication or local clone is a separate concern
- **External service state** — Cloudflare DNS records, pocket-id user accounts inside the IdP (the *data* is captured via PVC; rebuilding the IdP is part of pocket-id namespace restore)

## Related

- Tofu apply order on fresh state: see `CLAUDE.md` ("First-time apply").
- SOPS rotation: `docs/sops.md`.
