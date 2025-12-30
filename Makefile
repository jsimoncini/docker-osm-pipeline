# Makefile for docker-osm-pipeline

.PHONY: help build-local test-image lint-dockerfile ci-run clean

# Variables
IMAGE_NAME ?= osm-pipeline
IMAGE_TAG ?= latest
REGISTRY ?= ghcr.io
REPO_OWNER ?= $(shell git config --get remote.origin.url | sed 's/.*github.com[:/]\(.*\)\/.*\.git/\1/')
REPO_NAME ?= docker-osm-pipeline

help: ## Show this help message
	@echo "Usage: make [target]"
	@echo ""
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'

build-local: ## Build Docker image locally
	@echo "Building Docker image: $(IMAGE_NAME):$(IMAGE_TAG)"
	docker build -t $(IMAGE_NAME):$(IMAGE_TAG) .
	@echo "✓ Image built successfully"

build-multiarch: ## Build multi-architecture image (amd64, arm64)
	@echo "Building multi-arch Docker image: $(IMAGE_NAME):$(IMAGE_TAG)"
	docker buildx build \
		--platform linux/amd64,linux/arm64 \
		-t $(IMAGE_NAME):$(IMAGE_TAG) \
		.
	@echo "✓ Multi-arch image built successfully"

test-image: build-local ## Test the built Docker image
	@echo "Testing Docker image..."
	@echo "Checking image size..."
	@docker images $(IMAGE_NAME):$(IMAGE_TAG) --format "Size: {{.Size}}"
	@echo ""
	@echo "Checking installed packages..."
	@docker run --rm $(IMAGE_NAME):$(IMAGE_TAG) "which curl && which psql && which osm2pgsql"
	@echo ""
	@echo "Checking user..."
	@docker run --rm $(IMAGE_NAME):$(IMAGE_TAG) "id"
	@echo ""
	@echo "✓ Image tests passed"

lint-dockerfile: ## Lint Dockerfile with hadolint
	@echo "Linting Dockerfile..."
	@if command -v hadolint >/dev/null 2>&1; then \
		hadolint Dockerfile; \
		echo "✓ Dockerfile lint passed"; \
	else \
		echo "hadolint not found, using Docker..."; \
		docker run --rm -i hadolint/hadolint < Dockerfile; \
	fi

lint-shell: ## Lint shell scripts
	@echo "Linting shell scripts..."
	@for script in scripts/*.sh; do \
		echo "Checking $$script..."; \
		sh -n "$$script" && echo "  ✓ Syntax OK" || exit 1; \
	done
	@echo "✓ All shell scripts passed"

lint-yaml: ## Lint YAML files
	@echo "Linting YAML files..."
	@if command -v yamllint >/dev/null 2>&1; then \
		yamllint -d relaxed *.yml; \
		echo "✓ YAML lint passed"; \
	else \
		echo "⚠ yamllint not installed, skipping"; \
	fi

lint: lint-dockerfile lint-shell lint-yaml ## Run all linters

ci-run: lint build-local test-image ## Run full CI pipeline locally
	@echo ""
	@echo "✓ CI pipeline completed successfully"

push: ## Push image to registry
	@echo "Pushing $(IMAGE_NAME):$(IMAGE_TAG) to $(REGISTRY)/$(REPO_OWNER)/$(REPO_NAME)"
	docker tag $(IMAGE_NAME):$(IMAGE_TAG) $(REGISTRY)/$(REPO_OWNER)/$(REPO_NAME):$(IMAGE_TAG)
	docker push $(REGISTRY)/$(REPO_OWNER)/$(REPO_NAME):$(IMAGE_TAG)
	@echo "✓ Image pushed successfully"

clean: ## Clean up Docker images and build cache
	@echo "Cleaning up..."
	docker rmi $(IMAGE_NAME):$(IMAGE_TAG) 2>/dev/null || true
	docker builder prune -f
	@echo "✓ Cleanup completed"

scripts-executable: ## Make scripts executable
	chmod +x scripts/*.sh
	@echo "✓ Scripts are now executable"

dev-setup: scripts-executable ## Setup development environment
	@echo "Setting up development environment..."
	@if [ ! -f .env ]; then cp .env.example .env && echo "✓ Created .env from .env.example"; fi
	@echo "✓ Development environment ready"
	@echo ""
	@echo "Next steps:"
	@echo "  1. Edit .env with your configuration"
	@echo "  2. Run 'make build-local' to build the image"
	@echo "  3. Run 'make test-image' to test it"
