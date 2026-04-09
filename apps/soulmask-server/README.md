# soulmask-server

Custom Docker image for the [Soulmask](https://store.steampowered.com/app/2646460/Soulmask/) dedicated server. Minimal: just [`cm2network/steamcmd`](https://hub.docker.com/r/cm2network/steamcmd) + `libatomic1` + `procps` + our `entrypoint.sh`. **The game binaries are not baked into the image** — `entrypoint.sh` installs/updates Steam app `3017300` (native Linux dedicated server) into the PVC on every pod start, so the server auto-updates whenever the pod restarts.

Kubernetes manifests that consume this image live at `k8s/games/soulmask/`.

## Build and push

```bash
docker buildx build \
  --platform linux/amd64 \
  -t ghcr.io/idarlafish/soulmask-server:latest \
  --push \
  apps/soulmask-server/
```

This should only need to be rebuilt when `entrypoint.sh` or the `Dockerfile` change — not when Soulmask releases a server patch. Game updates happen automatically on the next pod restart.

## Cold start

- **First pod start on a fresh PVC**: ~3–5 minutes while SteamCMD downloads ~5 GB to the PVC.
- **Subsequent pod starts**: ~30–60 seconds (SteamCMD validates the existing install and only downloads deltas).
- **Pin a version** (skip the update) by setting `SKIP_UPDATE=1` on the pod env.

## Runtime env vars

Set in `k8s/games/soulmask/configmap.yaml` unless noted:

| Var | Default | Source | Notes |
|---|---|---|---|
| `GAME_MODE` | `pve` | ConfigMap | `pve` or `pvp` |
| `SERVER_NAME` | `Fabler` | ConfigMap | Steam browser server name |
| `SERVER_SLOTS` | `8` | ConfigMap | Max players |
| `GAME_PORT` | `27050` | ConfigMap | UDP |
| `QUERY_PORT` | `27051` | ConfigMap | UDP |
| `RCON_PORT` | `25575` | ConfigMap | TCP (EchoPort) |
| `SAVING` | `600` | ConfigMap | In-game autosave interval (seconds) |
| `BACKUP` | `960` | ConfigMap | In-game backup interval (seconds) |
| `SKIP_UPDATE` | `0` | ConfigMap (optional) | Set to `1` to pin the installed version |
| `STEAM_APP_ID` | `3017300` | ConfigMap (optional) | Override if SteamDB changes the app id |
| `SERVER_PASSWORD` | — | `soulmask-secrets` | **Required** |
| `ADMIN_PASSWORD` | — | `soulmask-secrets` | **Required** |
| `RCON_PASSWORD` | — | `soulmask-secrets` | Required when using RCON |

## Graceful shutdown

`entrypoint.sh` traps `SIGTERM` / `SIGINT` and forwards them to the `WSServer-Linux-Shipping` process, then `wait`s for it to exit. The StatefulSet sets `terminationGracePeriodSeconds: 180` so Kubernetes gives Soulmask up to 3 minutes to flush saves before a forced kill.
