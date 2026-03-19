# Oracle-OS Makefile
# ──────────────────────────────────────────────

.PHONY: build run clean test sidecars index reset help microvm-rootfs microvm-check

SWIFT := swift
BUILD_DIR := .build

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

build: ## Build the Oracle runtime
	$(SWIFT) build

run: build ## Build and run Oracle
	$(BUILD_DIR)/debug/oracle

clean: ## Clean build artifacts
	$(SWIFT) package clean
	rm -rf $(BUILD_DIR)

test: ## Run tests
	$(SWIFT) test

sidecars: ## Start all sidecar services
	./scripts/start_sidecars.sh

index: ## Index current directory into code index
	./scripts/index_repository.sh .

reset: ## Reset all memory stores (DESTRUCTIVE)
	./scripts/reset_memory.sh

microvm-rootfs: ## Build the Firecracker rootfs scaffold image
	./Infra/microvm/build-rootfs.sh

microvm-check: ## Check for required Firecracker assets
	@test -f ./Infra/microvm/vmlinux || (echo "missing ./Infra/microvm/vmlinux" && exit 1)
	@test -f ./Infra/microvm/rootfs.ext4 || (echo "missing ./Infra/microvm/rootfs.ext4" && exit 1)
	@echo "microvm assets present"

all: build sidecars ## Build and start everything
