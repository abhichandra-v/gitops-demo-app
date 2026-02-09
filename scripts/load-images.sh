#!/usr/bin/env bash
# Loads the locally built release images into the kind nodes, so the cluster
# does not need to pull from GHCR. See docs/DECISIONS/0005-image-delivery.md.
set -euo pipefail
. "$(dirname "$0")/lib.sh"
images=()
while IFS='|' read -r tag _; do
  case "$tag" in ''|\#*) continue ;; esac
  images+=("${DEMO_APP_IMAGE}:${tag}")
done < "${REPO_ROOT}/app/releases.env"
log "loading ${images[*]} into kind cluster ${KIND_CLUSTER_NAME}"
kind load docker-image --name "${KIND_CLUSTER_NAME}" "${images[@]}"
