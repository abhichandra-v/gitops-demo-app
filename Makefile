SHELL := bash
.DEFAULT_GOAL := help

include versions.env
export

.PHONY: help doctor images cluster-up cluster-down bootstrap argocd-ui status check

help: ## List targets
	@grep -E '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | awk -F ':.*## ' '{printf "  %-16s %s\n", $$1, $$2}'

doctor: ## Check local prerequisites (installs nothing)
	@bash scripts/doctor.sh

images: ## Build the three demo app release images locally
	@bash scripts/build-images.sh

cluster-up: ## Create the kind cluster
	@bash scripts/cluster-up.sh

cluster-down: ## Delete the kind cluster
	@bash scripts/cluster-down.sh

bootstrap: ## Install Argo CD, then hand the cluster over to Git (root app)
	@bash bootstrap/install-argocd.sh
	@bash scripts/apply-root.sh

argocd-ui: ## Port-forward the Argo CD UI to localhost
	@bash scripts/argocd-ui.sh

status: ## Show sync/health of all Argo CD applications
	@bash scripts/status.sh

check: ## Static checks for platform charts and pinned versions
	@bash scripts/check-platform.sh
