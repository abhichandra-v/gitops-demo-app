#!/usr/bin/env bash
# Port-forwards the Argo CD UI/API to localhost. Ctrl-C to stop.
set -euo pipefail
. "$(dirname "$0")/lib.sh"
PORT="${ARGOCD_UI_PORT:-8443}"
log "Argo CD UI at http://localhost:${PORT} (user: admin)"
k -n "${ARGOCD_NAMESPACE}" port-forward svc/argocd-server "${PORT}:80"
