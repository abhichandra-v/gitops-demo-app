#!/usr/bin/env bash
# Creates the kind cluster if it does not already exist.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

if kind get clusters 2>/dev/null | grep -qx "${KIND_CLUSTER_NAME}"; then
  log "kind cluster ${KIND_CLUSTER_NAME} already exists"
else
  log "creating kind cluster ${KIND_CLUSTER_NAME} (${KIND_NODE_IMAGE%%@*})"
  kind create cluster \
    --name "${KIND_CLUSTER_NAME}" \
    --image "${KIND_NODE_IMAGE}" \
    --config "${REPO_ROOT}/bootstrap/kind-config.yaml" \
    --wait 180s
fi
k get nodes -o wide
