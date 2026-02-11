#!/usr/bin/env bash
# Releases a tag the GitOps way and records what happens:
# commit the tag bump, push main, then poll until the given state is reached.
# Usage: scripts/run-release.sh <tag> '<until-regex>' [timeout-seconds]
# Output goes to stdout; redirect it into docs/evidence/.
set -euo pipefail
. "$(dirname "$0")/lib.sh"
tag="$1"; until_re="$2"; timeout="${3:-600}"
cd "${REPO_ROOT}"
bash scripts/release.sh "$tag" dev
printf '# %s\n$ git push origin main   (%s)\n' "$(ts)" "$(git log -1 --format='%h %s')"
T0=$(date +%s)
git push -q origin main
printf '# elapsed time (+Ns) counts from the push\n$ scripts/measure.sh --until %q\n' "$until_re"
T0=$T0 bash scripts/measure.sh --until "$until_re" --timeout "$timeout" || true
echo
bash scripts/snapshot.sh
