# soulmask-server

Custom Docker image for the [Soulmask](https://store.steampowered.com/app/2646460/Soulmask/) dedicated server. Based on [`cm2network/steamcmd`](https://hub.docker.com/r/cm2network/steamcmd), installs the native Linux build of Steam app `3017300` at image build time, then launches `WSServer-Linux-Shipping` via `entrypoint.sh`.

Kubernetes manifests that consume this image live at `k8s/games/soulmask/`.

## Build and push

```bash
docker buildx build \
  --platform linux/amd64 \
  -t ghcr.io/idarlafish/soulmask-server:latest \
  --push \
  apps/soulmask-server/
```

The first build is slow — SteamCMD downloads ~5 GB of game files during `RUN`. Rerun this command whenever Soulmask releases a server update, then roll the StatefulSet:

```bash
KUBECONFIG=.kube/game-servers kubectl rollout restart statefulset/soulmask -n soulmask
```
