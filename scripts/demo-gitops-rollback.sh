#!/usr/bin/env bash
# Scenario D: GitOps rollback. Reverts the most recent release commit, pushes
# main and records until the app is Synced/Healthy again.
# NOTE: this pushes to origin/main, because Argo CD only sees GitHub.
set -euo pipefail
. "$(dirname "$0")/lib.sh"
cd "${REPO_ROOT}"
[ "$(git branch --show-current)" = "main" ] || { echo "must run on main" >&2; exit 1; }
bad="$(git log -1 --format=%h --grep='^chore(release):')"
subject="$(git log -1 --format=%s "$bad")"
git revert --no-edit "$bad" >/dev/null
git commit -q --amend -m "revert: ${subject#chore(release): }" -m "This reverts commit ${bad}."
tag="$(yq e '.images[0].newTag' apps/demo-app/overlays/dev/kustomization.yaml)"
printf '# %s\n$ git revert --no-edit %s && git push origin main   (%s; dev back to %s)\n' "$(ts)" "$bad" "$(git log -1 --format='%h %s')" "$tag"
T0=$(date +%s)
git push -q origin main
printf '# elapsed time (+Ns) counts from the push\n'
T0=$T0 bash scripts/measure.sh --until "Synced/Healthy@$(git log -1 --format=%h | cut -c1-7).*phase=Healthy.*aborted= .*readyPods\[${tag}=5\]" --timeout 900 || true
echo
bash scripts/snapshot.sh
