#!/usr/bin/env bash
# Prints sync and health of every Argo CD Application.
# With --wait [seconds], blocks until all are Synced and Healthy.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

show() {
  k -n "${ARGOCD_NAMESPACE}" get applications.argoproj.io \
    -o custom-columns='NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status,REVISION:.status.sync.revision'
}

if [ "${1:-}" != "--wait" ]; then show; exit 0; fi
deadline=$(( $(date +%s) + ${2:-900} ))
while :; do
  not_ready="$(k -n "${ARGOCD_NAMESPACE}" get applications.argoproj.io \
    -o jsonpath='{range .items[*]}{.metadata.name}={.status.sync.status}/{.status.health.status}{"\n"}{end}' \
    | grep -v '=Synced/Healthy$' || true)"
  count="$(k -n "${ARGOCD_NAMESPACE}" get applications.argoproj.io --no-headers 2>/dev/null | wc -l)"
  if [ -z "$not_ready" ] && [ "$count" -ge "${MIN_APPS:-1}" ]; then
    log "all ${count} applications Synced/Healthy"; show; exit 0
  fi
  if [ "$(date +%s)" -ge "$deadline" ]; then
    log "timed out; not ready:"; echo "$not_ready"; show; exit 1
  fi
  sleep 5
done
