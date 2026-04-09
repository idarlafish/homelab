# Soulmask Server

[Soulmask](https://store.steampowered.com/app/2646460/Soulmask/) dedicated server running on the `game-servers` k3s cluster, using the custom self-contained image built from `apps/soulmask-server/`.

## At a glance

- **Game port:** 27050 (UDP, NodePort 30750)
- **Query port:** 27051 (UDP, NodePort 30751)
- **RCON / EchoPort:** 25575 (TCP, NodePort 30752)
- **Resources:** 10 Gi request / 14 Gi limit — **Soulmask dominates the cx43 when running.** Scale other heavy games (Satisfactory, Palworld) down to 0 before playing.
- **Storage:** 15 Gi `hcloud-volumes` PVC at `/home/steam/soulmask` — holds both the game binaries (installed via SteamCMD on every pod start) and the save data under `WS/Saved/`.
- **Auto-update:** SteamCMD runs on every pod (re)start; the daily auto-reboot picks up new Soulmask builds. Set `SKIP_UPDATE=1` in the configmap to pin a version.
- **Auto-reboot:** In-container supercronic cron — `AUTO_REBOOT_ENABLED=true` + `AUTO_REBOOT_CRON_EXPRESSION=0 4 * * *` (04:00 UTC daily). No k8s CronJob required.
- **Graceful shutdown:** SIGTERM from k8s → `init.sh` → `start.sh` → `WSServer-Linux-Shipping`. The StatefulSet has `terminationGracePeriodSeconds: 180` to allow the save-on-exit to finish.
- **Liveness probe:** `pgrep -f WSServer-Linux-Shipping` every 30 s (k8s restarts the pod if the game process dies).
- **Backups:** Soulmask's own in-game backup (`-backup=960`, roughly every 16 min) writes rollback snapshots into `WS/Saved/` on the PVC. **No off-node backup** — if the PVC is lost, saves are lost. Take manual R2 snapshots if you care.

## Architecture

The image is self-contained (see `apps/soulmask-server/README.md`). All operational logic — auto-reboot, auto-update-on-restart, signal handling — runs inside the container via `init.sh` + `start.sh` + `supercronic`. This namespace has **no k8s CronJobs, no RBAC, no external orchestration** — just Namespace + ConfigMap + Service + StatefulSet + (manually-created) Secrets.

All commands below assume `KUBECONFIG=.kube/game-servers` from the repo root.

## One-time setup

### 1. Create the namespace

```bash
KUBECONFIG=.kube/game-servers kubectl create namespace soulmask
```

### 2. Create the server-password secret

```bash
KUBECONFIG=.kube/game-servers kubectl create secret generic soulmask-secrets \
  -n soulmask \
  --from-literal=serverPassword='CHANGE_ME' \
  --from-literal=adminPassword='CHANGE_ME_ADMIN' \
  --from-literal=rconPassword='CHANGE_ME_RCON'
```

### 3. Create the ghcr pull secret

The `soulmask-server` image is a private GHCR package. Pull secrets are namespace-scoped and must be created here even if you have one in another namespace.

```bash
source .env && KUBECONFIG=.kube/game-servers kubectl create secret docker-registry ghcr-secret \
  -n soulmask \
  --docker-server=ghcr.io \
  --docker-username="$GHCR_USERNAME" \
  --docker-password="$GHCR_TOKEN"
```

### 4. Build and push the image

See `apps/soulmask-server/README.md`. Only required on Dockerfile or script changes — Soulmask itself updates at runtime via SteamCMD.

### 5. Apply the Hetzner firewall rules

`infra/game-servers/firewall.tf` contains rules for NodePorts `30750/udp`, `30751/udp`, `30752/tcp`. Apply once:

```bash
source .env && cd infra/game-servers && tofu init && tofu plan && tofu apply
```

### 6. Apply the manifests

```bash
KUBECONFIG=.kube/game-servers kubectl apply -f k8s/games/soulmask/
```

First pod start is slow (~3–5 min SteamCMD download). Subsequent starts are ~30–60 s.

## Day-to-day operations

### View logs

```bash
KUBECONFIG=.kube/game-servers kubectl logs -f soulmask-0 -n soulmask
```

### Restart manually

```bash
KUBECONFIG=.kube/game-servers kubectl rollout restart statefulset/soulmask -n soulmask
```

### Scale down / up

```bash
# Stop (frees RAM for other games)
KUBECONFIG=.kube/game-servers kubectl scale statefulset soulmask -n soulmask --replicas=0

# Start
KUBECONFIG=.kube/game-servers kubectl scale statefulset soulmask -n soulmask --replicas=1
```

### Apply config changes

After editing `configmap.yaml` or `statefulset.yaml`:

```bash
KUBECONFIG=.kube/game-servers kubectl apply -f k8s/games/soulmask/
KUBECONFIG=.kube/game-servers kubectl rollout restart statefulset/soulmask -n soulmask
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
