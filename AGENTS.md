# CLAUDE.md

Operational rules and gotchas for this monorepo. See [README.md](README.md) for layout, services, and infra overview. Per-game runbooks live in `k8s/apps/game-servers/<game>/README.md`.

## Hard rules

- **Use `tofu`** (OpenTofu), not `terraform`. tools + tools-staging share `infra/modules/tools-cluster/`. game-servers calls `hcloud-k8s/kubernetes/hcloud` directly. All three clusters run Talos. `infra/r2/` is a separate root for account-scoped R2 buckets (durable, isolated state).
- **all clusters are Talos** — no SSH at the host level (use `talosctl` against `infra/<env>/talosconfig` for OS-level work). Kubeconfigs are written to `infra/<env>/kubeconfig`. `kubectl exec` into pods is fine for runtime debugging.
- **No Traefik / no Ingress on tools** — Cloudflare Tunnel is the only ingress. New services on tools cluster need a Tunnel route in `infra/<env>/main.tf`, not an Ingress.
- **All Hetzner-running clusters are Flux-managed.** Manifests in git are the source of truth. Edit manifest → commit → push → Flux reconciles within 10 min. Never `kubectl scale` / `kubectl edit` Flux-managed resources — they're reverted at the next reconcile.
- **No new `kubectl create secret`.** SOPS-encrypted secrets live with their app under `k8s/apps/.../<name>-secret.yaml`; cluster-shared secrets under `k8s/infrastructure/<cluster>/`. To rotate: `sops <path>`. To create new: see [docs/sops.md](docs/sops.md).
- **PodSecurity baseline is enforced cluster-wide** on Talos. Namespaces hosting privileged workloads (`monitoring` for node-exporter, `vpn` for wg-easy NET_ADMIN) carry `pod-security.kubernetes.io/enforce: privileged` labels.
- **Commits:** never add `Co-Authored-By`.

## Environment

`.env` is gitignored. Copy `.env.example` and `source .env` before running infra commands.

**OpenTofu env var remap (`tofu` doesn't pick these up automatically):**
- `S3_ACCESS_KEY` / `S3_SECRET_KEY` → `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`
- `SOPS_AGE_KEY` → `TF_VAR_sops_age_key`
- For game-servers only: `HCLOUD_TOKEN` → `TF_VAR_hcloud_token`, `GAME_SERVERS_HCLOUD_SSH_KEY_NAME` → `TF_VAR_ssh_key_name`

`AWS_ENDPOINT_URL_S3` is read directly by the S3 backend (no remap) — set it in `.env` to your R2 endpoint so the backend block in `infra/*/provider.tf` doesn't need to hardcode the account ID.

**Tools clusters need `packer`, `talosctl`, `jq` locally** (Talos module dependencies). On macOS: `brew install packer siderolabs/tap/talosctl jq`.

**First-time apply** on a fresh state file requires two phases (the kubernetes/helm providers can't configure against a non-existent cluster):
1. `tofu apply -target='module.cluster.module.talos'` — provisions Talos
2. `tofu apply` — everything else

**Destroying a Talos cluster** requires several `tofu state rm` steps before `tofu destroy`: the lifecycle-protected `talos_machine_secrets`, the K8s/Helm/Talos-API resources that would hang on a dying API, and a Cloudflare Tunnel retry for the connection-active race. Full procedure: [docs/cluster-destroy.md](docs/cluster-destroy.md).

Terraform state lives in Cloudflare R2 bucket `fabler`.

## SOPS

`k8s/.sops.yaml` defines the age recipient and `encrypted_regex` shared between both clusters. The matching private key lives in the `sops-age` Secret in each cluster's `flux-system` namespace. Use sops ≥ 3.12. See [docs/sops.md](docs/sops.md) for encrypt/decrypt setup and gotchas.

## Quick reference

- Per-game runbook (start/stop, RCON, backup, config changes): `k8s/apps/game-servers/<game>/README.md` — minecraft and soulmask have detailed ones.
- Game backup: `KUBECONFIG=infra/game-servers/kubeconfig velero backup create <game>-$(date +%Y%m%d-%H%M%S) --from-schedule <game> --wait` (run while the game pod is up so Velero captures volume data — daily 03:00 UTC schedules also exist but only useful when the game is running).
- Disaster recovery (Velero schedules, restore procedures, full-cluster rebuild): [docs/disaster-recovery.md](docs/disaster-recovery.md).
- Conftest policies (env parity, SOPS, image tags, substitute vars, R2 endpoint): `policy/*.rego`. Run via `conftest test --policy policy/ --combine k8s/clusters/*/resource-set.yaml $(find k8s/apps -name '*.yaml')`.
