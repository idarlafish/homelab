# Enshrouded

Self-hosted [Enshrouded](https://enshrouded.zendesk.com/) dedicated server, 4 slots.

| | |
|---|---|
| Image | `mornedhels/enshrouded-server`, `dev-proton` pinned by digest ([docs](https://github.com/mornedhels/enshrouded-server)) |
| Connect | `<node ip>:30637` (UDP) |
| Namespace | `enshrouded` |
| Volume | `game-servers-enshrouded-data`, Tofu-owned, `Retain` |
| Backup | Velero `enshrouded` schedule, daily 03:00, 14d |

## Start and stop

`replicas` in `statefulset.yaml` is the switch — it is the only state that matters, so
flip it in git rather than scaling live.

```sh
export KUBECONFIG=infra/game-servers/kubeconfig
kubectl -n enshrouded get sts enshrouded
kubectl -n enshrouded logs sts/enshrouded -f
```

The node holds one big game at a time. Dune's `DUNE_STOP` must be `"true"` before
starting this, or the 20Gi request will not fit alongside it.

## What is persisted

Only `/opt/enshrouded/server/savegame`. The install path is `/opt/enshrouded/server`
and `SERVER_SAVE_DIR` defaults to `./savegame` relative to it, so that mount is the
world. The 8.94GB game itself is deliberately not on the volume and re-downloads on
restart, which keeps the volume at 10GB.

The PV is created by `infra/game-servers/volumes.tf` with a `claim_ref` to
`enshrouded-data-enshrouded-0`, the name the volumeClaimTemplate generates. Run
`tofu apply` **before** pushing a change that scales this up, or Flux gets there first
and the CSI driver provisions a throwaway volume instead of binding this one.

## Settings

All of `configmap.yaml`, as `SERVER_*` env vars that the image converts into
`enshrouded_server.json`. Since image 1.6.0 unknown `SERVER_GS_*` keys are passed
through generically, so new game settings work without an image bump.

`UPDATE_CRON` checks Steam every 30 minutes and updates in place, so a game patch
needs no action here.

Pinned to `dev-proton` because the 1.7.2 stable tags predate 1.0: their Proton Steam
bridge fails Steamworks init with `Version Mismatch` / `No SteamUtils011`. Upstream
fixed it in GE-Proton 11-9 (#254), which only the dev tags carry so far - move back to
a stable tag once one ships.

On first start the updater may log `Unable to set current version` because Proton files
do not exist yet and the download races. That leaves `current_version` empty, which
restarts the server every `UPDATE_CRON` tick. One `supervisorctl start enshrouded-updater`
settles it.

One role: `adminPassword` in `enshrouded-secret.yaml` (SOPS) feeds
`SERVER_ROLE_0_PASSWORD`. Everyone joins with it and gets full moderation rights.
Add `SERVER_ROLE_1_*` plus a second secret key to split that again.
