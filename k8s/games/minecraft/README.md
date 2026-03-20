# Minecraft Server

Modded Minecraft server running on the `game-servers` k3s cluster using [itzg/minecraft-server](https://docker-minecraft-server.readthedocs.io/).

- **Modpack:** [Zagribozha](https://modrinth.com/modpack/zagribozha) (Fabric)
- **Extra mods:** LuckPerms, Vanilla Permissions (added via `MODRINTH_PROJECTS` in configmap)
- **Port:** 25565 (NodePort 30565)

All commands below assume `KUBECONFIG=.kube/game-servers` from the repo root.

## Server Console

Use `rcon-cli` to run server commands (e.g. `/lp editor`):

```bash
KUBECONFIG=.kube/game-servers kubectl exec -it minecraft-0 -n minecraft -- rcon-cli
```

Ctrl+C exits the console without stopping the server.

## View Logs

```bash
KUBECONFIG=.kube/game-servers kubectl logs -f minecraft-0 -n minecraft
```

## Restart

```bash
KUBECONFIG=.kube/game-servers kubectl rollout restart statefulset/minecraft -n minecraft
```

## Backup

Backs up world data to Cloudflare R2. Scales the server down first (required for RWO volumes), runs the backup job, then scales back up:

```bash
./scripts/backup-game.sh minecraft
```

## Apply Config Changes

After editing `configmap.yaml` or `statefulset.yaml`:

```bash
KUBECONFIG=.kube/game-servers kubectl apply -f k8s/games/minecraft/
KUBECONFIG=.kube/game-servers kubectl rollout restart statefulset/minecraft -n minecraft
```

## Scale Down / Up

```bash
# Stop
KUBECONFIG=.kube/game-servers kubectl scale statefulset minecraft -n minecraft --replicas=0

# Start
KUBECONFIG=.kube/game-servers kubectl scale statefulset minecraft -n minecraft --replicas=1
```
