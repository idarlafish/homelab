# Soulmask Server

[Soulmask](https://store.steampowered.com/app/2646460/Soulmask/) dedicated server running on the `game-servers` k3s cluster, using the custom image built from `apps/soulmask-server/`.

- **Game port:** 27050 (UDP, NodePort 30750)
- **Query port:** 27051 (UDP, NodePort 30751)
- **RCON / EchoPort:** 25575 (TCP, NodePort 30752)
- **Resources:** 10 Gi request / 14 Gi limit — **Soulmask dominates the cx43 when running.** Scale other heavy games (Satisfactory, Palworld) down to 0 before playing.
- **Save data:** `/home/steam/soulmask/WS/Saved` → `soulmask-saves` PVC (10 Gi).

All commands below assume `KUBECONFIG=.kube/game-servers` from the repo root.

## One-time setup

### 1. Create the secret with server passwords

```bash
KUBECONFIG=.kube/game-servers kubectl create secret generic soulmask-secrets \
  -n soulmask \
  --from-literal=serverPassword='CHANGE_ME' \
  --from-literal=adminPassword='CHANGE_ME_ADMIN' \
  --from-literal=rconPassword='CHANGE_ME_RCON'
```

### 2. Build and push the image

See `apps/soulmask-server/README.md`. Required before the first `kubectl apply` of the StatefulSet, and again whenever Soulmask releases a server update.

### 3. Apply the Hetzner firewall rules

After `infra/game-servers/firewall.tf` is updated with the three Soulmask NodePort rules:

```bash
source .env && cd infra/game-servers && tofu init && tofu plan && tofu apply
```

### 4. Apply the manifests

```bash
KUBECONFIG=.kube/game-servers kubectl apply -f k8s/games/soulmask/
```

## View logs

```bash
KUBECONFIG=.kube/game-servers kubectl logs -f soulmask-0 -n soulmask
```

## Restart

```bash
KUBECONFIG=.kube/game-servers kubectl rollout restart statefulset/soulmask -n soulmask
```

## Apply Config Changes

After editing `configmap.yaml` or `statefulset.yaml`:

```bash
KUBECONFIG=.kube/game-servers kubectl apply -f k8s/games/soulmask/
KUBECONFIG=.kube/game-servers kubectl rollout restart statefulset/soulmask -n soulmask
```

## Scale Down / Up

```bash
# Stop (free RAM for other games)
KUBECONFIG=.kube/game-servers kubectl scale statefulset soulmask -n soulmask --replicas=0

# Start
KUBECONFIG=.kube/game-servers kubectl scale statefulset soulmask -n soulmask --replicas=1
```

## Update the server

When Soulmask ships a new server build, rebuild the image and restart:

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
