# tools

Personal infrastructure monorepo. Manages two Hetzner Cloud ARM64 servers using Terraform + k3s/Docker.

## Machines

| Machine | Type | Runtime | Purpose |
|---|---|---|---|
| `tools` | cax11 (ARM64) | k3s | sleepy-notify bot, VPN, content services |
| `openclaw` | cax11 (ARM64) | Docker | OpenClaw personal AI assistant |

## Structure

```
apps/
  sleepy-notify/   Telegram bot + SvelteKit Mini App
  openclaw/        OpenClaw Docker Compose setup
  vpn/             VPN configuration
k8s/               Kubernetes manifests (tools cluster)
  cloudflared/     Cloudflare Tunnel ingress
  telegram/        sleepy-notify deployment
  vpn/             WireGuard (wg-easy) + xray
  content/         booklore + komga
infra/
  modules/
    hcloud-server/ Reusable Hetzner server Terraform module
  tools/           tools server (k3s bootstrap)
  openclaw/        openclaw server (Docker install)
```

## Services

- `sleepy-notify.la.fish` — Telegram bot web app
- `wg-admin.la.fish` — WireGuard VPN admin UI
- `booklore.la.fish` — Booklore e-book manager

## CI/CD

| Workflow | Trigger |
|---|---|
| `deploy-tools-infra` | push to `infra/tools/**` or `infra/modules/**` |
| `deploy-openclaw-infra` | push to `infra/openclaw/**` or `infra/modules/**` |
| `deploy-sleepy-notify` | push to `apps/sleepy-notify/**` |
| `cleanup` | manual (choose `tools` or `openclaw`) |

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
- `openclaw/terraform.tfstate`
