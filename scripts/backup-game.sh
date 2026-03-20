#!/usr/bin/env bash
set -euo pipefail

# Backup a game server's data to Cloudflare R2.
# Scales down the game, runs a backup Job, then scales back up.
#
# Usage: ./scripts/backup-game.sh <game>
# Example: ./scripts/backup-game.sh minecraft
#
# Prerequisites:
# - kubectl configured with game-servers cluster access
# - r2-credentials secret in the game's namespace
#   (create once per namespace):
#   source .env && KUBECONFIG=.kube/game-servers kubectl create secret generic r2-credentials \
#     -n <game> --from-literal=access-key-id="$S3_ACCESS_KEY" \
#     --from-literal=secret-access-key="$S3_SECRET_KEY"
# - backup-job.yaml in k8s/games/<game>/

GAME="${1:?Usage: $0 <game>}"
KUBECONFIG="${KUBECONFIG:-$(git rev-parse --show-toplevel)/.kube/game-servers}"
export KUBECONFIG

MANIFEST="$(git rev-parse --show-toplevel)/k8s/games/${GAME}/backup-job.yaml"
if [[ ! -f "$MANIFEST" ]]; then
  echo "Error: $MANIFEST not found"
  exit 1
fi

echo "==> Scaling down ${GAME}..."
kubectl scale statefulset "$GAME" -n "$GAME" --replicas=0
kubectl wait --for=delete pod/"${GAME}-0" -n "$GAME" --timeout=120s 2>/dev/null || true

echo "==> Cleaning up previous backup job (if any)..."
kubectl delete job "${GAME}-backup" -n "$GAME" --ignore-not-found

echo "==> Running backup..."
kubectl apply -f "$MANIFEST"
kubectl wait --for=condition=complete job/"${GAME}-backup" -n "$GAME" --timeout=600s

echo "==> Backup logs:"
kubectl logs -n "$GAME" job/"${GAME}-backup"

echo "==> Scaling ${GAME} back up..."
kubectl scale statefulset "$GAME" -n "$GAME" --replicas=1

echo "==> Done! ${GAME} is starting back up."
