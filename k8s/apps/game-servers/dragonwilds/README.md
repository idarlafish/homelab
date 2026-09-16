# RuneScape: Dragonwilds Server

Linux dedicated server via
[indifferentbroccoli/runescape-dragonwilds-server-docker](https://github.com/indifferentbroccoli/runescape-dragonwilds-server-docker)
(DepotDownloader pulls the server files onto the PVC on every start unless `UPDATE_ON_START=false`).

Players join with the **join code** from the logs (EOS session) and `worldPassword`:

```bash
KUBECONFIG=infra/game-servers/kubeconfig kubectl logs -n dragonwilds dragonwilds-0 | \
  grep -oE 'JoinCode.*value\[[A-Z0-9-]+\]' | tail -1
```

The server listens directly on **31777** (`DEFAULT_PORT`) because the game advertises its listen
port to clients — a container port that differs from the NodePort kicks players back to the title
screen on join.

## Admin

- `OWNER_ID` in `configmap.yaml` is the owner's Player ID (Settings menu, bottom). Placeholder `0`
  until set — the owner can ban/unban anyone; admins (via `adminPassword` in the in-game Server
  Management screen) can only ban online regular users.
- Rotate passwords: `sops k8s/apps/game-servers/dragonwilds/dragonwilds-secret.yaml`.

## Notes

- amd64 only.
- RAM: 2 GB + 1 GB per player. On a cx33 the 5Gi limit fits ~3 players; bump the node to cx43
  (`tofu apply -var server_type=cx43`) and raise the limit to 8Gi for a full 6-player lobby.
- A UE "world settings beacon" also listens on UDP 8888; upstream doesn't expose it and joins work without it.
- No RCON or query protocol; backups are crash-consistent unless the pod is stopped.
