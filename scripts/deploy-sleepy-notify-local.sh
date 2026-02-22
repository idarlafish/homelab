#!/usr/bin/env bash
set -euo pipefail

# Local deployment helper for sleepy-notify to the k3s "tools" cluster.
# Builds the image on your Mac, streams it directly into k3s (no registry required),
# then updates the deployment to use the new tag.
#
# Requirements:
# - docker (or nerdctl) on this machine
# - kubectl configured with access to the tools cluster (current context)
# - SSH access to the tools server as root
# - TOOLS_SERVER_IP environment variable set (same as in GitHub Actions),
#   or a kubeconfig whose current cluster server URL points at the tools server
#
# Usage:
#   ./scripts/deploy-sleepy-notify-local.sh             # uses git SHA as tag
#   TAG=my-feature ./scripts/deploy-sleepy-notify-local.sh

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# Optional: load repo-local env overrides (e.g. TOOLS_SERVER_IP) if present
if [ -f ".env" ]; then
  # shellcheck disable=SC1091
  . ".env"
elif [ -f ".env.tools" ]; then
  # Backwards compatibility with older setup
  # shellcheck disable=SC1091
  . ".env.tools"
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required but not found on PATH" >&2
  exit 1
fi

if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl is required but not found on PATH" >&2
  exit 1
fi

if [ -z "${TOOLS_SERVER_IP:-}" ]; then
  # Derive host from current kubeconfig server URL, e.g. https://1.2.3.4:6443
  SERVER_URL="$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}' || true)"
  if [ -z "$SERVER_URL" ]; then
    echo "Could not determine cluster server from kubeconfig; set TOOLS_SERVER_IP explicitly." >&2
    exit 1
  fi
  # Strip scheme
  SERVER_NO_SCHEME="${SERVER_URL#http://}"
  SERVER_NO_SCHEME="${SERVER_NO_SCHEME#https://}"
  # Take host before any port
  TOOLS_SERVER_IP="${SERVER_NO_SCHEME%%:*}"
fi

SSH_TARGET="root@${TOOLS_SERVER_IP}"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "This script must be run inside the git repository root" >&2
  exit 1
fi

TAG="${TAG:-$(git rev-parse --short HEAD)}"
IMAGE_NAME="ghcr.io/idarlafish/sleepy-notify"
FULL_IMAGE="${IMAGE_NAME}:${TAG}"

echo "Building sleepy-notify image:"
echo "  IMAGE: ${FULL_IMAGE}"
echo "  CONTEXT: apps/sleepy-notify"

docker build -t "${FULL_IMAGE}" apps/sleepy-notify

echo "Streaming image into k3s on ${SSH_TARGET} (no registry push)..."
docker save "${FULL_IMAGE}" | ssh "${SSH_TARGET}" 'k3s ctr images import -'

echo "Updating Kubernetes deployment image..."
kubectl -n telegram set image deployment/sleepy-notify-bot bot="${FULL_IMAGE}"

echo "Waiting for rollout to complete..."
kubectl -n telegram apply -f k8s/telegram/deployment.yaml
# kubectl -n telegram rollout status deployment/sleepy-notify-bot

echo "sleepy-notify deployed with image ${FULL_IMAGE}"

