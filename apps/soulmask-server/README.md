# soulmask-server

Custom Docker image for the [Soulmask](https://store.steampowered.com/app/2646460/Soulmask/) dedicated server. The image is **self-contained**: all operational features (game launch, SteamCMD auto-update, graceful shutdown, scheduled auto-reboot via in-container cron) live inside the image. The k8s (or docker-compose) side is just a dumb consumer — set env vars, run the container, done. Pattern inspired by [thijsvanloef/palworld-server-docker](https://github.com/thijsvanloef/palworld-server-docker).

## Layout

```
apps/soulmask-server/
├── Dockerfile
├── scripts/
│   ├── init.sh              # Container PID 1. Signal handler, child orchestration, supercronic launcher.
│   ├── start.sh             # Runs SteamCMD, launches WSServer-Linux-Shipping, forwards SIGTERM.
│   ├── helper_functions.sh  # Small shared logging / truthy-parsing helpers.
│   └── auto_reboot.sh       # Invoked by supercronic on AUTO_REBOOT_CRON_EXPRESSION; sends SIGTERM to PID 1.
└── README.md
```

## Features

- **Native Linux build** of Soulmask (Steam app `3017300`). No Proton/Wine.
- **Auto-update on every (re)start** via SteamCMD `+app_update 3017300 validate`. The game binary lives on the PVC, not in the image, so the image itself rarely needs to be rebuilt.
- **Graceful shutdown**: `init.sh` traps SIGTERM/SIGINT, cascades to `start.sh`, which cascades to the game process; the server saves and exits cleanly before Kubernetes sends SIGKILL.
- **In-container scheduled auto-reboot** via [supercronic](https://github.com/aptible/supercronic). When `AUTO_REBOOT_ENABLED=true`, a cron job runs `auto_reboot.sh` on `AUTO_REBOOT_CRON_EXPRESSION` (default `0 4 * * *`, i.e. 04:00 UTC daily). That triggers a clean container exit; Kubernetes' restart policy brings the pod back, which re-runs SteamCMD — so the daily reboot is also the auto-update mechanism.
- **In-game saving + rollback snapshots** via Soulmask's own `-saving` and `-backup` CLI flags. These write to `WS/Saved/` on the PVC. No off-node backup (by design — we rely on the PVC surviving).
- **Minimal image**: `cm2network/steamcmd` + `libatomic1` + `procps` + `ca-certificates` + `curl` + `supercronic` + four small shell scripts.

## Build and push

```bash
docker buildx build \
  --platform linux/amd64 \
  -t ghcr.io/idarlafish/soulmask-server:latest \
  --push \
  apps/soulmask-server/
```

Rebuilds are only needed when the Dockerfile or one of the scripts under `scripts/` changes. Soulmask game updates are handled at runtime by SteamCMD and do not require an image rebuild.

## Cold start timing

- **First pod start on a fresh PVC**: ~3–5 min while SteamCMD downloads the game (~1.5–5 GB depending on Soulmask's current build).
- **Subsequent starts** (PVC already populated): ~30–60 s — SteamCMD validates the existing install and only fetches deltas.
- Set `SKIP_UPDATE=1` in the configmap to skip SteamCMD entirely and launch whatever is already on the PVC.

## Runtime env vars

Set in `k8s/games/soulmask/configmap.yaml` unless noted.

### Server identity & networking (consumed by `start.sh`)

| Var | Default | Notes |
|---|---|---|
| `GAME_MODE` | `pve` | `pve` or `pvp` |
| `SERVER_NAME` | `Fabler` | Steam browser server name |
| `SERVER_SLOTS` | `8` | Max players |
| `GAME_PORT` | `27050` | UDP |
| `QUERY_PORT` | `27051` | UDP |
| `RCON_PORT` | `25575` | TCP (Soulmask's EchoPort) |
| `SAVING` | `600` | In-game autosave interval (seconds) |
| `BACKUP` | `960` | In-game backup interval (seconds) |
| `GAME_WORLD` | `Level01_Main` | Map to load: `Level01_Main` (base game) or `DLC_Level01_Main` (Shifting Sands DLC) |
| `SKIP_UPDATE` | `0` | Set to `1` to pin the installed Soulmask version (skip SteamCMD) |
| `STEAM_APP_ID` | `3017300` | Override if SteamDB changes the app id |
| `INSTALL_DIR` | `/home/steam/soulmask` | Where SteamCMD installs the game — matches the PVC mount path |
| `CROSS_SERVER_MAIN_PORT` | — | Port the main server advertises for cross-server linkage (`-mainserverport` flag). Only set when running two map instances. |
| `CROSS_SERVER_CONNECT` | — | Address (`host:port`) a child server uses to connect to the main (`-clientserverconnect` flag). |
| `SERVER_PASSWORD` | — | **Required**, inject via `soulmask-secrets` k8s Secret |
| `ADMIN_PASSWORD` | — | **Required**, inject via `soulmask-secrets` k8s Secret |
| `RCON_PASSWORD` | — | Required when using the EchoPort for admin; inject via `soulmask-secrets` |

### Scheduled auto-reboot (consumed by `init.sh`)

| Var | Default | Notes |
|---|---|---|
| `AUTO_REBOOT_ENABLED` | `true` (in configmap) | Set to any of `1/true/on/yes` to enable. If disabled, supercronic is not launched. |
| `AUTO_REBOOT_CRON_EXPRESSION` | `0 4 * * *` | Standard 5-field cron. Any expression supercronic accepts. |

## SteamCMD failure recovery

SteamCMD periodically wedges itself with:

```
Error! App '3017300' state is 0x6 after update job.
```

State `0x6` means the Steam client state machine thinks the install is simultaneously "update required" (`0x2`) and "fully installed" (`0x4`) — a contradiction that `+app_update … validate` cannot fix on its own, because validate exits immediately with the same `0x6`. Common triggers:

- A prior update was interrupted (pod killed mid-download, SIGKILL at end of `terminationGracePeriodSeconds`, node reboot).
- Steam published a new Soulmask build midway through our download.
- Stale scratch space under `steamapps/downloading/` or `steamapps/temp/`.
- A corrupt `~/Steam/appcache/appinfo.vdf`.
- Rarely: a stuck `steamapps/appmanifest_3017300.acf` disagreeing with the on-disk tree.

The manual fix (documented on the [SCP:SL server techwiki](https://techwiki.scpslgame.com/) and reproduced in many community threads) is to delete the stuck appmanifest and re-run. `start.sh` automates that with an escalating retry loop so a transient 0x6 no longer produces a 3-day CrashLoopBackOff:

| Attempt | Cleanup before SteamCMD is invoked |
|---|---|
| 1 | `rm -rf steamapps/downloading steamapps/temp` |
| 2 | everything from attempt 1, plus `rm -f steamapps/appmanifest_${STEAM_APP_ID}.acf` |
| 3 | everything from attempt 2, plus `rm -f ~/Steam/appcache/appinfo.vdf` |

After the third failure the script exits non-zero and Kubernetes surfaces the issue as CrashLoopBackOff — at that point it is almost certainly *not* a cache-corruption issue (network outage, Steam down, Soulmask depot pulled, etc.) and needs human attention.

Tunables live at the top of the SteamCMD block in `scripts/start.sh`:

| Constant | Default | Notes |
|---|---|---|
| `STEAMCMD_MAX_ATTEMPTS` | `3` | Total attempts, not extra retries. Set to `1` to disable the retry loop entirely. |
| `STEAMCMD_RETRY_SLEEP` | `30` | Seconds between attempts. Short enough to stay inside k8s' liveness-probe `initialDelaySeconds` budget (300s) on a warm PVC. |

### Interpreting the logs

During a recovery cycle you will see lines like:

```
[soulmask] [start] SteamCMD attempt 1/3
…
[soulmask] [start] ERR: SteamCMD attempt 1 failed (exit 8)
[soulmask] [start] recovery: removing stuck appmanifest_3017300.acf
[soulmask] [start] sleeping 30s before retry
[soulmask] [start] SteamCMD attempt 2/3
…
[soulmask] [start] SteamCMD update complete
```

If you see all three attempts fail, check `kubectl logs` for the SteamCMD stdout between the retry banners — that is the real error (network, auth, Steam outage). The retry loop exists to eat transient cache corruption, not to paper over genuine failures.

## Graceful shutdown chain

```
k8s SIGTERM → init.sh (PID 1)
               └─ trap: kill -TERM $MAIN_PID
                        └─ start.sh
                               └─ trap: kill -TERM $GAME_PID
                                        └─ WSServer-Linux-Shipping
                                             (saves to WS/Saved/, exits)
                                        wait $GAME_PID
                               exits
                        wait $MAIN_PID
               exits
```

The StatefulSet in `k8s/games/soulmask/statefulset.yaml` sets `terminationGracePeriodSeconds: 180`, so Kubernetes gives this chain up to 3 minutes before SIGKILLing the pod. Soulmask's save-on-exit is fast in practice (a few seconds) but that budget leaves room for slow disk flushes during scheduled reboots.
