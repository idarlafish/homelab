#!/usr/bin/env bash
# Scheduled auto-reboot, invoked by supercronic inside the container.
#
# Sends SIGTERM to PID 1 (init.sh), which triggers the full graceful
# shutdown chain: init.sh forwards SIGTERM to start.sh, start.sh forwards
# to WSServer-Linux-Shipping, the game saves and exits, start.sh exits,
# init.sh exits. The container then terminates and Kubernetes' restart
# policy (default "Always") brings it back up — which re-runs SteamCMD
# and so picks up any new Soulmask build. In short: this is our
# auto-update-via-restart knob.
set -euo pipefail

# shellcheck source=./helper_functions.sh
source /home/steam/scripts/helper_functions.sh

log reboot "scheduled auto-reboot triggered, signalling PID 1 for graceful shutdown"
kill -TERM 1
