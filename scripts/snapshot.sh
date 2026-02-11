#!/usr/bin/env bash
# Prints the state that matters after a release: Argo CD app, Rollout tree,
# AnalysisRuns with their measurements, and who is serving traffic.
set -uo pipefail
. "$(dirname "$0")/lib.sh"
ns="${NAMESPACE:-demo-dev}"
cap() { bash "${REPO_ROOT}/scripts/capture.sh" "$@"; }
cap "kubectl --context ${KUBE_CONTEXT} -n argocd get application demo-app -o jsonpath='sync={.status.sync.status} health={.status.health.status} revision={.status.sync.revision}{\"\n\"}'"
cap "git log -1 --format='git main: %h %s'; yq e '.images[0].newTag' apps/demo-app/overlays/dev/kustomization.yaml | sed 's/^/git image tag: /'"
cap "kubectl-argo-rollouts --context ${KUBE_CONTEXT} -n ${ns} get rollout demo-app --no-color"
cap "kubectl --context ${KUBE_CONTEXT} -n ${ns} get analysisrun --sort-by=.metadata.creationTimestamp -o custom-columns='NAME:.metadata.name,PHASE:.status.phase,MESSAGE:.status.message,STARTED:.status.startedAt'"
cap "kubectl --context ${KUBE_CONTEXT} -n ${ns} get analysisrun --sort-by=.metadata.creationTimestamp -o jsonpath='{range .items[*]}{.metadata.name}{\"  \"}{.status.phase}{\"\n\"}{range .status.metricResults[*].measurements[*]}{\"    \"}{.startedAt}{\"  \"}{.phase}{\"  value=\"}{.value}{\" \"}{.message}{\"\n\"}{end}{end}' | tail -n 14"
cap "bash scripts/promql.sh 'sum by (rollouts_pod_template_hash,code)(rate(http_requests_total[1m]))'"
cap "curl -s -H 'Host: demo.localtest.me' 'http://localhost/?r=[1-200]' | grep -o '\"version\":\"[^\"]*\"\|\"error\":\"[^\"]*\"' | sort | uniq -c"
