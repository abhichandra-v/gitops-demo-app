#!/usr/bin/env bash
# Scenario C: manual intervention inside the cluster while Argo CD selfHeal is
# on. Runs one Argo Rollouts command against the live Rollout and records what
# Argo CD and the Rollout do in the following minutes.
# Usage: scripts/demo-manual-undo.sh <undo|abort|retry|promote> [observe-seconds]
set -euo pipefail
. "$(dirname "$0")/lib.sh"
action="${1:?usage: demo-manual-undo.sh <undo|abort|retry|promote> [observe-seconds]}"
window="${2:-240}"
ns="${NAMESPACE:-demo-dev}"
cd "${REPO_ROOT}"

printf '# %s  state before\n' "$(ts)"
bash scripts/measure.sh --for 0
printf '# git says: %s\n' "$(yq e '.images[0].newTag' apps/demo-app/overlays/dev/kustomization.yaml)"
printf '# %s\n$ kubectl argo rollouts %s demo-app -n %s\n' "$(ts)" "$action" "$ns"
T0=$(date +%s)
kubectl-argo-rollouts --context "${KUBE_CONTEXT}" -n "$ns" "$action" demo-app
printf '# elapsed time (+Ns) counts from the command\n'
T0=$T0 bash scripts/measure.sh --for "$window"
echo
bash scripts/capture.sh "kubectl --context ${KUBE_CONTEXT} -n argocd get application demo-app -o jsonpath='{range .status.history[*]}{.deployedAt}  revision={.revision}  automated={.initiatedBy.automated}{\"\\n\"}{end}' | tail -n 5"
bash scripts/capture.sh "kubectl --context ${KUBE_CONTEXT} -n ${ns} get events --sort-by=.lastTimestamp --field-selector involvedObject.name=demo-app -o custom-columns='TIME:.lastTimestamp,REASON:.reason,MESSAGE:.message' | tail -n 15"
bash scripts/snapshot.sh
