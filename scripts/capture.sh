#!/usr/bin/env bash
# Runs a command and prints it with a UTC timestamp, for evidence files.
# Usage: scripts/capture.sh 'kubectl get pods -A' >> docs/evidence/<file>.txt
set -uo pipefail
. "$(dirname "$0")/lib.sh"
printf '# %s\n$ %s\n' "$(ts)" "$*"
bash -c "$*" 2>&1
printf '\n'
