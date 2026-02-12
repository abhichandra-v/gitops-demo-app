#!/usr/bin/env bash
# Scenario E: drift. Changes the live Rollout by hand (replicas or image) and
# records how Argo CD selfHeal puts Git's state back.
# Usage: scripts/demo-drift.sh <replicas|image> [observe-seconds]
set -euo pipefail
. "$(dirname "$0")/lib.sh"
what="${1:?usage: demo-drift.sh <replicas|image> [observe-seconds]}"
window="${2:-90}"
ns="${NAMESPACE:-demo-dev}"
cd "${REPO_ROOT}"

spec() { k -n "$ns" get rollout demo-app -o jsonpath='replicas={.spec.replicas} image={.spec.template.spec.containers[0].image}'; }

printf '# %s  before: %s\n' "$(ts)" "$(spec)"
case "$what" in
  replicas)
    cmd=(kubectl --context "${KUBE_CONTEXT}" -n "$ns" patch rollout demo-app --type merge -p '{"spec":{"replicas":2}}') ;;
  image)
    cmd=(kubectl --context "${KUBE_CONTEXT}" -n "$ns" patch rollout demo-app --type json -p '[{"op":"replace","path":"/spec/template/spec/containers/0/image","value":"ghcr.io/abhichandra-v/gitops-demo-app:v1.0.0"}]') ;;
  *) echo "unknown drift type $what" >&2; exit 2 ;;
esac
printf '# %s\n$ %s\n' "$(ts)" "${cmd[*]}"
T0=$(date +%s)
"${cmd[@]}"
end=$((T0 + window))
while [ "$(date +%s)" -lt "$end" ]; do
  printf '%s  +%3ds  live: %s  argocd=%s  readyPods=%s\n' "$(ts)" "$(( $(date +%s) - T0 ))" "$(spec)" \
    "$(k -n argocd get application demo-app -o jsonpath='{.status.sync.status}/{.status.health.status}')" \
    "$(k -n "$ns" get rollout demo-app -o jsonpath='{.status.readyReplicas}')"
  sleep 2
done
echo
bash scripts/capture.sh "kubectl --context ${KUBE_CONTEXT} -n argocd get application demo-app -o jsonpath='{range .status.history[*]}{.deployedAt}  revision={.revision}  automated={.initiatedBy.automated}{\"\\n\"}{end}' | tail -n 4"
