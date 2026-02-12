#!/usr/bin/env bash
# Scenario A: good release. Bumps dev to the given tag (default v2.0.0),
# pushes main and records the canary until it is fully promoted.
# NOTE: this pushes to origin/main, because Argo CD only sees GitHub.
set -euo pipefail
cd "$(dirname "$0")/.."
tag="${1:-v2.0.0}"
bash scripts/run-release.sh "$tag" "Synced/Healthy.*phase=Healthy.*readyPods\[${tag}=5\]" 900
