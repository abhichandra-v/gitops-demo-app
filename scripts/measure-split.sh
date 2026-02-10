#!/usr/bin/env bash
# Measures the real traffic split through the ingress while a canary is paused.
# Waits for the Rollout to pause at the given step, sends N requests through
# http://localhost (Host: demo.localtest.me) and counts responses per version.
# Usage: scripts/measure-split.sh [step-index] [requests]
set -euo pipefail
. "$(dirname "$0")/lib.sh"
step="${1:-1}"; n="${2:-500}"; ns="${NAMESPACE:-demo-dev}"

log "waiting for rollout to pause at step ${step}"
for _ in $(seq 1 200); do
  s="$(k -n "$ns" get rollout demo-app -o jsonpath='{.status.phase}/{.status.currentStepIndex}')"
  [ "$s" = "Paused/${step}" ] && break; sleep 1
done
[ "$s" = "Paused/${step}" ] || { echo "rollout never reached Paused/${step} (last: $s)" >&2; exit 1; }
log "rollout is ${s}; setWeight=$(k -n "$ns" get rollout demo-app -o jsonpath='{.status.canary.weights.canary.weight}')"
log "canary ingress annotations:"
k -n "$ns" get ingress -o jsonpath='{range .items[*]}{.metadata.name}{"  canary="}{.metadata.annotations.nginx\.ingress\.kubernetes\.io/canary}{" weight="}{.metadata.annotations.nginx\.ingress\.kubernetes\.io/canary-weight}{"\n"}{end}'
log "sending ${n} requests to http://localhost/ with Host: demo.localtest.me"
curl -s -H 'Host: demo.localtest.me' "http://localhost/?r=[1-${n}]" \
  | grep -o '"version":"[^"]*"' | sort | uniq -c \
  | awk -v n="$n" '{printf "  %5d  %-22s %5.1f%%\n", $1, $2, 100*$1/n}'
log "rollout after sampling: $(k -n "$ns" get rollout demo-app -o jsonpath='{.status.phase}/{.status.currentStepIndex}')"
