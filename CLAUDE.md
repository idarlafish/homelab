# CLAUDE.md

Guidance for Claude Code when working in this repository. See [README.md](README.md) for the high-level overview, machine inventory, directory layout, and app architecture.

## sleepy-notify App

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

## Game Servers

Kubernetes-based game server infrastructure on a dedicated Hetzner CX43 (Intel, 8 shared vCPU, 16 GB RAM, 160 GB disk) in `fsn1`. Runs k3s with Hetzner CCM + CSI.

**Games:** Minecraft, Valheim, Palworld, Satisfactory, Enshrouded, Foundry, Core Keeper, V Rising. Each runs in its own namespace with NodePort services.

K8s manifests: `k8s/games/<game>/` (namespace.yaml, configmap.yaml, service.yaml, statefulset.yaml or deployment.yaml).

OpenTofu: `infra/game-servers/` — uses shared `hcloud-server` module. State key: `game-servers/terraform.tfstate`.

When running kubectl for the game-servers cluster, use `KUBECONFIG=.kube/game-servers`.

### Backups

Game server world data is backed up to Cloudflare R2 (`s3://fabler/backups/game-servers/<game>/`). Each game has a `backup-job.yaml` that runs as a k8s Job — requires the game to be scaled to 0 first (RWO volumes).

```bash
# Backup a game (scales down, backs up, scales back up)
./scripts/backup-game.sh minecraft

# One-time setup per game namespace (r2-credentials secret)
source .env && KUBECONFIG=.kube/game-servers kubectl create secret generic r2-credentials \
  -n <game> --from-literal=access-key-id="$S3_ACCESS_KEY" \
  --from-literal=secret-access-key="$S3_SECRET_KEY"
```

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

## Infrastructure (OpenTofu)

Uses OpenTofu (`tofu` CLI, not `terraform`). Two environments share a common `infra/modules/hcloud-server/` module that provisions a server, private network, and base firewall. Each environment adds its own resources on top.

```bash
source .env

# tools server (k3s)
cd infra/tools && tofu init && tofu plan   # State key: tools/terraform.tfstate

# game-servers server (k3s)
cd infra/game-servers && tofu init && tofu plan   # State key: game-servers/terraform.tfstate
```

State stored in Cloudflare R2 bucket `fabler`. Provider: Hetzner Cloud (`hcloud`).

### Module: infra/modules/hcloud-server

Reusable module inputs: `name`, `server_type`, `location`, `ssh_key_id`, `private_ip`, `cloud_init`, `extra_firewall_ids`, `network_ip_range`, `subnet_ip_range`.

Outputs: `server_ip`, `network_id`, `server_id`.

## Commits made by Claude

Do not add Co-Authored-By in the commit message.
