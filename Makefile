SHELL := bash
.DEFAULT_GOAL := help

include versions.env
export

.PHONY: help doctor

help: ## List targets
	@grep -E '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | awk -F ':.*## ' '{printf "  %-16s %s\n", $$1, $$2}'

doctor: ## Check local prerequisites (installs nothing)
	@bash scripts/doctor.sh
