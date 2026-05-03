# Destroying a Talos cluster

`tofu destroy` cannot just run as-is against the tools clusters. Three classes of resources block or hang it:

1. **Lifecycle-protected** state (the upstream Talos module sets `prevent_destroy = true` on `talos_machine_secrets`).
2. **State entries that call the Kubernetes/Talos API** on nodes that are simultaneously being destroyed (race ⇒ destroy hangs with `context deadline exceeded`).
3. **Cloudflare Tunnel** keeps a connection registry — deleting the tunnel itself fails for ~60–120 s after the nodes go away.

The procedure below works around all three. The state-removal step is **pattern-based**, so it stays correct as you add or remove apps.

> **Pre-flight**: confirm `cluster_delete_protection = false` in `infra/<env>/main.tf` (it defaults to `true` to prevent accidents). Source `.env` and apply the env-var remap from [CLAUDE.md](../CLAUDE.md#environment).

```sh
source .env
export TF_VAR_sops_age_key="$SOPS_AGE_KEY"
export AWS_ACCESS_KEY_ID="$S3_ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="$S3_SECRET_KEY"
ENV=tools-staging   # or tools, game-servers
```

## 1. Sanity check

```sh
tofu -chdir=infra/$ENV plan -destroy 2>&1 | grep "Plan:"
```

Expect `Plan: 0 to add, 0 to change, N to destroy`. If `cluster_delete_protection` is still `true`, fix it and re-apply before continuing.

## 2. Orphan-remove API-dependent state (pattern-based)

Anything that talks to the Kubernetes or Talos API of the dying cluster needs to leave Tofu state before destroy, otherwise destroy hangs once the nodes are gone. We also bypass the lifecycle-protected `talos_machine_secrets` here.

The regex below matches every category that needs removal — Kubernetes provider resources, Helm releases, `flux_bootstrap.*`, and the four Talos-API-coupled resources. It auto-covers any new PV / Secret / namespace you add later (e.g., a future `kubernetes_persistent_volume_v1.<your-app>_data`).

```sh
tofu -chdir=infra/$ENV state list \
  | grep -E '(^|\.)(kubernetes_[^.]+|helm_release)\.|module\.flux_bootstrap\.|(^|\.)talos_machine_(secrets|configuration_apply|bootstrap)|(^|\.)talos_cluster_kubeconfig' \
  | xargs -t -n1 tofu -chdir=infra/$ENV state rm
```

The `(^|\.)` anchor catches both **root-level** resources (e.g. `kubernetes_persistent_volume_v1.pocket_id_data` declared in `infra/tools/volumes.tf`) and **module-nested** ones (e.g. `module.cluster.kubernetes_namespace_v1.cloudflared` declared in the shared module). Without it, root-level entries are silently missed.

What this matches and why:

| Matches | Reason for orphan-rm |
|---|---|
| `*.kubernetes_namespace_v1.*`, `*.kubernetes_secret_v1.*`, `*.kubernetes_config_map_v1.*`, `*.kubernetes_persistent_volume_v1.*` | Calls K8s API; hangs once cluster is gone |
| `*.helm_release.*` (under `module.flux_bootstrap`) | Calls K8s/Helm API |
| `*.module.flux_bootstrap.*` | Whole bootstrap chain — same |
| `*.talos_machine_secrets.this` | `lifecycle.prevent_destroy = true` (upstream module) |
| `*.talos_machine_configuration_apply.{control_plane,worker}[*]` | Calls Talos API on the dying node |
| `*.talos_machine_bootstrap.this` | Calls Talos API |
| `*.talos_cluster_kubeconfig.this` | Calls K8s API |

**Verify after**:

```sh
tofu -chdir=infra/$ENV state list \
  | grep -cE '(^|\.)(kubernetes_[^.]+|helm_release)\.|module\.flux_bootstrap\.|(^|\.)talos_machine_(secrets|configuration_apply|bootstrap)|(^|\.)talos_cluster_kubeconfig'
# expect: 0
```

What's deliberately **not** matched (these get destroyed normally via their providers' APIs, no K8s/Talos coupling):

- `hcloud_*` — Hetzner Cloud (servers, network, firewall, volume, etc.)
- `cloudflare_*` — Cloudflare (tunnel, DNS, certs)
- `talos_image_factory_*` — Sidero Image Factory (no cluster API)
- `talos_machine_configuration` (data source), `talos_client_configuration` (data source) — read-only
- `tls_*`, `random_*`, `terraform_data.*` — local-only state

## 3. Destroy

```sh
tofu -chdir=infra/$ENV destroy
```

The first run usually fails on the Cloudflare tunnel:

```
This tunnel has active connections. Please stop all cloudflared
replicas, or wait a few minutes for connections to close, then try again.
```

Cloudflare's edge hasn't yet noticed the nodes are gone. **Just retry every ~60 s until it succeeds** (typically 1–2 retries). Tofu destroys are idempotent.

A scripted retry loop:

```sh
until tofu -chdir=infra/$ENV destroy -auto-approve; do
  echo "destroy retrying in 60s..."
  sleep 60
done
```

## 4. Verify

```sh
# state empty (or just data-source residue)
tofu -chdir=infra/$ENV state list | wc -l   # → 0

# Hetzner Cloud Console: zero <env>-prefixed servers / volumes / networks / firewalls
# Cloudflare DNS: no <env>-* records
```

## 5. Local cleanup (optional)

The kubeconfig and talosconfig in `infra/$ENV/` reference a dead cluster.

```sh
rm -f infra/$ENV/{kubeconfig,kubeconfig.bak,talosconfig,talosconfig.bak}
```

Keep `infra/$ENV/*.tf` and `k8s/clusters/$ENV/*.yaml` — they're the recipe to recreate. The Tofu state file in R2 (`fabler` bucket) stays in place; it's now valid-but-empty.

## To recreate the cluster

Two-phase apply per [CLAUDE.md](../CLAUDE.md#environment):

```sh
cd infra/$ENV
tofu apply -target='module.cluster.module.talos'   # phase 1: provision Talos
tofu apply                                          # phase 2: everything else
```
