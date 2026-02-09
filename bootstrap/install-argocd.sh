#!/usr/bin/env bash
# First install of Argo CD from the official Helm chart at the pinned version.
# After this, Argo CD manages its own release from Git (see argocd/).
set -euo pipefail
. "$(dirname "$0")/../scripts/lib.sh"

log "installing argo-cd chart ${ARGOCD_CHART_VERSION} into namespace ${ARGOCD_NAMESPACE}"
helm upgrade --install argocd argo-cd \
  --repo https://argoproj.github.io/argo-helm \
  --version "${ARGOCD_CHART_VERSION}" \
  --kube-context "${KUBE_CONTEXT}" \
  --namespace "${ARGOCD_NAMESPACE}" --create-namespace \
  --values "${REPO_ROOT}/platform/argo-cd/values.yaml" \
  --wait --timeout 10m

k -n "${ARGOCD_NAMESPACE}" get pods

cat <<MSG

Argo CD is installed.

UI:        make argocd-ui      (then open http://localhost:${ARGOCD_UI_PORT:-8443})
User:      admin
Password:  print it to your terminal only, never into a file in this repo:

  kubectl --context ${KUBE_CONTEXT} -n ${ARGOCD_NAMESPACE} get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
MSG
