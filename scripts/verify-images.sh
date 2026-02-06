#!/usr/bin/env bash
# Runs each release image locally and records what it actually returns.
# Usage: scripts/verify-images.sh > docs/evidence/phase-1/image-verification.txt
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; . ./versions.env; set +a

REQUESTS=200
PORT=18080
ts() { date -u +%Y-%m-%dT%H:%M:%SZ; }

while IFS='|' read -r tag color fault; do
  case "$tag" in ''|\#*) continue ;; esac
  image="${DEMO_APP_IMAGE}:${tag}"
  name="demo-verify-${tag//./-}"
  echo "===== $(ts) ${image} ====="
  docker rm -f "$name" >/dev/null 2>&1 || true
  echo "\$ docker run -d --name ${name} -p ${PORT}:8080 ${image}"
  docker run -d --name "$name" -p "${PORT}:8080" "$image" >/dev/null
  for _ in $(seq 1 30); do curl -fs "localhost:${PORT}/healthz" >/dev/null 2>&1 && break; sleep 0.5; done

  echo "\$ docker inspect -f '{{.Config.User}}' ${name}"
  docker inspect -f '{{.Config.User}}' "$name"
  echo "\$ curl -s localhost:${PORT}/healthz"
  curl -s "localhost:${PORT}/healthz"

  echo "\$ ${REQUESTS} x curl -s -o /dev/null -w '%{http_code}' localhost:${PORT}/ | sort | uniq -c"
  for _ in $(seq 1 "$REQUESTS"); do
    curl -s -o /dev/null -w '%{http_code}\n' "localhost:${PORT}/"
  done | sort | uniq -c

  echo "\$ curl -s localhost:${PORT}/  (one sample body)"
  curl -s "localhost:${PORT}/"
  echo "\$ curl -s localhost:${PORT}/metrics | grep -E '^(http_requests_total|demo_app_info|http_request_duration_seconds_count)'"
  curl -s "localhost:${PORT}/metrics" | grep -E '^(http_requests_total|demo_app_info|http_request_duration_seconds_count)'
  docker rm -f "$name" >/dev/null
  echo
done < app/releases.env
echo "===== $(ts) image sizes ====="
docker images "${DEMO_APP_IMAGE}" --format '{{.Repository}}:{{.Tag}}  {{.Size}}'
