SHELL := bash
.DEFAULT_GOAL := help

include versions.env
export

.PHONY: help doctor images cluster-up cluster-down bootstrap argocd-ui status check load-images demo-good demo-bad demo-undo demo-rollback demo-drift demo-argocd-down validate

help: ## List targets
	@grep -E '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | awk -F ':.*## ' '{printf "  %-16s %s\n", $$1, $$2}'

doctor: ## Check local prerequisites (installs nothing)
	@bash scripts/doctor.sh

images: ## Build the three demo app release images locally
	@bash scripts/build-images.sh

load-images: ## Load the release images into the kind nodes (GHCR fallback)
	@bash scripts/load-images.sh

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

validate: ## kustomize build, kubeconform, kube-score and Checkov
	@bash scripts/validate.sh all

demo-good: ## Scenario A: release v2.0.0 (pushes main)
	@bash scripts/demo-good-release.sh v2.0.0

demo-bad: ## Scenario B: release v3.0.0-bad and watch the automatic abort (pushes main)
	@bash scripts/demo-bad-release.sh

demo-undo: ## Scenario C: kubectl argo rollouts undo with selfHeal on
	@bash scripts/demo-manual-undo.sh undo

demo-rollback: ## Scenario D: git revert the last release (pushes main)
	@bash scripts/demo-gitops-rollback.sh

demo-drift: ## Scenario E: change replicas by hand and watch self-heal
	@bash scripts/demo-drift.sh replicas

demo-argocd-down: ## Scenario F: take Argo CD down and bring it back
	@bash scripts/demo-argocd-down.sh
