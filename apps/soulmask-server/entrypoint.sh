#!/usr/bin/env bash
# Entrypoint for the Soulmask dedicated server container.
#
# - Runs SteamCMD on every start to install/update the server on the PVC
#   (set SKIP_UPDATE=1 to pin a specific installed version).
# - Launches the game in the background and forwards SIGTERM/SIGINT to it
#   so Kubernetes pod termination lets Soulmask save + exit cleanly.
#
# All non-secret config comes from env vars (see k8s/games/soulmask/
# configmap.yaml); SERVER_PASSWORD / ADMIN_PASSWORD come from the
# soulmask-secrets k8s Secret.
set -euo pipefail

GAME_MODE="${GAME_MODE:-pve}"
SERVER_NAME="${SERVER_NAME:-Fabler}"
SERVER_SLOTS="${SERVER_SLOTS:-8}"
GAME_PORT="${GAME_PORT:-27050}"
QUERY_PORT="${QUERY_PORT:-27051}"
RCON_PORT="${RCON_PORT:-25575}"
SAVING="${SAVING:-600}"
BACKUP="${BACKUP:-960}"
INSTALL_DIR="${INSTALL_DIR:-/home/steam/soulmask}"
SKIP_UPDATE="${SKIP_UPDATE:-0}"
STEAM_APP_ID="${STEAM_APP_ID:-3017300}"

if [[ -z "${SERVER_PASSWORD:-}" || -z "${ADMIN_PASSWORD:-}" ]]; then
  echo "[soulmask] SERVER_PASSWORD and ADMIN_PASSWORD are required (inject via k8s Secret)" >&2
  exit 1
fi

mkdir -p "$INSTALL_DIR"

if [[ "$SKIP_UPDATE" != "1" ]]; then
  echo "[soulmask] running SteamCMD to install/update app ${STEAM_APP_ID} into ${INSTALL_DIR}..."
  /home/steam/steamcmd/steamcmd.sh \
    +force_install_dir "$INSTALL_DIR" \
    +login anonymous \
    +app_update "$STEAM_APP_ID" validate \
    +quit
  echo "[soulmask] SteamCMD update complete"
else
  echo "[soulmask] SKIP_UPDATE=1 — skipping SteamCMD update"
fi

cd "$INSTALL_DIR"

if [[ ! -x ./WS/Binaries/Linux/WSServer-Linux-Shipping ]]; then
  echo "[soulmask] fatal: WSServer-Linux-Shipping not found under ${INSTALL_DIR}/WS/Binaries/Linux/" >&2
  echo "[soulmask] (check SteamCMD output above, or the PVC contents)" >&2
  exit 1
fi

echo "[soulmask] starting server: name='${SERVER_NAME}' mode=${GAME_MODE} slots=${SERVER_SLOTS}"
echo "[soulmask] ports: game=${GAME_PORT}/udp query=${QUERY_PORT}/udp rcon=${RCON_PORT}/tcp"

# Forward SIGTERM/SIGINT to the game so Soulmask saves on shutdown.
GAME_PID=""
shutdown() {
  echo "[soulmask] received shutdown signal, forwarding to WSServer..."
  if [[ -n "$GAME_PID" ]] && kill -0 "$GAME_PID" 2>/dev/null; then
    kill -TERM "$GAME_PID"
    # Wait until the game actually exits. A second 'wait' after the trap
    # handles the case where the first 'wait' was interrupted by the signal.
    wait "$GAME_PID" 2>/dev/null || true
  fi
  echo "[soulmask] shutdown complete"
  exit 0
}
trap shutdown SIGTERM SIGINT

./WS/Binaries/Linux/WSServer-Linux-Shipping \
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
  -MULTIHOME=0.0.0.0 \
  &

GAME_PID=$!
# 'wait' without -n returns the child's exit status. set -e would abort on
# non-zero, so we || true to let the trap handle graceful shutdown exits.
wait "$GAME_PID" || true
