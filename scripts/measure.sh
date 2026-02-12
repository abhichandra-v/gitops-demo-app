#!/usr/bin/env bash
# Timestamped one-line-per-poll view of a release, used for every scenario so
# the evidence files are comparable.
#
# Usage: scripts/measure.sh [--until <regex>] [--timeout <seconds>] [--interval <seconds>]
#   --until    stop once the status line matches this regex for 2 polls in a row
#   --timeout  give up after this many seconds (default 600)
#   --for      just observe for this many seconds, then exit 0
# Environment: NAMESPACE (demo-dev), ROLLOUT (demo-app), APP (demo-app), T0 (epoch
# seconds the elapsed column counts from; default: now).
set -euo pipefail
. "$(dirname "$0")/lib.sh"

NAMESPACE="${NAMESPACE:-demo-dev}"; ROLLOUT="${ROLLOUT:-demo-app}"; APP="${APP:-demo-app}"
until_re=""; timeout=600; interval=3; observe=0
while [ $# -gt 0 ]; do
  case "$1" in
    --until) until_re="$2"; shift 2 ;;
    --timeout) timeout="$2"; shift 2 ;;
    --for) timeout="$2"; observe=1; shift 2 ;;
    --interval) interval="$2"; shift 2 ;;
    *) echo "unknown argument $1" >&2; exit 2 ;;
  esac
done
T0="${T0:-$(date +%s)}"

status_line() {
  local app ro pods
  app="$(k -n "${ARGOCD_NAMESPACE}" get application "${APP}" \
    -o jsonpath='{.status.sync.status}/{.status.health.status}@{.status.sync.revision}' 2>/dev/null || echo "unavailable")"
  app="${app%@*}@$(printf '%.7s' "${app##*@}")"
  ro="$(k -n "${NAMESPACE}" get rollout "${ROLLOUT}" \
    -o jsonpath='phase={.status.phase} step={.status.currentStepIndex} weight={.status.canary.weights.canary.weight} aborted={.status.abort} stable={.status.stableRS} current={.status.currentPodHash}' 2>/dev/null || echo "rollout=absent")"
  # ready pods per image tag
  pods="$(k -n "${NAMESPACE}" get pods -l app.kubernetes.io/name=demo-app \
    -o jsonpath='{range .items[*]}{.spec.containers[0].image}{" "}{.status.containerStatuses[0].ready}{"\n"}{end}' 2>/dev/null \
    | awk '{sub(/.*:/,"",$1); if ($2=="true") r[$1]++; else if (!($1 in r)) r[$1]+=0} END {n=asorti(r,s); for(i=1;i<=n;i++) printf "%s%s=%d", (i>1?",":""), s[i], r[s[i]]}')"
  printf 'argocd=%s  %s  readyPods[%s]' "$app" "$ro" "${pods:-none}"
}

hits=0
while :; do
  now=$(date +%s); line="$(status_line)"
  printf '%s  +%4ds  %s\n' "$(ts)" "$((now - T0))" "$line"
  if [ -n "$until_re" ] && [[ "$line" =~ $until_re ]]; then
    hits=$((hits + 1)); [ "$hits" -ge 2 ] && exit 0
  else
    hits=0
  fi
  if [ $((now - T0)) -ge "$timeout" ] && [ "$observe" = 1 ]; then exit 0; fi
  if [ $((now - T0)) -ge "$timeout" ]; then echo "measure: timed out after ${timeout}s" >&2; exit 1; fi
  sleep "$interval"
done
