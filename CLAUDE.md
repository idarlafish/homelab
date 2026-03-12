# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

A personal infrastructure monorepo managing three Hetzner Cloud servers:
- **tools** — k3s cluster (ARM64, cax11) running sleepy-notify, VPN, and content services
- **openclaw** — Docker host (ARM64, cax11) running OpenClaw personal AI assistant
- **game-servers** — k3s cluster (AMD, cpx32) running game servers

```
apps/       - Application source code
  sleepy-notify/  - Telegram notification bot + SvelteKit mini-app
  vpn/            - VPN configuration
  openclaw/       - OpenClaw Docker Compose setup
k8s/        - Kubernetes manifests
  cloudflared/    - Cloudflare Tunnel (tools cluster, public ingress)
  telegram/       - sleepy-notify bot deployment (tools cluster)
  vpn/            - WireGuard (wg-easy) + xray (tools cluster)
  content/        - booklore + komga (tools cluster)
  games/          - Game server manifests (game-servers cluster)
infra/      - OpenTofu (Hetzner Cloud)
  modules/
    hcloud-server/ - Reusable server module (server, network, base firewall)
  tools/          - tools server config (k3s, cax11)
  openclaw/       - openclaw server config (Docker, cax11)
  game-servers/   - game-servers server config (k3s, cpx32)
```

## sleepy-notify App

A Telegram bot + Mini App for scheduling daily recurring notifications. Backend uses BullMQ with Redis for job scheduling (cron-based), GrammY for the Telegram Bot API, and Elysia as the HTTP server. The frontend is a Telegram Mini App (SvelteKit, `@sveltejs/adapter-static`), built and served as static files from `backend/public/`.

**Architecture:**
- User configs stored in Redis under `user:{userId}:schedule`
- Notifications scheduled as BullMQ repeating jobs with cron patterns; jobs are deduplicated by `jobId`
- In production: Telegram webhook at `/telegram-webhook`; in development: long polling
- Cloudflare Tunnel exposes `sleepy-notify.la.fish` → k8s service

### Development

```bash
# Start Redis (required for backend)
cd apps/sleepy-notify && docker compose up redis -d

# Backend (hot reload via bun --watch)
cd apps/sleepy-notify/backend && bun dev

# Frontend (Vite dev server)
cd apps/sleepy-notify/frontend && bun run dev

# Build full app (frontend → backend/public)
cd apps/sleepy-notify && bun run build
```

### Linting

```bash
# Backend (Biome - tabs, double quotes)
cd apps/sleepy-notify/backend && bun run lint
cd apps/sleepy-notify/backend && bun run lint:fix

# Frontend (Prettier + ESLint)
cd apps/sleepy-notify/frontend && bun run lint
cd apps/sleepy-notify/frontend && bun run lint:fix
```

### Production Build / Docker

```bash
# Multi-stage Docker build (ARM64 distroless final image)
cd apps/sleepy-notify && docker compose up -d
```

The Dockerfile compiles the Bun backend to a single binary (`bun build --compile --target bun-linux-arm64`).

## OpenClaw App

A self-hosted personal AI assistant running on the dedicated `openclaw` server via Docker Compose. Connects to Telegram for interaction.

```bash
# Local dev / manual deploy
cp apps/openclaw/.env.example apps/openclaw/.env
# Fill in OPENCLAW_ANTHROPIC_API_KEY, OPENCLAW_TELEGRAM_BOT_TOKEN
cd apps/openclaw && docker compose up -d
```

The `deploy-openclaw-infra` GitHub Actions workflow provisions the server and deploys OpenClaw automatically on push to `infra/openclaw/**`.

## Game Servers

Kubernetes-based game server infrastructure on a dedicated Hetzner CPX32 (AMD, 8 vCPU, 16GB RAM) in `fsn1`. Runs k3s with Hetzner CCM + CSI.

**Games:** Minecraft, Valheim, Palworld, Satisfactory, Enshrouded, Foundry, Core Keeper, V Rising. Each runs in its own namespace with NodePort services.

K8s manifests: `k8s/games/<game>/` (namespace.yaml, configmap.yaml, service.yaml, statefulset.yaml or deployment.yaml).

