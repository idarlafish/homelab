#!/usr/bin/env bash
# Soulmask container PID 1.
#
# Responsibilities:
#   1. Set up a SIGTERM / SIGINT trap that forwards to start.sh so the game
#      can save + exit cleanly before Kubernetes SIGKILLs us.
#   2. Launch start.sh (SteamCMD update + the game) in the background.
#   3. If AUTO_REBOOT_ENABLED=true, generate a crontab and launch supercronic
#      in the background. supercronic runs auto_reboot.sh on the schedule.
#   4. `wait` for start.sh to exit, then propagate its exit code.
#
# Pattern inspired by thijsvanloef/palworld-server-docker/scripts/init.sh —
# simpler because we skip REST API, Discord, player logging, auto-pause,
# player-count detection and the other heavy features palworld offers.
set -euo pipefail

# shellcheck source=./helper_functions.sh
source /home/steam/scripts/helper_functions.sh

MAIN_PID=""
SUPERCRONIC_PID=""

shutdown_handler() {
  log init "received shutdown signal, forwarding to start.sh (pid ${MAIN_PID:-?})"

  if [[ -n "$SUPERCRONIC_PID" ]] && kill -0 "$SUPERCRONIC_PID" 2>/dev/null; then
    kill -TERM "$SUPERCRONIC_PID" 2>/dev/null || true
  fi

  if [[ -n "$MAIN_PID" ]] && kill -0 "$MAIN_PID" 2>/dev/null; then
    kill -TERM "$MAIN_PID" 2>/dev/null || true
    # start.sh has its own trap that kills the game and waits for it.
    wait "$MAIN_PID" 2>/dev/null || true
  fi

  log init "shutdown complete"
  exit 0
}
trap shutdown_handler SIGTERM SIGINT

log init "launching start.sh"
/home/steam/scripts/start.sh &
MAIN_PID=$!

# --- supercronic (in-container cron daemon) ---
if is_truthy "${AUTO_REBOOT_ENABLED:-0}"; then
  CRON_EXPR="${AUTO_REBOOT_CRON_EXPRESSION:-0 4 * * *}"
  CRONTAB="/tmp/soulmask.crontab"
  printf '%s bash /home/steam/scripts/auto_reboot.sh\n' "$CRON_EXPR" > "$CRONTAB"
  log init "auto-reboot enabled, schedule=\"$CRON_EXPR\""

  if supercronic -test "$CRONTAB" >/dev/null 2>&1; then
    supercronic -passthrough-logs "$CRONTAB" &
    SUPERCRONIC_PID=$!
    log init "supercronic started (pid $SUPERCRONIC_PID)"
  else
    log_err init "invalid cron expression \"$CRON_EXPR\" — supercronic not started"
  fi
else
  log init "AUTO_REBOOT_ENABLED is not set/true — supercronic not started"
fi

# Block on the game process. If it exits (game crashed, scheduled reboot
# took effect, SIGTERM propagated), the container exits and k8s will
# restart us — which re-runs SteamCMD (pulling any new Soulmask build).
wait "$MAIN_PID"
EXIT_CODE=$?
log init "start.sh exited with code $EXIT_CODE — container will terminate"

# Reap supercronic if it's still around.
if [[ -n "$SUPERCRONIC_PID" ]] && kill -0 "$SUPERCRONIC_PID" 2>/dev/null; then
  kill -TERM "$SUPERCRONIC_PID" 2>/dev/null || true
  wait "$SUPERCRONIC_PID" 2>/dev/null || true
fi

exit "$EXIT_CODE"
