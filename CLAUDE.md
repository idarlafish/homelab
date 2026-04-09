# CLAUDE.md

Guidance for Claude Code. See [README.md](README.md) for overview, machine inventory, directory layout, and app architecture.

## Rules (read first)

- **Use `tofu`** (OpenTofu), not `terraform`. Both environments share `infra/modules/hcloud-server/`; read that module before changing either caller.
- **Two clusters, two kubeconfigs — never mix them:**
  - `tools` → `KUBECONFIG=.kube/config`
  - `game-servers` → `KUBECONFIG=.kube/game-servers`
- **`tools` is ARM64** (Hetzner cax11) — k8s manifests and images for that cluster need `arm64`. **`game-servers` is Intel/amd64** (cx43).
- **No Traefik / no Ingress resources** on tools — Cloudflare Tunnel is the only ingress. Expose services via `Service` + a tunnel route.
- **Images come from `ghcr.io/idarlafish/`** using the `ghcr-secret` pull secret. Reference it as `imagePullSecrets: [{name: ghcr-secret}]` in every deployment that pulls a private image, **and** create the secret per-namespace (image pull secrets are namespace-scoped, not cluster-scoped) with:
  ```
  kubectl create secret docker-registry ghcr-secret -n <ns> \
    --docker-server=ghcr.io --docker-username="$GHCR_USERNAME" --docker-password="$GHCR_TOKEN"
  ```
- **Commits:** never add `Co-Authored-By`.

## Environment

`.env` is gitignored. Copy `.env.example` and `source .env` before running infra commands. See that file for the full list of variables.

**OpenTofu gotcha — env vars must be remapped before running `tofu`:**

- `S3_ACCESS_KEY` / `S3_SECRET_KEY` → `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`
- `HCLOUD_TOKEN` → `TF_VAR_hcloud_token`
- `HCLOUD_SSH_KEY_NAME` (or `GAME_SERVERS_HCLOUD_SSH_KEY_NAME`) → `TF_VAR_ssh_key_name`

Terraform state lives in Cloudflare R2 bucket `fabler` under keys `tools/terraform.tfstate` and `game-servers/terraform.tfstate`.

## Commands

### sleepy-notify (dev)

```bash
cd apps/sleepy-notify && docker compose up redis -d  # start Redis
cd apps/sleepy-notify/backend  && bun dev            # backend (hot reload)
cd apps/sleepy-notify/frontend && bun run dev        # frontend (Vite)
cd apps/sleepy-notify && bun run build               # full build → backend/public
```

Lint with `bun run lint` / `bun run lint:fix` inside each of `backend/` (Biome) and `frontend/` (Prettier + ESLint). Don't manually enforce style — let the linter do it.

### OpenTofu

```bash
source .env
cd infra/tools        && tofu init && tofu plan
cd infra/game-servers && tofu init && tofu plan
```

### Game-server backups

```bash
./scripts/backup-game.sh <game>   # scales to 0, backs up to R2, scales back up
```

See `k8s/games/minecraft/README.md` for the model runbook pattern — replicate it for other games as needed.