OpenTofu: `infra/game-servers/` — uses shared `hcloud-server` module. State key: `game-servers/terraform.tfstate`.

When running kubectl for the game-servers cluster, use `KUBECONFIG=.kube/game-servers`.

## Kubernetes (tools cluster)

Manifests in `k8s/` are applied to the `tools` k3s cluster only. The cluster runs on Hetzner `cax11` (ARM64) with Cloudflare Tunnel as the ingress (no Traefik). Services exposed publicly: `sleepy-notify.la.fish`, `wg-admin.la.fish`, `booklore.la.fish`.

Images are pulled from `ghcr.io/idarlafish/` using a `ghcr-secret` pull secret.

## Environment Variables

Copy `.env.example` to `.env` and fill in values. Source with `source .env` before running infrastructure commands. The `.env` file is gitignored.

**Infrastructure (OpenTofu):**
- `S3_ACCESS_KEY`, `S3_SECRET_KEY` — Cloudflare R2 credentials for remote state
- `HCLOUD_TOKEN` — Hetzner Cloud API token
- `HCLOUD_SSH_KEY_NAME`, `GAME_SERVERS_HCLOUD_SSH_KEY_NAME` — SSH key names per environment
- `TOOLS_SERVER_IP` — IP of the tools k3s server

**OpenTofu needs these mapped as:**
- `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` (from `S3_ACCESS_KEY` / `S3_SECRET_KEY`)
- `TF_VAR_hcloud_token` (from `HCLOUD_TOKEN`)
- `TF_VAR_ssh_key_name` (from `HCLOUD_SSH_KEY_NAME` or `GAME_SERVERS_HCLOUD_SSH_KEY_NAME`)

**App-specific (for production deploys):**
- `SLEEPY_BOT_TOKEN`, `SLEEPY_PUBLIC_DOMAIN` — sleepy-notify Telegram bot
- `GHCR_USERNAME`, `GHCR_TOKEN` — GitHub Container Registry
- `WG_EASY_PASSWORD` — WireGuard admin (bcrypt hash)
- `BOOKLORE_MYSQL_ROOT_PASSWORD`, `BOOKLORE_MYSQL_PASSWORD` — Booklore MariaDB
- `CF_TUNNEL_CERT_PATH`, `CF_TUNNEL_CREDENTIALS_PATH` — Cloudflare Tunnel
- `FLUX_TOKEN_PAT` — GitHub PAT for FluxCD

**sleepy-notify local dev** (in `apps/sleepy-notify/backend/.env`):
- `BOT_TOKEN` (required), `REDIS_HOST` (default: localhost), `REDIS_PORT` (default: 6379), `REDIS_PASSWORD`, `PORT` (default: 3000), `API_URL` / `PUBLIC_DOMAIN`

**OpenClaw** (in `apps/openclaw/.env`, see `.env.example`):
- `OPENCLAW_AI_PROVIDER`, `OPENCLAW_ANTHROPIC_API_KEY`, `OPENCLAW_TELEGRAM_BOT_TOKEN`

## Infrastructure (OpenTofu)

Uses OpenTofu (`tofu` CLI, not `terraform`). Three environments share a common `infra/modules/hcloud-server/` module that provisions a server, private network, and base firewall. Each environment adds its own resources on top.

```bash
source .env

# tools server (k3s)
cd infra/tools && tofu init && tofu plan   # State key: tools/terraform.tfstate

# openclaw server (Docker)
cd infra/openclaw && tofu init && tofu plan   # State key: openclaw/terraform.tfstate

# game-servers server (k3s)
cd infra/game-servers && tofu init && tofu plan   # State key: game-servers/terraform.tfstate
```

State stored in Cloudflare R2 bucket `fabler`. Provider: Hetzner Cloud (`hcloud`).

### Module: infra/modules/hcloud-server

Reusable module inputs: `name`, `server_type`, `location`, `ssh_key_id`, `private_ip`, `cloud_init`, `extra_firewall_ids`, `network_ip_range`, `subnet_ip_range`.

Outputs: `server_ip`, `network_id`, `server_id`.

## Commits made by Claude

Do not add Co-Authored-By in the commit message.
