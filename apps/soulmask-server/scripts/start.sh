#!/usr/bin/env bash
# Main Soulmask server startup script.
#
# Runs SteamCMD to install/update the game onto the PVC (skip with
# SKIP_UPDATE=1), then launches WSServer-Linux-Shipping in the background
# and forwards SIGTERM to it so the game saves cleanly on pod termination.
#
# Called by init.sh as a background child, so this script's SIGTERM trap
# is what actually handles graceful shutdown of the game binary.
set -euo pipefail

# shellcheck source=./helper_functions.sh
source /home/steam/scripts/helper_functions.sh

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
GAME_WORLD="${GAME_WORLD:-Level01_Main}"       # Level01_Main (base) or DLC_Level01_Main (Shifting Sands DLC)

if [[ -z "${SERVER_PASSWORD:-}" || -z "${ADMIN_PASSWORD:-}" ]]; then
  log_err start "SERVER_PASSWORD and ADMIN_PASSWORD are required (inject via k8s Secret)"
  exit 1
fi

mkdir -p "$INSTALL_DIR"

# --- SteamCMD with escalating recovery ---------------------------------
# SteamCMD periodically wedges itself into "Error! App 'X' state is 0x6
# after update job" when an earlier update was interrupted, when Steam
# pushed a new build midway through a download, or when its state files
# disagree with the on-disk tree. Plain `+app_update ... validate` does
# NOT recover from this — the state machine itself is corrupt, and
# validate exits immediately with the same 0x6. Manual recovery (per the
# SCP:SL server wiki) is to delete the stuck appmanifest and re-run.
#
# We automate that recovery with a retry loop that clears one additional
# slice of SteamCMD state between attempts:
#
#   attempt 1: clear transient downloading/ + temp/ dirs, then update
#   attempt 2: also delete steamapps/appmanifest_<appid>.acf
#   attempt 3: also delete ~/Steam/appcache/appinfo.vdf
#   give up:   exit non-zero → k8s CrashLoopBackOff surfaces the failure
#
# See apps/soulmask-server/README.md § "SteamCMD failure recovery" for
# the rationale and source links.
STEAMCMD_MAX_ATTEMPTS=3
STEAMCMD_RETRY_SLEEP=30
STEAM_APPCACHE="/home/steam/Steam/appcache/appinfo.vdf"

run_steamcmd_once() {
  # Transient download artifacts from an interrupted prior update can
  # themselves cause state 0x6. Clear them on every attempt — they are
  # scratch space by design and safe to delete.
  rm -rf \
    "${INSTALL_DIR}/steamapps/downloading" \
    "${INSTALL_DIR}/steamapps/temp" \
    || true

  /home/steam/steamcmd/steamcmd.sh \
    +force_install_dir "$INSTALL_DIR" \
    +login anonymous \
    +app_update "$STEAM_APP_ID" validate \
    +quit
}

run_steamcmd_with_recovery() {
  local attempt rc
  for (( attempt = 1; attempt <= STEAMCMD_MAX_ATTEMPTS; attempt++ )); do
    log start "SteamCMD attempt ${attempt}/${STEAMCMD_MAX_ATTEMPTS}"

    # `|| rc=$?` suspends `set -e` for the function call so a steamcmd
    # failure doesn't abort the script before we can retry.
    rc=0
    run_steamcmd_once || rc=$?
    if (( rc == 0 )); then
      log start "SteamCMD update complete"
      return 0
    fi
    log_err start "SteamCMD attempt ${attempt} failed (exit ${rc})"

    if (( attempt >= STEAMCMD_MAX_ATTEMPTS )); then
      break
    fi

    # Escalate recovery between attempts.
    case $attempt in
      1)
        log start "recovery: removing stuck appmanifest_${STEAM_APP_ID}.acf"
        rm -f "${INSTALL_DIR}/steamapps/appmanifest_${STEAM_APP_ID}.acf" || true
        ;;
      2)
        log start "recovery: removing Steam appcache ${STEAM_APPCACHE}"
        rm -f "$STEAM_APPCACHE" || true
        ;;
    esac

    log start "sleeping ${STEAMCMD_RETRY_SLEEP}s before retry"
    sleep "$STEAMCMD_RETRY_SLEEP"
  done

  log_err start "SteamCMD failed after ${STEAMCMD_MAX_ATTEMPTS} attempts — giving up"
  return 1
}

if ! is_truthy "$SKIP_UPDATE"; then
  log start "running SteamCMD to install/update app ${STEAM_APP_ID} into ${INSTALL_DIR}"
  run_steamcmd_with_recovery
else
  log start "SKIP_UPDATE is set, skipping SteamCMD update"
fi

cd "$INSTALL_DIR"

if [[ ! -x ./WS/Binaries/Linux/WSServer-Linux-Shipping ]]; then
  log_err start "WSServer-Linux-Shipping not found under ${INSTALL_DIR}/WS/Binaries/Linux/"
  log_err start "(check SteamCMD output above, or the PVC contents)"
  exit 1
fi

log start "starting server: name='${SERVER_NAME}' mode=${GAME_MODE} slots=${SERVER_SLOTS} world=${GAME_WORLD}"
log start "ports: game=${GAME_PORT}/udp query=${QUERY_PORT}/udp rcon=${RCON_PORT}/tcp"

# --- Graceful shutdown: forward SIGTERM / SIGINT to the game and wait for
# it to flush saves. init.sh's trap calls `kill -TERM` on this script; the
# signal interrupts `wait` below, the trap fires, kills the game, and
# waits for it to drain.
GAME_PID=""
shutdown_handler() {
  log start "received shutdown signal, forwarding to WSServer (pid ${GAME_PID:-?})"
  if [[ -n "$GAME_PID" ]] && kill -0 "$GAME_PID" 2>/dev/null; then
    kill -TERM "$GAME_PID" 2>/dev/null || true
    wait "$GAME_PID" 2>/dev/null || true
  fi
  log start "game exited cleanly"
  exit 0
}
trap shutdown_handler SIGTERM SIGINT

# Build the launch argument list. Cross-server flags are only appended if
# their env vars are set, so single-server deploys don't see them at all.
EXTRA_ARGS=""
if [[ -n "${CROSS_SERVER_MAIN_PORT:-}" ]]; then
  EXTRA_ARGS="${EXTRA_ARGS} -mainserverport=${CROSS_SERVER_MAIN_PORT}"
  log start "cross-server: main server port ${CROSS_SERVER_MAIN_PORT}"
fi
if [[ -n "${CROSS_SERVER_CONNECT:-}" ]]; then
  EXTRA_ARGS="${EXTRA_ARGS} -clientserverconnect=${CROSS_SERVER_CONNECT}"
  log start "cross-server: connecting to main at ${CROSS_SERVER_CONNECT}"
fi

# shellcheck disable=SC2086
./WS/Binaries/Linux/WSServer-Linux-Shipping \
  WS "${GAME_WORLD}" \
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
  -online=Steam \
  -forcepassthrough \
  ${EXTRA_ARGS} \
  &

GAME_PID=$!
# wait returns non-zero if it was interrupted by a signal; || true lets
# the trap handler run without set -e killing us first.
wait "$GAME_PID" || true
