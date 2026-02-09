#!/usr/bin/env bash
# Prepares a release commit: bumps the image tag in an overlay. It does not
# push; pushing main is what actually releases.
# Usage: scripts/release.sh <tag> [overlay]     e.g. scripts/release.sh v2.0.0 dev
set -euo pipefail
. "$(dirname "$0")/lib.sh"
tag="${1:?usage: release.sh <tag> [overlay]}"; overlay="${2:-dev}"
file="apps/demo-app/overlays/${overlay}/kustomization.yaml"
cd "${REPO_ROOT}"
grep -q "^${tag}|" app/releases.env || { echo "unknown release tag ${tag} (see app/releases.env)" >&2; exit 1; }
old="$(yq e '.images[0].newTag' "$file")"
[ "$old" = "$tag" ] && { echo "${overlay} is already at ${tag}"; exit 0; }
yq e -i ".images[0].newTag = \"${tag}\"" "$file"
git add "$file"
git commit -q -m "chore(release): demo-app ${tag} in ${overlay}" -m "Previous: ${old}"
log "committed: demo-app ${old} -> ${tag} in ${overlay}. Release it with: git push origin main"
