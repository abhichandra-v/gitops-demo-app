#!/usr/bin/env bash
# Manifest validation, identical locally and in CI.
# Usage: scripts/validate.sh [render|kubeconform|kube-score|checkov|all]
set -euo pipefail
. "$(dirname "$0")/lib.sh"
cd "${REPO_ROOT}"
OUT="${RENDER_DIR:-rendered}"
CRD_SCHEMAS='https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json'

render() {
  rm -rf "${OUT}"; mkdir -p "${OUT}/overlays" "${OUT}/scoring"
  for dir in apps/*/overlays/*/; do
    app="$(basename "$(dirname "$(dirname "$dir")")")"; env="$(basename "$dir")"
    kustomize build "$dir" > "${OUT}/overlays/${app}-${env}.yaml"
    echo "rendered ${dir} -> ${OUT}/overlays/${app}-${env}.yaml"
    # kube-score and Checkov do not understand the Rollout kind, so its pod
    # template would go unchecked. Score it as the Deployment it replaces.
    yq e '(select(.kind == "Rollout") | .apiVersion) = "apps/v1"
          | (select(.kind == "Rollout") | .spec.strategy) = {"type": "RollingUpdate"}
          | (select(.kind == "Rollout") | .kind) = "Deployment"
          | select(.kind != "AnalysisTemplate" and .kind != "PodMonitor")' \
      "${OUT}/overlays/${app}-${env}.yaml" > "${OUT}/scoring/${app}-${env}.yaml"
  done
}

run_kubeconform() {
  kubeconform -strict -summary \
    -kubernetes-version "${KIND_NODE_K8S_VERSION}" \
    -schema-location default -schema-location "${CRD_SCHEMAS}" \
    "${OUT}/overlays" argocd bootstrap/root-app.yaml
}

run_kube_score() {
  # Skips are documented in docs/VALIDATION.md.
  kube-score score \
    --ignore-test container-image-pull-policy \
    --ignore-test pod-networkpolicy \
    "${OUT}"/scoring/*.yaml
}

run_checkov() {
  if command -v checkov >/dev/null 2>&1; then
    checkov --framework kubernetes --config-file .checkov.yaml -d "${OUT}/scoring" --compact --quiet
  else
    MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W 2>/dev/null || pwd):/src" -w /src \
      "bridgecrew/checkov:${CHECKOV_VERSION}" \
      --framework kubernetes --config-file .checkov.yaml -d "${OUT}/scoring" --compact --quiet
  fi
}

case "${1:-all}" in
  render) render ;;
  kubeconform) render; run_kubeconform ;;
  kube-score) render; run_kube_score ;;
  checkov) render; run_checkov ;;
  all) render; run_kubeconform; run_kube_score; run_checkov ;;
  *) echo "usage: $0 [render|kubeconform|kube-score|checkov|all]" >&2; exit 2 ;;
esac
