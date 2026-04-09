#!/usr/bin/env bash
# Small helper library sourced by the other soulmask scripts.
# Pattern borrowed from thijsvanloef/palworld-server-docker/scripts/helper_functions.sh,
# kept deliberately tiny because our feature set is much smaller.

# Print a log line prefixed with [soulmask] and a component tag, so that
# output from init / start / auto_reboot is easy to distinguish in kubectl logs.
# Usage: log "component" "message"
log() {
  local component="$1"
  shift
  printf '[soulmask] [%s] %s\n' "$component" "$*"
}

log_warn() {
  local component="$1"
  shift
  printf '[soulmask] [%s] WARNING: %s\n' "$component" "$*" >&2
}

log_err() {
  local component="$1"
  shift
  printf '[soulmask] [%s] ERROR: %s\n' "$component" "$*" >&2
}

# Return 0 (true) if the argument is a common "truthy" string — used for
# env-var feature flags like AUTO_REBOOT_ENABLED=true.
is_truthy() {
  case "${1,,}" in
    1|true|on|yes) return 0 ;;
    *) return 1 ;;
  esac
}
