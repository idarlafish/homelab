# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

A personal infrastructure monorepo managing a Hetzner Cloud Kubernetes cluster (ARM64, k3s). Contains the `sleepy-notify` Telegram bot/mini-app, VPN configs, and Terraform infrastructure.

```
apps/       - Application source code
  sleepy-notify/  - Telegram notification bot + SvelteKit mini-app
  vpn/            - VPN configuration
k8s/        - Kubernetes manifests
  cloudflared/    - Cloudflare Tunnel (public ingress)
  telegram/       - sleepy-notify bot deployment
  vpn/            - WireGuard (wg-easy) + xray
  content/        - booklore
infra/      - Terraform (Hetzner Cloud)
  prod/           - Production server config
  staging/        - Staging environment
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

Backend requires env vars: `BOT_TOKEN`, `REDIS_HOST`, `REDIS_PORT`, `REDIS_PASSWORD`, `PORT`, `API_URL`/`PUBLIC_DOMAIN`.

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

## Kubernetes

Manifests are applied directly to the k3s cluster. The cluster runs on Hetzner `cax11` (ARM64) with Cloudflare Tunnel as the ingress (no Traefik). Services exposed publicly: `sleepy-notify.la.fish`, `wg-admin.la.fish`, `booklore.la.fish`.

Images are pulled from `ghcr.io/idarlafish/` using a `ghcr-secret` pull secret.

## Infrastructure (Terraform)

```bash
cd infra/prod
terraform init   # Uses Cloudflare R2 as remote state backend
terraform plan
terraform apply
```

Provider: Hetzner Cloud (`hcloud`). State stored in Cloudflare R2 bucket `fabler`.
