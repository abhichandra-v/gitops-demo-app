SHELL := bash
.DEFAULT_GOAL := help

include versions.env
export

.PHONY: help doctor images cluster-up cluster-down

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
