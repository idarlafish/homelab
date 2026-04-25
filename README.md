# tools

Personal infrastructure monorepo. Manages Hetzner Cloud servers using OpenTofu + k3s.

## Machines

| Machine | Type | Runtime | Purpose |
|---|---|---|---|
| `tools` | cax11 (ARM64) | k3s | sleepy-notify bot, VPN, content services |
| `game-servers` | cx43 (Intel) | k3s | Game server cluster |

## Structure

```
apps/                              # source code (NOT k8s manifests — see k8s/ for those)
  sleepy-notify/                   # Telegram bot + SvelteKit Mini App
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
    hcloud-server/                 # Reusable Hetzner server Terraform module
  tools/                           # tools server (k3s bootstrap)
  game-servers/                    # game-servers server (k3s bootstrap)
```

See [CLAUDE.md](CLAUDE.md) for the operating model: how to start/stop a game, add a SOPS secret, run a backup, and avoid the Flux prune cascade.

## Services

- `sleepy-notify.la.fish` — Telegram bot web app
- `booklore.la.fish` — Booklore e-book manager
- `prometheus.la.fish` — tools-cluster Prometheus (game-servers metrics-collector ships here)
- ~~`wg-admin.la.fish`~~ — WireGuard parked: PVC was on `local-path` SC and lost during the multi-cluster Flux refactor; configs need to be regenerated before re-enabling. See `k8s/apps/tools/vpn/wg-easy/`.

### sleepy-notify architecture

A Telegram bot + Mini App for scheduling daily recurring notifications. Backend is [GramIO](https://gramio.dev/) (Telegram Bot API) + [Elysia](https://elysiajs.com/) (HTTP) + [BullMQ](https://docs.bullmq.io/) (Redis-backed cron jobs), compiled to a single Bun binary. Frontend is a Telegram Mini App (SvelteKit, `@sveltejs/adapter-static`), built into `backend/public/` and served by the backend.

- User configs stored in Redis under `user:{userId}:schedule`
- Notifications are BullMQ repeating jobs with cron patterns; jobs deduplicated by `jobId`
- Production: Telegram webhook at `/telegram-webhook`; local dev: long polling
- Cloudflare Tunnel exposes `sleepy-notify.la.fish` → k8s service on the `tools` cluster

## CI/CD

| Workflow | Trigger |
|---|---|
| `deploy-tools-infra` | push to `infra/tools/**` or `infra/modules/**` (re-runs `flux bootstrap` against `k8s/clusters/tools`) |
| `deploy-game-servers-infra` | push to `infra/game-servers/**` or `infra/modules/**` |
| `deploy-sleepy-notify` | push to `apps/sleepy-notify/**` |
| `cleanup` | manual (choose `tools` or `game-servers`) |

**Most app/manifest changes don't need CI** — Flux watches `main` and reconciles directly. Only Tofu / image-build changes go through GitHub Actions.

## Local sleepy-notify deploy (no registry)

To deploy `sleepy-notify` from your Mac without publishing an image:

```bash
export TOOLS_SERVER_IP=<tools server IP> # same value used in GitHub Actions
./scripts/deploy-sleepy-notify-local.sh  # builds, imports into k3s, and rolls out
```

This builds the image locally, streams it directly into k3s via `k3s ctr images import`, and updates the `sleepy-notify-bot` deployment image tag. The deployment manifest now uses `imagePullPolicy: IfNotPresent`, so k3s will prefer the locally imported image and only pull from GHCR when no local image exists (e.g. on a fresh cluster).

## Infrastructure

Terraform state stored in Cloudflare R2 bucket `fabler`:
- `tools/terraform.tfstate`
- `game-servers/terraform.tfstate`
