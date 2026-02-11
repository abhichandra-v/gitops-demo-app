#!/usr/bin/env bash
# Runs an instant PromQL query against the in-cluster Prometheus through the
# Kubernetes API server proxy (no port-forward needed).
# Usage: scripts/promql.sh 'sum(rate(http_requests_total[1m]))'
set -euo pipefail
. "$(dirname "$0")/lib.sh"
q="$(printf '%s' "$1" | od -An -tx1 | tr -d '\n' | sed 's/ /%/g')"
k get --raw "/api/v1/namespaces/monitoring/services/kps-prometheus:9090/proxy/api/v1/query?query=${q}" \
  | yq -p json -o yaml '.data.result[] | [(.metric | to_entries | map(.key + "=" + .value) | join(",")), .value[1]] | join("  ")'
