#!/usr/bin/env bash
# Builds the three release images locally. CI builds and pushes the same set.
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; . ./versions.env; set +a

while IFS='|' read -r tag color fault; do
  case "$tag" in ''|\#*) continue ;; esac
  echo ">> building ${DEMO_APP_IMAGE}:${tag} (color=${color} fault=${fault:-none})"
  docker build -q \
    --build-arg GO_VERSION="${GO_VERSION}" \
    --build-arg VERSION="${tag}" \
    --build-arg COLOR="${color}" \
    --build-arg FAULT_MODE="${fault}" \
    -t "${DEMO_APP_IMAGE}:${tag}" app
done < app/releases.env
