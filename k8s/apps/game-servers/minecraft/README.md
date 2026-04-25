# Minecraft Server

Modded Minecraft server running on the `game-servers` k3s cluster using [itzg/minecraft-server](https://docker-minecraft-server.readthedocs.io/).

- **Modpack:** [Zagribozha](https://modrinth.com/modpack/zagribozha) (Fabric)
- **Extra mods:** LuckPerms, Vanilla Permissions (added via `MODRINTH_PROJECTS` in configmap)
- **Port:** 25565 (NodePort 30565)

All commands below assume `KUBECONFIG=.kube/game-servers` from the repo root.

## RCON (quick commands)

For commands with simple text output:

```bash
KUBECONFIG=.kube/game-servers kubectl exec minecraft-0 -n minecraft -- rcon-cli "list"
```

For admin tasks like LuckPerms (`/lp editor`), use the in-game chat — RCON doesn't show formatted chat responses.

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

Manifest is the source of truth — Flux reconciles within 10 min of every push.

```bash
# Edit configmap.yaml or statefulset.yaml, then:
git add k8s/apps/game-servers/minecraft/ && git commit -m "tweak minecraft config" && git push

# Optional — force immediate reconcile instead of waiting:
KUBECONFIG=.kube/game-servers flux reconcile source git flux-system
KUBECONFIG=.kube/game-servers flux reconcile kustomization minecraft -n flux-system
```

If only the ConfigMap changed but the StatefulSet's pod hash didn't update (Flux doesn't auto-restart pods on ConfigMap-only changes), force a rollout:

```bash
KUBECONFIG=.kube/game-servers kubectl rollout restart statefulset/minecraft -n minecraft
# Note: this is a runtime action, not a state change — Flux won't undo it.
```

## Pause / Resume

The game's `replicas` field in `statefulset.yaml` is the source of truth. Edit + push:

```bash
# Stop:
sed -i '' 's/replicas: 1/replicas: 0/' k8s/apps/game-servers/minecraft/statefulset.yaml
git commit -am "chore(minecraft): stop" && git push

# Start:
sed -i '' 's/replicas: 0/replicas: 1/' k8s/apps/game-servers/minecraft/statefulset.yaml
git commit -am "chore(minecraft): start" && git push

# Force immediate reconcile (otherwise wait ≤10 min):
KUBECONFIG=.kube/game-servers flux reconcile kustomization minecraft -n flux-system
```

`kubectl scale --replicas=N` directly on the StatefulSet is reverted by Flux within 10 min — don't use it.
