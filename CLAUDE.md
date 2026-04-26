# CLAUDE.md

Operational rules and gotchas for this monorepo. See [README.md](README.md) for layout, services, and infra overview. Per-game runbooks live in `k8s/apps/game-servers/<game>/README.md`.

## Hard rules

- **Use `tofu`** (OpenTofu), not `terraform`. Both Hetzner servers share `infra/modules/hcloud-server/`; read it before editing either caller.
- **Two clusters, two kubeconfigs — never mix them:**
  - `tools` (ARM64) → `KUBECONFIG=.kube/config`
  - `game-servers` (amd64) → `KUBECONFIG=.kube/game-servers`
- **No Traefik / no Ingress on tools** — Cloudflare Tunnel is the only ingress. New services on tools cluster need a Tunnel route, not an Ingress.
- **Both clusters are Flux-managed.** Manifests in git are the source of truth. Edit manifest → commit → push → Flux reconciles within 10 min. Never use `kubectl scale` / `kubectl edit` on Flux-managed resources — they're reverted at the next reconcile.
- **No new `kubectl create secret`.** SOPS-encrypted secrets (including `ghcr-secret` for GHCR pulls) live in `k8s/secrets/<cluster>/`. To rotate: `sops <file>`. To create: see "SOPS gotcha" below.
- **`infrastructure/base/` is shared by both clusters.** Cluster-specific addons go in `infrastructure/<cluster>/`. Anything in `base/` must be valid for both.
- **Commits:** never add `Co-Authored-By`.
- **New env vars** are documented in both the image's `README.md` and the k8s game's `README.md`. Inline `# comment` in the configmap if applicable.

## Environment

`.env` is gitignored. Copy `.env.example` and `source .env` before running infra commands.

**OpenTofu env var remap (`tofu` doesn't pick these up automatically):**
- `S3_ACCESS_KEY` / `S3_SECRET_KEY` → `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`
- `HCLOUD_TOKEN` → `TF_VAR_hcloud_token`
- `HCLOUD_SSH_KEY_NAME` (or `GAME_SERVERS_HCLOUD_SSH_KEY_NAME`) → `TF_VAR_ssh_key_name`

**Flux bootstrap:** export `GITHUB_TOKEN="$FLUX_TOKEN_PAT"` from `.env`.

Terraform state lives in Cloudflare R2 bucket `fabler` (`tools/terraform.tfstate`, `game-servers/terraform.tfstate`).

## SOPS gotcha

sops 3.11 has a config-discovery bug — `.sops.yaml` isn't auto-found when encrypting new files. Pass flags explicitly:

```bash
sops --age age14a000yfg3226nakz8gycgtw4c7zugyply4jv29p6fmuy8ak05cqsu5cdx3 \
     --encrypted-regex '^(data|stringData)$' \
     --encrypt --in-place k8s/secrets/<cluster>/<file>.yaml
```

Editing existing files (`sops <file>`) works fine — it reads the SOPS metadata block. Same age recipient is shared between both clusters; the private key is in the `sops-age` Secret in each cluster's `flux-system` namespace.

## Footguns (incident lessons)

- **Flux prune cascade**: a root Kustomization with `prune: true` reconciling at a commit where the per-concern manifests don't exist at its bootstrap path will garbage-collect everything previously managed → cascading deletes through every child Kustomization. **When relocating a Flux bootstrap path, stage all manifests in one commit before running `flux bootstrap`**, OR temporarily patch root to `prune: false`. (Hit us once during a multi-cluster restructure — Redis data on a former bot deployment was lost.)
- **Edit + git rm in the same commit:** `git commit` only takes staged changes. If you `Edit` a `kustomization.yaml` to drop a reference *and* `git rm` the referenced file in the same step, only the `git rm` is auto-staged — the kustomization edit needs `git add` first. Forgetting this leaves the kustomization referencing a deleted file, breaking the Kustomization build (and blocking everything that depends on it via `dependsOn`). Always `git status --short` before commit.
- **CSI uninstall mid-cascade can reformat volumes.** Even with `Retain` reclaim, volumes yanked off the node uncleanly may be reformatted by the CSI driver on next attach. Static PVs with explicit `volumeName` in the PVC give the most deterministic recovery.
- **Game PVs are on `Retain`** (patched during Phase 3 recovery work). Don't change to `Delete`.
- **`kubectl scale` on Flux-managed StatefulSets** is reverted within 10 min. Edit the manifest.

## Quick reference

- Per-game runbook (start/stop, RCON, backup, config changes): `k8s/apps/game-servers/<game>/README.md` — minecraft and soulmask have detailed ones.
- Game backup: `./scripts/backup-game.sh <game>` (the `backup-job.yaml` is deliberately excluded from minecraft's kustomization so Flux doesn't manage it).
