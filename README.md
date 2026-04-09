# tools

Personal infrastructure monorepo. Manages Hetzner Cloud servers using OpenTofu + k3s.

## Machines

| Machine | Type | Runtime | Purpose |
|---|---|---|---|
| `tools` | cax11 (ARM64) | k3s | sleepy-notify bot, VPN, content services |
| `game-servers` | cx43 (Intel) | k3s | Game server cluster |

## Structure

```
apps/
  sleepy-notify/   Telegram bot + SvelteKit Mini App
  vpn/             VPN configuration
k8s/               Kubernetes manifests
  cloudflared/     Cloudflare Tunnel ingress (tools)
  telegram/        sleepy-notify deployment (tools)
  vpn/             WireGuard (wg-easy) + xray (tools)
  content/         booklore + komga (tools)
  games/           Game server manifests (game-servers)
infra/
  modules/
    hcloud-server/ Reusable Hetzner server Terraform module
  tools/           tools server (k3s bootstrap)
  game-servers/    game-servers server (k3s bootstrap)
```

## Services

- `sleepy-notify.la.fish` — Telegram bot web app
- `wg-admin.la.fish` — WireGuard VPN admin UI
- `booklore.la.fish` — Booklore e-book manager

### sleepy-notify architecture

A Telegram bot + Mini App for scheduling daily recurring notifications. Backend is [GramIO](https://gramio.dev/) (Telegram Bot API) + [Elysia](https://elysiajs.com/) (HTTP) + [BullMQ](https://docs.bullmq.io/) (Redis-backed cron jobs), compiled to a single Bun binary. Frontend is a Telegram Mini App (SvelteKit, `@sveltejs/adapter-static`), built into `backend/public/` and served by the backend.

- User configs stored in Redis under `user:{userId}:schedule`
- Notifications are BullMQ repeating jobs with cron patterns; jobs deduplicated by `jobId`
- Production: Telegram webhook at `/telegram-webhook`; local dev: long polling
- Cloudflare Tunnel exposes `sleepy-notify.la.fish` → k8s service on the `tools` cluster

## CI/CD

| Workflow | Trigger |
|---|---|
| `deploy-tools-infra` | push to `infra/tools/**` or `infra/modules/**` |
| `deploy-game-servers-infra` | push to `infra/game-servers/**` or `infra/modules/**` |
| `deploy-sleepy-notify` | push to `apps/sleepy-notify/**` |
| `cleanup` | manual (choose `tools` or `game-servers`) |

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
