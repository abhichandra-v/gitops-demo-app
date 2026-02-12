#!/usr/bin/env bash
# Scenario B: bad release. Bumps dev to v3.0.0-bad, pushes main and records
# until the analysis has aborted the rollout and the canary is gone.
# NOTE: this pushes to origin/main, because Argo CD only sees GitHub.
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/run-release.sh v3.0.0-bad 'phase=Degraded.*aborted=true.*readyPods\[v[12]\.0\.0=5\]' 900
