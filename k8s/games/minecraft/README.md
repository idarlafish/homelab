# Minecraft Server

Modded Minecraft server running on the `game-servers` k3s cluster using [itzg/minecraft-server](https://docker-minecraft-server.readthedocs.io/).

- **Modpack:** [Zagribozha](https://modrinth.com/modpack/zagribozha) (Fabric)
- **Extra mods:** LuckPerms, Vanilla Permissions (added via `MODRINTH_PROJECTS` in configmap)
- **Port:** 25565 (NodePort 30565)

All commands below assume `KUBECONFIG=.kube/game-servers` from the repo root.

## Server Console (WebSocket)

The server exposes a WebSocket console on port 80 that streams full log output (including chat messages like LuckPerms editor URLs). Connect via `kubectl port-forward` and [websocat](https://github.com/vi/websocat):

```bash
# Terminal 1: port-forward
KUBECONFIG=.kube/game-servers kubectl port-forward minecraft-0 -n minecraft 8080:80

# Terminal 2: connect (password is the RCON_PASSWORD from minecraft-secrets)
websocat ws://localhost:8080/console -H "Sec-WebSocket-Protocol: mc-server-runner-ws-v1, <password>"
```

Once connected, type commands directly (e.g. `lp editor`) and see full output including links.

## RCON (quick commands)

For simple commands where you don't need to see chat output:

```bash
KUBECONFIG=.kube/game-servers kubectl exec minecraft-0 -n minecraft -- rcon-cli "list"
```

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
