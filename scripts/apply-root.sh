#!/usr/bin/env bash
# Hands the cluster over to Git: creates the AppProjects and the root
# Application. Everything else is created by Argo CD from argocd/.
set -euo pipefail
. "$(dirname "$0")/lib.sh"
# The projects are also in argocd/ (and so managed by the root app); applying
# them first lets the root app reference its project on first sync.
k apply -f "${REPO_ROOT}/argocd/projects.yaml"
k apply -f "${REPO_ROOT}/bootstrap/root-app.yaml"
log "root application applied; watch with: make status"
