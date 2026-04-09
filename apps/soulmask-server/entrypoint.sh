#!/usr/bin/env bash
# Entrypoint for the Soulmask dedicated server container.
# Reads config from environment variables (see k8s/games/soulmask/configmap.yaml
# and k8s/games/soulmask/statefulset.yaml for the authoritative set).
set -euo pipefail

GAME_MODE="${GAME_MODE:-pve}"
SERVER_NAME="${SERVER_NAME:-Fabler}"
SERVER_SLOTS="${SERVER_SLOTS:-8}"
GAME_PORT="${GAME_PORT:-27050}"
QUERY_PORT="${QUERY_PORT:-27051}"
RCON_PORT="${RCON_PORT:-25575}"
SAVING="${SAVING:-600}"
BACKUP="${BACKUP:-960}"

if [[ -z "${SERVER_PASSWORD:-}" || -z "${ADMIN_PASSWORD:-}" ]]; then
  echo "[soulmask] SERVER_PASSWORD and ADMIN_PASSWORD are required (inject via k8s Secret)" >&2
  exit 1
fi

cd /home/steam/soulmask

echo "[soulmask] starting server: name='${SERVER_NAME}' mode=${GAME_MODE} slots=${SERVER_SLOTS}"
echo "[soulmask] ports: game=${GAME_PORT}/udp query=${QUERY_PORT}/udp rcon=${RCON_PORT}/tcp"

exec ./WS/Binaries/Linux/WSServer-Linux-Shipping \
  WS Level01_Main \
  -server \
  -log \
  -UTF8Output \
  "-${GAME_MODE}" \
  -SteamServerName="${SERVER_NAME}" \
  -MaxPlayers="${SERVER_SLOTS}" \
  -Port="${GAME_PORT}" \
  -QueryPort="${QUERY_PORT}" \
  -EchoPort="${RCON_PORT}" \
  -adminpsw="${ADMIN_PASSWORD}" \
  -PSW="${SERVER_PASSWORD}" \
  -saving="${SAVING}" \
  -backup="${BACKUP}" \
  -MULTIHOME=0.0.0.0
