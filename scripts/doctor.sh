#!/usr/bin/env bash
# Checks that the local prerequisites are present. Installs nothing.
set -uo pipefail
. "$(dirname "$0")/lib.sh"

MIN_DOCKER_MEM_GB=6
missing=()
warnings=()

check() {
  local name="$1" version_cmd="$2" pinned="${3:-}"
  if ! command -v "$name" >/dev/null 2>&1; then
    printf '  MISSING  %-22s (pinned: %s)\n' "$name" "${pinned:-n/a}"
    missing+=("$name")
    return
  fi
  local got
  got="$(eval "$version_cmd" 2>/dev/null | head -n1)"
  printf '  ok       %-22s %s' "$name" "${got:-version unknown}"
  if [ -n "$pinned" ] && [ -n "$got" ] && [[ "$got" != *"${pinned#v}"* ]]; then
    printf '   (pinned: %s)' "$pinned"
    warnings+=("$name is $got, versions.env pins $pinned")
  fi
  printf '\n'
}

echo "Tools:"
check docker                "docker version --format '{{.Client.Version}}'"
check kind                  "kind version"                                    "${KIND_VERSION:-}"
check kubectl               "kubectl version --client -o yaml | grep gitVersion | awk '{print \$2}'" "${KUBECTL_VERSION:-}"
check helm                  "helm version --short"                            "${HELM_VERSION:-}"
check kustomize             "kustomize version"                               "${KUSTOMIZE_VERSION:-}"
check argocd                "argocd version --client --short"                 "${ARGOCD_CLI_VERSION:-}"
check kubectl-argo-rollouts "kubectl-argo-rollouts version --short"           "${ARGO_ROLLOUTS_PLUGIN_VERSION:-}"
check go                    "go version"                                      "${GO_VERSION:-}"
check make                  "make --version"
check yq                    "yq --version"                                    "${YQ_VERSION:-}"

echo
echo "Docker daemon:"
if command -v docker >/dev/null 2>&1 && mem_bytes="$(docker info --format '{{.MemTotal}}' 2>/dev/null)" && [ "${mem_bytes:-0}" -gt 0 ]; then
  mem_gb=$((mem_bytes / 1024 / 1024 / 1024))
  if [ "$mem_gb" -lt "$MIN_DOCKER_MEM_GB" ]; then
    printf '  LOW      %s GB available to Docker, about %s GB needed\n' "$mem_gb" "$MIN_DOCKER_MEM_GB"
    warnings+=("Docker has ${mem_gb} GB RAM; the full stack wants about ${MIN_DOCKER_MEM_GB} GB")
  else
    printf '  ok       %s GB available to Docker\n' "$mem_gb"
  fi
else
  echo "  DOWN     docker daemon not reachable (is Docker running?)"
  missing+=("docker-daemon")
fi

echo
for w in "${warnings[@]:-}"; do [ -n "$w" ] && echo "warning: $w"; done
if [ "${#missing[@]}" -gt 0 ]; then
  echo "doctor: missing: ${missing[*]}"
  echo "Install them yourself; this target does not install anything."
  exit 1
fi
echo "doctor: all prerequisites present"
