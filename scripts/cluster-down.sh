#!/usr/bin/env bash
# Deletes the kind cluster. Everything in it is rebuilt from Git by
# `make cluster-up bootstrap`.
set -euo pipefail
. "$(dirname "$0")/lib.sh"
kind delete cluster --name "${KIND_CLUSTER_NAME}"
