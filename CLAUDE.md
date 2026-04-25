# CLAUDE.md

Guidance for Claude Code. See [README.md](README.md) for overview, machine inventory, and app architecture.

## Rules (read first)

- **Use `tofu`** (OpenTofu), not `terraform`. Both environments share `infra/modules/hcloud-server/`; read that module before changing either caller.
- **Two clusters, two kubeconfigs — never mix them:**
  - `tools` → `KUBECONFIG=.kube/config`
  - `game-servers` → `KUBECONFIG=.kube/game-servers`
- **`tools` is ARM64** (Hetzner cax11) — k8s manifests and images for that cluster need `arm64`. **`game-servers` is Intel/amd64** (cx43).
- **No Traefik / no Ingress resources** on tools — Cloudflare Tunnel is the only ingress. Expose services via `Service` + a tunnel route.
- **Both clusters are Flux-managed.** Manifests in git are the source of truth. Imperative `kubectl scale`, `kubectl edit`, etc. will be reverted at the next reconcile interval (10 min).
  - To start/stop a workload: edit its manifest in git (`replicas: 0` ↔ `1`), commit, push.
  - To rotate a secret: `sops k8s/secrets/<cluster>/<file>.yaml` to decrypt-edit-encrypt in-place, then push.
- **No new `kubectl create secret`.** SOPS-encrypted secrets — including `ghcr-secret` for private GHCR pulls — live in `k8s/secrets/<cluster>/`. See "Adding a SOPS secret" below.
- **Don't add resources to `infrastructure/base/` unless they're identical for both clusters.** Cluster-specific addons go in `infrastructure/<cluster>/`.
- **Commits:** never add `Co-Authored-By`.
- **New env vars must be documented** in both the image's `README.md` (env var table) and the k8s game's `README.md` (runbook). If added to `configmap.yaml`, add an inline `# comment` explaining it.

## Repository layout (`k8s/`)

```
k8s/
├── clusters/                       # per-cluster Flux bootstrap + per-concern KSs
│   ├── tools/                      # bootstrap path: --path=k8s/clusters/tools
│   │   ├── flux-system/            # gotk-components, gotk-sync (generated, do not edit)
│   │   ├── apps.yaml               # Flux KS → ./k8s/apps/tools
│   │   ├── infrastructure.yaml     # Flux KS → ./k8s/infrastructure/tools
│   │   ├── secrets.yaml            # Flux KS → ./k8s/secrets/tools (SOPS)
│   │   └── kustomization.yaml
│   └── game-servers/               # bootstrap path: --path=k8s/clusters/game-servers
│       ├── flux-system/
│       ├── game-servers.yaml       # Flux KS → ./k8s/apps/game-servers
│       ├── infrastructure.yaml     # Flux KS → ./k8s/infrastructure/game-servers
│       ├── secrets.yaml            # Flux KS → ./k8s/secrets/game-servers
│       └── kustomization.yaml
├── apps/
│   ├── tools/                      # cloudflared, content/booklore, monitoring (kube-prometheus-stack), telegram, vpn
│   └── game-servers/               # 9 games (5 historically deployed + 4 stubs, all replicas:0) + metrics (Grafana Alloy)
├── infrastructure/
│   ├── base/                       # SHARED: hcloud HelmRepository, hetzner-csi, hetzner-ccm, coredns-patch
│   ├── tools/                      # tools-only: prometheus-community helm repo, monitoring namespace
│   └── game-servers/               # thin overlay — just inherits ../base
└── secrets/
    ├── .sops.yaml                  # SOPS config (applies to both subdirs via parent-dir lookup)
    ├── tools/                      # SOPS-encrypted secrets for tools workloads
    └── game-servers/               # SOPS-encrypted secrets for game-servers workloads
```

**Repo-root `apps/` is unrelated** — it holds source code (sleepy-notify, vpn config), not k8s manifests. Don't confuse with `k8s/apps/`.

## Operating model

### Starting / stopping a game

All games default to `replicas: 0` in their workload manifest. To start one:

```bash
# Edit the workload manifest:
sed -i '' 's/replicas: 0/replicas: 1/' k8s/apps/game-servers/<game>/statefulset.yaml
# (palworld uses deployment.yaml, not statefulset.yaml)

git add k8s/apps/game-servers/<game>/ && git commit -m "chore(<game>): start" && git push

# Wait ≤10 min for Flux to reconcile, or force it:
KUBECONFIG=.kube/game-servers flux reconcile source git flux-system
KUBECONFIG=.kube/game-servers flux reconcile kustomization <game> -n flux-system
```

To stop, swap back to `replicas: 0` and push. `kubectl scale --replicas=N` will be reverted by Flux within 10 min, so don't bother.

