# CLAUDE.md

Operational rules and gotchas for this monorepo. See [README.md](README.md) for layout, services, and infra overview. Per-game runbooks live in `k8s/apps/game-servers/<game>/README.md`.

## Hard rules

- **Use `tofu`** (OpenTofu), not `terraform`. tools + tools-staging share `infra/modules/tools-cluster/`. game-servers calls `hcloud-k8s/kubernetes/hcloud` directly. All three clusters run Talos. `infra/r2/` is a separate root for account-scoped R2 buckets (durable, isolated state).
- **tools clusters are Talos** — no SSH at the host level (use `talosctl` against `infra/<env>/talosconfig` for OS-level work). Kubeconfigs are written to `infra/<env>/kubeconfig`. `kubectl exec` into pods is fine for runtime debugging.
- **No Traefik / no Ingress on tools** — Cloudflare Tunnel is the only ingress. New services on tools cluster need a Tunnel route in `infra/<env>/main.tf`, not an Ingress.
- **Both Hetzner-running clusters are Flux-managed.** Manifests in git are the source of truth. Edit manifest → commit → push → Flux reconciles within 10 min. Never `kubectl scale` / `kubectl edit` Flux-managed resources — they're reverted at the next reconcile.
- **No new `kubectl create secret`.** SOPS-encrypted secrets live with their app under `k8s/apps/.../<name>-secret.yaml`; cluster-shared secrets under `k8s/infrastructure/<cluster>/`. To rotate: `sops <path>`. To create new: see [docs/sops.md](docs/sops.md).
- **`infrastructure/base/` is for game-servers (k3s)** — Hetzner CCM/CSI HelmReleases. tools clusters skip `../base` entirely (the Talos module installs CCM/CSI directly via inline manifests).
- **PodSecurity baseline is enforced cluster-wide** on Talos. Namespaces hosting privileged workloads (`monitoring` for node-exporter, `vpn` for wg-easy NET_ADMIN) carry `pod-security.kubernetes.io/enforce: privileged` labels.
- **Commits:** never add `Co-Authored-By`.

## Environment

`.env` is gitignored. Copy `.env.example` and `source .env` before running infra commands.

**OpenTofu env var remap (`tofu` doesn't pick these up automatically):**
- `S3_ACCESS_KEY` / `S3_SECRET_KEY` → `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`
- `SOPS_AGE_KEY` → `TF_VAR_sops_age_key`
- For game-servers only: `HCLOUD_TOKEN` → `TF_VAR_hcloud_token`, `GAME_SERVERS_HCLOUD_SSH_KEY_NAME` → `TF_VAR_ssh_key_name`

**Tools clusters need `packer`, `talosctl`, `jq` locally** (Talos module dependencies). On macOS: `brew install packer siderolabs/tap/talosctl jq`.

**First-time apply** on a fresh state file requires two phases (the kubernetes/helm providers can't configure against a non-existent cluster):
1. `tofu apply -target='module.cluster.module.talos'` — provisions Talos
2. `tofu apply` — everything else

**Destroying a Talos cluster** requires removing lifecycle-protected state first:
```
tofu state rm 'module.cluster.module.talos.talos_machine_secrets.this'
tofu state rm 'module.cluster.module.talos.talos_machine_configuration_apply.control_plane["<name>"]'
```
Plus the in-cluster k8s resources (cloudflared ns/secret, PVs, flux_bootstrap) so the destroy doesn't try to call a dying API. See module README.

Terraform state lives in Cloudflare R2 bucket `fabler`.

## SOPS

`k8s/.sops.yaml` defines the age recipient and `encrypted_regex` shared between both clusters. The matching private key lives in the `sops-age` Secret in each cluster's `flux-system` namespace. Use sops ≥ 3.12. See [docs/sops.md](docs/sops.md) for encrypt/decrypt setup and gotchas.

## Footguns (incident lessons)

- **Flux prune cascade**: a Kustomization with `prune: true` whose source no longer references a previously-managed resource will delete it. Two failure modes hit:
  1. Bootstrap path relocations — stage all child manifests in one commit before `flux bootstrap`.
  2. Cross-Kustomization moves — first commit adds resource to the new Kustomization (Flux re-labels the live object on next reconcile); second commit removes it from the old. See `feedback_flux_prune_cascade_risk.md` memory.
- **Talos in-place server resize requires reboot** to surface new capacity to kubelet. Either reboot manually after the apply, or destroy + apply for true clean install. The reboot also leaves stale `Unknown`/`Error` pods that need force-deleting (kubelet GCs them eventually).
- **Talos/Kube API exposed; mTLS is the only barrier.** We set `firewall_use_current_ipv4 = false` — kube-api (6443) and talos-api (50000) accept connections from any IP, gated by client cert (kubeconfig/talosconfig). Standard managed-K8s posture (GKE/EKS/AKS default). Trade-off: lost the IP-allowlist defense-in-depth, gained no `tofu apply` churn on VPN rotation.
- **CSI uninstall mid-cascade can reformat volumes.** Even with `Retain` reclaim, volumes yanked off the node uncleanly may be reformatted by the CSI driver on next attach. Static PVs (Tofu-owned `kubernetes_persistent_volume_v1` with explicit `volumeHandle`) give the most deterministic recovery.
- **`kubectl scale` on Flux-managed StatefulSets** is reverted within 10 min. Edit the manifest.

## Quick reference

- Per-game runbook (start/stop, RCON, backup, config changes): `k8s/apps/game-servers/<game>/README.md` — minecraft and soulmask have detailed ones.
- Game backup: `KUBECONFIG=infra/game-servers/kubeconfig velero backup create <game>-$(date +%Y%m%d-%H%M%S) --from-schedule <game> --wait` (run while the game pod is up so Velero captures volume data — daily 03:00 UTC schedules also exist but only useful when the game is running).
- Disaster recovery (Velero schedules, restore procedures, full-cluster rebuild): [docs/disaster-recovery.md](docs/disaster-recovery.md).
- Conftest policies (env parity, SOPS, image tags, substitute vars, R2 endpoint): `policy/*.rego`. Run via `conftest test --policy policy/ --combine k8s/clusters/*/resource-set.yaml $(find k8s/apps -name '*.yaml')`.
