#!/usr/bin/env bash
# Measures the real traffic split through the ingress while a canary is paused.
# Waits for the Rollout to pause at the given step, then takes several samples
# of N requests each through http://localhost (Host: demo.localtest.me) and
# counts responses per version. Several samples, because the first seconds
# after a weight change are not representative.
# Usage: scripts/measure-split.sh [step-index] [requests-per-sample] [samples] [gap-seconds]
set -euo pipefail
. "$(dirname "$0")/lib.sh"
step="${1:-1}"; n="${2:-200}"; samples="${3:-5}"; gap="${4:-3}"; ns="${NAMESPACE:-demo-dev}"

log "waiting for rollout to pause at step ${step}"
s=""
for _ in $(seq 1 200); do
  s="$(k -n "$ns" get rollout demo-app -o jsonpath='{.status.phase}/{.status.currentStepIndex}')"
  [ "$s" = "Paused/${step}" ] && break; sleep 1
done
[ "$s" = "Paused/${step}" ] || { echo "rollout never reached Paused/${step} (last: $s)" >&2; exit 1; }
t_pause=$(date +%s)
log "rollout is ${s}; setWeight=$(k -n "$ns" get rollout demo-app -o jsonpath='{.status.canary.weights.canary.weight}')"
k -n "$ns" get ingress -o jsonpath='{range .items[*]}{"  ingress "}{.metadata.name}{"  canary="}{.metadata.annotations.nginx\.ingress\.kubernetes\.io/canary}{" canary-weight="}{.metadata.annotations.nginx\.ingress\.kubernetes\.io/canary-weight}{"\n"}{end}'

for i in $(seq 1 "$samples"); do
  now=$(date +%s)
  counts="$(curl -s -H 'Host: demo.localtest.me' "http://localhost/?r=[1-${n}]" \
    | grep -o '"version":"[^"]*"' | sort | uniq -c \
    | awk -v n="$n" '{gsub(/"version":|"/,"",$2); printf "%s=%d (%.1f%%)  ", $2, $1, 100*$1/n}')"
  printf '%s  sample %d  +%2ds after pause  %d requests:  %s  rollout=%s\n' "$(ts)" "$i" "$((now - t_pause))" "$n" "$counts" \
    "$(k -n "$ns" get rollout demo-app -o jsonpath='{.status.phase}/{.status.currentStepIndex}')"
  sleep "$gap"
done