### Adding a SOPS-encrypted secret

```bash
# 1. Write the plaintext (umask 077 to keep it private during encryption):
umask 077
cat > k8s/secrets/<cluster>/<ns>-<name>.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: <name>
  namespace: <ns>
type: Opaque
stringData:
  myKey: my-plaintext-value
EOF

# 2. Encrypt in place. sops 3.11 has a config-discovery bug — pass flags explicitly:
sops --age age14a000yfg3226nakz8gycgtw4c7zugyply4jv29p6fmuy8ak05cqsu5cdx3 \
     --encrypted-regex '^(data|stringData)$' \
     --encrypt --in-place k8s/secrets/<cluster>/<ns>-<name>.yaml

# 3. Add the new file to the resources list in k8s/secrets/<cluster>/kustomization.yaml.
# 4. Commit + push.
```

To **edit** an existing encrypted secret: `sops k8s/secrets/<cluster>/<file>.yaml` (opens decrypted in `$EDITOR`, re-encrypts on save).

The age recipient is shared between both clusters; the private key (`sops-age` Secret in `flux-system` namespace) was copied from tools to game-servers during Phase 3.

### Adding a new game

1. Create `k8s/apps/game-servers/<game>/` with `namespace.yaml`, `configmap.yaml`, `service.yaml`, `statefulset.yaml` (or `deployment.yaml`), and `kustomization.yaml` (explicit resource list — never rely on auto-discovery).
2. Create `k8s/apps/game-servers/<game>.yaml` — a Flux Kustomization expander.
3. Add `<game>.yaml` to `k8s/apps/game-servers/kustomization.yaml`'s resources list.
4. If the game needs secrets, add SOPS-encrypted files to `k8s/secrets/game-servers/`.
5. Set `replicas: 0` initially; commit + push. Game appears in cluster but doesn't run until you scale up.

### Activating a stub game

The 4 stubs (`enshrouded`, `palworld`, `satisfactory`, `valheim`) are already wired up at `replicas: 0`. To activate, set `replicas: 1` in the workload manifest, ensure any required SOPS secrets exist, push.

## Environment

`.env` is gitignored. Copy `.env.example` and `source .env` before running infra commands.

**OpenTofu gotcha — env vars must be remapped before running `tofu`:**

- `S3_ACCESS_KEY` / `S3_SECRET_KEY` → `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`
- `HCLOUD_TOKEN` → `TF_VAR_hcloud_token`
- `HCLOUD_SSH_KEY_NAME` (or `GAME_SERVERS_HCLOUD_SSH_KEY_NAME`) → `TF_VAR_ssh_key_name`

**Flux bootstrap** uses `FLUX_TOKEN_PAT` from `.env` (export as `GITHUB_TOKEN`).

Terraform state lives in Cloudflare R2 bucket `fabler` under `tools/terraform.tfstate` and `game-servers/terraform.tfstate`.

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
./scripts/backup-game.sh <game>   # scales to 0, runs the Job, scales back up
```

This is intentionally an imperative escape hatch. `backup-job.yaml` is deliberately excluded from `k8s/apps/game-servers/minecraft/kustomization.yaml` so Flux doesn't manage it; the script applies it on demand. See `k8s/apps/game-servers/minecraft/README.md` for the runbook pattern.

### Flux operations

```bash
# Force reconcile after a push (instead of waiting ≤ 10 min):
KUBECONFIG=<kubeconfig> flux reconcile source git flux-system

# Status of all Kustomizations on a cluster:
KUBECONFIG=<kubeconfig> flux get kustomizations -n flux-system

# Suspend / resume (use during manual interventions):
KUBECONFIG=<kubeconfig> flux suspend kustomization <name> -n flux-system
KUBECONFIG=<kubeconfig> flux resume  kustomization <name> -n flux-system
```

## Footguns to know about

- **Flux prune cascade**: a root Kustomization with `prune: true` reconciling at a commit where the user's per-concern Kustomizations don't yet exist at the bootstrap path will garbage-collect everything previously managed. When relocating a Flux bootstrap path, **stage all manifests in one commit before running `flux bootstrap`**, OR temporarily patch root to `prune: false` until the move commit lands. (This bit us during Phase 2 of the multi-cluster refactor — sleepy-notify lost its Redis data.)
- **CSI uninstall mid-cascade reformats volumes**. Even with `Retain` reclaim policy, volumes that get yanked off the node uncleanly may be reformatted by the CSI driver on next attach. Static PVs with explicit `volumeName` in the PVC give the most deterministic recovery.
- **Game PVs are on `Retain`** (patched during Phase 3). Don't change to `Delete`.
- **`kubectl scale`** on Flux-managed StatefulSets is reverted within 10 min. Edit the manifest instead.
