# Sourced by the other scripts: loads pinned versions and common helpers.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
set -a; . "${REPO_ROOT}/versions.env"; set +a

# Optional repo-local tool directory (gitignored), used when tools are not
# installed system-wide.
if [ -d "${REPO_ROOT}/.bin" ]; then
  PATH="${REPO_ROOT}/.bin:${REPO_ROOT}/.bin/go/bin:${PATH}"
fi

# Keep Helm's repo config and cache out of the user's global Helm state.
export HELM_REPOSITORY_CONFIG="${REPO_ROOT}/.bin/helm/repositories.yaml"
export HELM_REPOSITORY_CACHE="${REPO_ROOT}/.bin/helm/cache"
mkdir -p "${HELM_REPOSITORY_CACHE}"

KUBE_CONTEXT="kind-${KIND_CLUSTER_NAME}"
ARGOCD_NAMESPACE=argocd

ts()  { date -u +%Y-%m-%dT%H:%M:%SZ; }
log() { printf '%s  %s\n' "$(ts)" "$*"; }
k()   { kubectl --context "${KUBE_CONTEXT}" "$@"; }
