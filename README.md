# tools

Personal infrastructure monorepo. Manages Hetzner Cloud servers using OpenTofu + k3s.

## Machines

| Machine | Type | Runtime | Purpose |
|---|---|---|---|
| `tools` | cax11 (ARM64) | k3s | VPN, content services, monitoring, Cloudflared tunnel |
| `game-servers` | cx43 (Intel) | k3s | Game server cluster |

## Structure

```
apps/                              # source code (NOT k8s manifests — see k8s/ for those)
  vpn/                             # VPN configuration

k8s/                               # GitOps tree, both clusters managed by Flux
  clusters/
    tools/                         # tools cluster Flux bootstrap (--path=k8s/clusters/tools)
    game-servers/                  # game-servers cluster Flux bootstrap
  apps/
    tools/                         # cloudflared, content/booklore, monitoring stack, telegram, vpn
    game-servers/                  # 9 games (default replicas: 0) + Grafana Alloy metrics agent
  infrastructure/
    base/                          # shared by both clusters: hcloud HelmRepository, hetzner-csi, hetzner-ccm, coredns-patch
    tools/                         # tools-only: prometheus-community, monitoring namespace
    game-servers/                  # overlay (just inherits ../base for now)
  secrets/
    .sops.yaml                     # SOPS config — recipient + encrypted_regex
    tools/                         # SOPS-encrypted secrets for tools workloads
    game-servers/                  # SOPS-encrypted secrets for game workloads

infra/
  modules/
    tools-cluster/                 # tools + tools-staging shared module (Talos via hcloud-k8s)
  tools/                           # tools cluster (Talos)
  tools-staging/                   # tools-staging cluster (Talos)
  game-servers/                    # game-servers cluster (Talos, calls hcloud-k8s directly)
  r2/                              # account-scoped R2 backup buckets
```

See [CLAUDE.md](CLAUDE.md) for the operating model: how to start/stop a game, add a SOPS secret, run a backup, and avoid the Flux prune cascade.

## Services

- `booklore.la.fish` — Booklore e-book manager
- `prometheus.la.fish` — tools-cluster Prometheus (game-servers metrics-collector ships here)
- `grafana.la.fish` — Grafana dashboards
- ~~`wg-admin.la.fish`~~ — WireGuard parked: PVC was on `local-path` SC and lost during the multi-cluster Flux refactor; configs need to be regenerated before re-enabling. See `k8s/apps/tools/vpn/wg-easy/`.

> The Telegram reminder bot (formerly `sleepy-notify`, deployed here) was extracted to its own repo and now runs as a Cloudflare Worker — see [idarlafish/telegram-notify](https://github.com/idarlafish/telegram-notify).

## CI/CD

| Workflow | Trigger |
|---|---|
| `deploy-tools-infra` | manual (re-runs `flux bootstrap` against `k8s/clusters/tools`) |
| `deploy-game-servers-infra` | manual (re-runs `flux bootstrap` against `k8s/clusters/game-servers`) |
| `cleanup` | manual (choose `tools` or `game-servers`) |

**Most app/manifest changes don't need CI** — Flux watches `main` and reconciles directly. Only Tofu / cluster-bootstrap changes go through GitHub Actions.

## Infrastructure

Terraform state stored in Cloudflare R2 bucket `fabler`:
- `tools/terraform.tfstate`
- `game-servers/terraform.tfstate`
