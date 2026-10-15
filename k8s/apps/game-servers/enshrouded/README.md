# Enshrouded

Self-hosted [Enshrouded](https://enshrouded.zendesk.com/) dedicated server, 4 slots.

| | |
|---|---|
| Image | `mornedhels/enshrouded-server`, **wine** variant ([docs](https://github.com/mornedhels/enshrouded-server)) |
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

The `-wine` tag is required, not a preference. The default (Proton/umu) image cannot
start game build 25936466 (1.0): Steamworks init fails with `Version Mismatch` /
`No SteamUtils011`, because the image's Proton Steam bridge predates the interface 1.0
asks for. The game ships a correct `steamclient64.dll`, so no file swap or forced
reinstall helps - only the different runtime does.

Two roles, both with passwords in `enshrouded-secret.yaml` (SOPS): `adminPassword` ->
`SERVER_ROLE_0_PASSWORD` (Admin, full moderation) and `playerPassword` ->
`SERVER_ROLE_1_PASSWORD` (Friend, builds but cannot kick/ban or open other players'
inventories). Which password a client joins with decides its role.
