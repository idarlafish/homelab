# Soulmask Server

[Soulmask](https://store.steampowered.com/app/2646460/Soulmask/) dedicated server running on the `game-servers` k3s cluster, using the custom self-contained image built from `apps/soulmask-server/`.

## At a glance

- **Game port:** 27050 (UDP, NodePort 30750)
- **Query port:** 27051 (UDP, NodePort 30751)
- **RCON / EchoPort:** 25575 (TCP, NodePort 30752)
- **Resources:** 10 Gi request / 14 Gi limit — **Soulmask dominates the cx43 when running.** All game StatefulSets default to `replicas: 0` in their manifests, so this is normally a non-issue — just confirm no other heavy game (Satisfactory, Palworld) is currently scaled up.
- **Storage:** 15 Gi `hcloud-volumes` PVC at `/home/steam/soulmask` — holds both the game binaries (installed via SteamCMD on every pod start) and the save data under `WS/Saved/`.
- **Auto-update:** SteamCMD runs on every pod (re)start; the daily auto-reboot picks up new Soulmask builds. Set `SKIP_UPDATE=1` in the configmap to pin a version.
- **Auto-reboot:** In-container supercronic cron — `AUTO_REBOOT_ENABLED=true` + `AUTO_REBOOT_CRON_EXPRESSION=0 4 * * *` (04:00 UTC daily). No k8s CronJob required.
- **Graceful shutdown:** SIGTERM from k8s → `init.sh` → `start.sh` → `WSServer-Linux-Shipping`. The StatefulSet has `terminationGracePeriodSeconds: 180` to allow the save-on-exit to finish.
- **Liveness probe:** `pgrep -f WSServer-Linux-Shipping` every 30 s (k8s restarts the pod if the game process dies).
- **Backups:** Soulmask's own in-game backup (`-backup=960`, roughly every 16 min) writes rollback snapshots into `WS/Saved/` on the PVC. **No off-node backup** — if the PVC is lost, saves are lost. Take manual R2 snapshots if you care.
- **Map:** `GAME_WORLD=DLC_Level01_Main` (Shifting Sands DLC). Set to `Level01_Main` to switch back to the base game — saves are per-map under `WS/Saved/Worlds/Dedicated/<MapName>/`, so switching is non-destructive.
- **Cross-server:** Set `CROSS_SERVER_MAIN_PORT` + `CROSS_SERVER_CONNECT` in configmap to link two map instances. See `apps/soulmask-server/README.md` for details.

## Architecture

The image is self-contained (see `apps/soulmask-server/README.md`). All operational logic — auto-reboot, auto-update-on-restart, signal handling — runs inside the container via `init.sh` + `start.sh` + `supercronic`. The namespace has **no k8s CronJobs, no RBAC, no external orchestration** — just Namespace + ConfigMap + Service + StatefulSet, applied by Flux from this directory. Secrets (`soulmask-secrets`, `ghcr-secret`, `r2-credentials`) live SOPS-encrypted in `k8s/secrets/game-servers/` and are reconciled by the `secrets` Flux Kustomization.

All commands below assume `KUBECONFIG=.kube/game-servers` from the repo root.

## One-time setup (only if rebuilding the cluster)

The cluster is Flux-managed: applying the manifests = pushing the manifests. Most of these steps are already done.

### 1. Apply the Hetzner firewall rules

`infra/game-servers/firewall.tf` contains rules for NodePorts `30750/udp`, `30751/udp`, `30752/tcp`. Apply once:

```bash
source .env && cd infra/game-servers && tofu init && tofu plan && tofu apply
```

### 2. Build and push the image (first time only)

See `apps/soulmask-server/README.md`. Only required on Dockerfile or script changes — Soulmask itself updates at runtime via SteamCMD.

### 3. Secrets

Already in git as `k8s/secrets/game-servers/soulmask-{soulmask-secrets,ghcr-secret,r2-credentials}.yaml` (SOPS-encrypted). To rotate:

```bash
sops k8s/secrets/game-servers/soulmask-soulmask-secrets.yaml   # opens in $EDITOR, re-encrypts on save
git commit -am "rotate soulmask secrets" && git push
```

### 4. Manifests are already applied via Flux

If you've just bootstrapped a new game-servers cluster, `flux bootstrap github --path=k8s/clusters/game-servers` brings up everything in this directory automatically. First pod start is slow (~3–5 min SteamCMD download). Subsequent starts are ~30–60 s.

## Day-to-day operations

### View logs

```bash
KUBECONFIG=.kube/game-servers kubectl logs -f soulmask-0 -n soulmask
```

### Restart manually

```bash
KUBECONFIG=.kube/game-servers kubectl rollout restart statefulset/soulmask -n soulmask
```

### Pause / Resume

`replicas` in `statefulset.yaml` is the source of truth. Edit + push:

```bash
# Stop (frees RAM for other games):
sed -i '' 's/replicas: 1/replicas: 0/' k8s/apps/game-servers/soulmask/statefulset.yaml
git commit -am "chore(soulmask): stop" && git push

# Start:
sed -i '' 's/replicas: 0/replicas: 1/' k8s/apps/game-servers/soulmask/statefulset.yaml
git commit -am "chore(soulmask): start" && git push

# Force immediate reconcile (otherwise wait ≤10 min):
KUBECONFIG=.kube/game-servers flux reconcile kustomization soulmask -n flux-system
```

`kubectl scale --replicas=N` directly on the StatefulSet is reverted by Flux within 10 min — don't use it.

### Apply config changes

After editing `configmap.yaml` or `statefulset.yaml`:

```bash
git add k8s/apps/game-servers/soulmask/ && git commit -m "tweak soulmask config" && git push
KUBECONFIG=.kube/game-servers flux reconcile kustomization soulmask -n flux-system  # optional, force
```

ConfigMap-only changes don't auto-restart the pod (Flux doesn't track ConfigMap → pod hash). Force a rollout:

```bash
KUBECONFIG=.kube/game-servers kubectl rollout restart statefulset/soulmask -n soulmask
# Runtime action — Flux won't undo it.
```

### Change the auto-reboot schedule

Edit `AUTO_REBOOT_CRON_EXPRESSION` in `configmap.yaml`, reapply, and roll the pod. `init.sh` reads the env var at startup and configures supercronic accordingly. Set `AUTO_REBOOT_ENABLED: "false"` to disable the in-container cron entirely.

### Pin a Soulmask version

Add `SKIP_UPDATE: "1"` to `configmap.yaml`. `start.sh` will skip the SteamCMD call on next (re)start and launch whatever is already on the PVC.

## Gameplay tuning

Connect to the server as admin (enter `ADMIN_PASSWORD` in the in-game chat / console). Open the GM menu → "Open Coefficient Settings" — you get English-labeled sliders for XP rate, resource yield, invasion frequency, breeding interval, building decay, etc. Changes are written to section 1 of `WS/Saved/GameplaySettings/GameXishu.json` and persist across pod restarts and SteamCMD updates.

There are no env vars for gameplay tuning by design — Soulmask's config keys are Chinese-pinyin (`CaiJiDiaoLuoRatio`, `JianZhuFuLanKaiGuan`, etc.) and the in-game menu provides a much friendlier interface than forwarding opaque names via a configmap.

## Connect via Steam

Steam → View → Game Servers → Favorites → `<game-servers-public-ip>:30750`.
