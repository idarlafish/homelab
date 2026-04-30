#!/usr/bin/env bash
# data.external program: SSH into a freshly-provisioned k3s server and return
# its kubeconfig as base64. Tofu's yamldecode parses the rest. Relies on
# ssh-agent (or ~/.ssh/config) being set up by the caller.
set -euo pipefail

eval "$(jq -r '@sh "HOST=\(.host)"')"

KUBECONFIG_RAW=$(ssh \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o LogLevel=ERROR \
  -o ConnectTimeout=10 \
  "root@${HOST}" 'cat /root/.kube/config')

KUBECONFIG_B64=$(printf '%s' "$KUBECONFIG_RAW" | base64 | tr -d '\n')

jq -n --arg b64 "$KUBECONFIG_B64" '{kubeconfig_b64: $b64}'
