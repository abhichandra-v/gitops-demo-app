#!/usr/bin/env bash
# Static checks for the platform definitions:
#  - every Application's chart version matches versions.env
#  - every chart renders with its values file at that version
set -euo pipefail
. "$(dirname "$0")/lib.sh"
cd "${REPO_ROOT}"
fail=0

check() { # app-file chart repo pinned-version release namespace
  local got
  got="$(yq e '.spec.sources[0].targetRevision' "argocd/$1.yaml")"
  if [ "$got" != "$4" ]; then
    echo "FAIL  argocd/$1.yaml pins $2 $got, versions.env says $4"; fail=1
  fi
  if helm template "$5" "$2" --repo "$3" --version "$4" -n "$6" \
       -f "platform/$2/values.yaml" > "${RENDER_DIR:-/dev/null}${RENDER_DIR:+/$2.yaml}"; then
    echo "ok    $2 $4 renders with platform/$2/values.yaml"
  else
    echo "FAIL  $2 $4 does not render"; fail=1
  fi
}

[ -n "${RENDER_DIR:-}" ] && mkdir -p "${RENDER_DIR}"
check argocd                argo-cd               https://argoproj.github.io/argo-helm               "${ARGOCD_CHART_VERSION}"                argocd                argocd
check argo-rollouts         argo-rollouts         https://argoproj.github.io/argo-helm               "${ARGO_ROLLOUTS_CHART_VERSION}"         argo-rollouts         argo-rollouts
check ingress-nginx         ingress-nginx         https://kubernetes.github.io/ingress-nginx         "${INGRESS_NGINX_CHART_VERSION}"         ingress-nginx         ingress-nginx
check kube-prometheus-stack kube-prometheus-stack https://prometheus-community.github.io/helm-charts "${KUBE_PROMETHEUS_STACK_CHART_VERSION}" kube-prometheus-stack monitoring

for f in argocd/*.yaml bootstrap/root-app.yaml; do
  url="$(yq e 'select(.kind == "Application") | (.spec.source.repoURL // .spec.sources[1].repoURL)' "$f" | { grep -v '^---$' || true; } | sort -u)"
  if [ -n "$url" ] && [ "$url" != "${GIT_REPO_URL}" ]; then
    echo "FAIL  $f points at $url, versions.env says ${GIT_REPO_URL}"; fail=1
  fi
done
exit $fail
