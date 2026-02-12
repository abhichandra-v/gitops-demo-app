#!/usr/bin/env bash
# Scenario F: Argo CD unavailable. Takes the application controller and the API
# server down, shows the app keeps serving and that drift is no longer healed,
# then brings the controller back and records the recovery.
set -euo pipefail
. "$(dirname "$0")/lib.sh"
ns="${NAMESPACE:-demo-dev}"
A="${ARGOCD_NAMESPACE}"
KC=(kubectl --context "${KUBE_CONTEXT}")

serving() {
  curl -s -m 5 -H 'Host: demo.localtest.me' 'http://localhost/?r=[1-50]' \
    | grep -o '"version":"[^"]*"' | sort | uniq -c \
    | awk '{gsub(/"version":|"/,"",$2); printf "%s x%d ", $2, $1}'
}

line() {
  printf '%s  +%3ds  controller=%s server=%s  app=%s  rollout.replicas=%s ready=%s  serving(50 req): %s\n' \
    "$(ts)" "$(( $(date +%s) - T0 ))" \
    "$(k -n "$A" get sts argocd-application-controller -o jsonpath='{.status.readyReplicas}/{.spec.replicas}')" \
    "$(k -n "$A" get deploy argocd-server -o jsonpath='{.status.readyReplicas}/{.spec.replicas}')" \
    "$(k -n "$A" get application demo-app -o jsonpath='{.status.sync.status}/{.status.health.status}')" \
    "$(k -n "$ns" get rollout demo-app -o jsonpath='{.spec.replicas}')" \
    "$(k -n "$ns" get rollout demo-app -o jsonpath='{.status.readyReplicas}')" \
    "$(serving)"
}

watch_for() {
  local end=$(( $(date +%s) + $1 ))
  while [ "$(date +%s)" -lt "$end" ]; do line; sleep "${2:-5}"; done
}

step() {
  printf '\n# %s  %s\n' "$(ts)" "$1"; shift
  if [ $# -gt 0 ]; then printf '$ %s\n' "$*"; "$@"; fi
}

T0=$(date +%s)

step "baseline"
watch_for 10

step "1. scale argocd-server to 0 while the application controller is still running" \
  "${KC[@]}" -n "$A" scale deploy argocd-server --replicas=0
watch_for 60

step "2. scale the application controller to 0, then the server" \
  "${KC[@]}" -n "$A" scale sts argocd-application-controller --replicas=0
"${KC[@]}" -n "$A" scale deploy argocd-server --replicas=0
watch_for 45

step "3. Argo CD is down: introduce drift (rollout replicas 5 -> 3)" \
  "${KC[@]}" -n "$ns" patch rollout demo-app --type merge -p '{"spec":{"replicas":3}}'
watch_for 75

step "4. restore only the application controller" \
  "${KC[@]}" -n "$A" scale sts argocd-application-controller --replicas=1
T_RESTORE=$(date +%s)
for _ in $(seq 1 60); do
  line
  ok="$(k -n "$A" get application demo-app -o jsonpath='{.status.sync.status}/{.status.health.status}') $(k -n "$ns" get rollout demo-app -o jsonpath='{.spec.replicas}/{.status.readyReplicas}') $(k -n "$A" get deploy argocd-server -o jsonpath='{.status.readyReplicas}')"
  [ "$ok" = "Synced/Healthy 5/5 1" ] && break
  sleep 5
done
printf '# %s  recovered %ss after the controller was scaled back up\n' "$(ts)" "$(( $(date +%s) - T_RESTORE ))"
line
