# Soulmask Server

[Soulmask](https://store.steampowered.com/app/2646460/Soulmask/) dedicated server running on the `game-servers` k3s cluster, using the custom image built from `apps/soulmask-server/`.

## At a glance

- **Game port:** 27050 (UDP, NodePort 30750)
- **Query port:** 27051 (UDP, NodePort 30751)
- **RCON / EchoPort:** 25575 (TCP, NodePort 30752)
- **Resources:** 10 Gi request / 14 Gi limit — **Soulmask dominates the cx43 when running.** Scale other heavy games (Satisfactory, Palworld) down to 0 before playing.
- **Storage:** 15 Gi `hcloud-volumes` PVC at `/home/steam/soulmask` — holds both the game binaries (installed via SteamCMD on each pod start) and the save data under `WS/Saved/`.
- **Auto-update:** `entrypoint.sh` runs SteamCMD on every pod start, so the server picks up Soulmask patches automatically. Set `SKIP_UPDATE=1` in the configmap to pin a version.
- **Graceful shutdown:** SIGTERM from k8s is trapped and forwarded to `WSServer-Linux-Shipping`; the StatefulSet's `terminationGracePeriodSeconds: 180` gives Soulmask time to flush saves.
- **Liveness probe:** `pgrep WSServer-Linux-Shipping` (k8s restarts the pod if the game process dies).
- **Scheduled restart:** CronJob runs `kubectl rollout restart` daily at 04:00 UTC (see `restart-cronjob.yaml`).
- **Scheduled backup to R2:** CronJob runs every 6 hours — scales down, snapshots `WS/Saved/` to `s3://fabler/backups/game-servers/soulmask/`, scales back up (see `backup-cronjob.yaml`). ~2 min of downtime per cycle.

All commands below assume `KUBECONFIG=.kube/game-servers` from the repo root.

## One-time setup

### 1. Create the server-password secret

```bash
KUBECONFIG=.kube/game-servers kubectl create secret generic soulmask-secrets \
  -n soulmask \
  --from-literal=serverPassword='CHANGE_ME' \
  --from-literal=adminPassword='CHANGE_ME_ADMIN' \
  --from-literal=rconPassword='CHANGE_ME_RCON'
```

### 2. Create the R2 credentials secret (for scheduled backups)

```bash
source .env && KUBECONFIG=.kube/game-servers kubectl create secret generic r2-credentials \
  -n soulmask \
  --from-literal=access-key-id="$S3_ACCESS_KEY" \
  --from-literal=secret-access-key="$S3_SECRET_KEY"
```

### 3. Build and push the image

See `apps/soulmask-server/README.md`. Only required once — subsequent Soulmask updates are handled by SteamCMD on pod start, not by image rebuilds.

### 4. Apply the Hetzner firewall rules

```bash
source .env && cd infra/game-servers && tofu init && tofu plan && tofu apply
```

### 5. Apply the manifests

```bash
KUBECONFIG=.kube/game-servers kubectl apply -f k8s/games/soulmask/
```

First pod start will be slow (~3–5 min while SteamCMD downloads ~5 GB to the PVC). Subsequent starts are ~30–60 s.

## View logs

```bash
KUBECONFIG=.kube/game-servers kubectl logs -f soulmask-0 -n soulmask
```

## Restart

Manual:

```bash
KUBECONFIG=.kube/game-servers kubectl rollout restart statefulset/soulmask -n soulmask
```

Automatic (daily 04:00 UTC): configured in `restart-cronjob.yaml`. Adjust `spec.schedule` and re-apply to change the cadence.

## Scale Down / Up

```bash
# Stop (free RAM for other games)
KUBECONFIG=.kube/game-servers kubectl scale statefulset soulmask -n soulmask --replicas=0

# Start
KUBECONFIG=.kube/game-servers kubectl scale statefulset soulmask -n soulmask --replicas=1
```

## Apply Config Changes

After editing `configmap.yaml` or `statefulset.yaml`:

```bash
KUBECONFIG=.kube/game-servers kubectl apply -f k8s/games/soulmask/
KUBECONFIG=.kube/game-servers kubectl rollout restart statefulset/soulmask -n soulmask
```

## Backups

### Run a backup on demand

```bash
KUBECONFIG=.kube/game-servers kubectl create job \
  --from=cronjob/soulmask-scheduled-backup \
  -n soulmask \
  soulmask-backup-manual-$(date +%s)
```

Check progress with `kubectl logs -f job/soulmask-backup-manual-... -n soulmask`.

### Pause scheduled backups temporarily

```bash
KUBECONFIG=.kube/game-servers kubectl patch cronjob soulmask-scheduled-backup \
  -n soulmask -p '{"spec":{"suspend":true}}'
```

Re-enable with `suspend: false`.

### Pin a Soulmask version (skip auto-update)

Edit `configmap.yaml` to add `SKIP_UPDATE: "1"`, reapply, and roll the pod. This keeps whatever build is already on the PVC.

## Update the custom image

Only needed when `apps/soulmask-server/Dockerfile` or `entrypoint.sh` change — **not** when Soulmask releases a server patch.

```bash
docker buildx build \
  --platform linux/amd64 \
  -t ghcr.io/idarlafish/soulmask-server:latest \
  --push \
  apps/soulmask-server/

KUBECONFIG=.kube/game-servers kubectl rollout restart statefulset/soulmask -n soulmask
```

## Connect via Steam

Steam → View → Game Servers → Favorites → `<game-servers-public-ip>:30750`.
