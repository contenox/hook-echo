.PHONY: help build build-cached build-smart up up-debug up-info down logs test lint format check-types quality fix check-npm install-docs-deps docs-dir generate-openapi generate-docs-html generate-docs-markdown validate-openapi generate-docs check-clean bump-patch bump-minor bump-major release check-venv install clean

# ====================================================================================
# VARIABLES
# ====================================================================================
SERVICE_NAME = echo-tool
VENV_DIR = .venv
VENV_ACTIVATE = . $(VENV_DIR)/bin/activate

# Default log level, can be overridden
LOG_LEVEL ?= info

# Default image name, can be overridden for CI
IMAGE_NAME ?= tool-echo-local

# Default command to run when make is called without arguments
.DEFAULT_GOAL := help

# ====================================================================================
# DOCKER COMMANDS
# ====================================================================================
# Build using Docker Compose (default for local dev)
build:
	@echo "Building Docker image for the service..."
	docker compose build

# Build using Buildx with local caching (for CI or advanced local use)
build-cached:
	@echo "Building Docker image with Buildx and caching..."
	@mkdir -p /tmp/.buildx-cache 2>/dev/null || true
	docker buildx build \
		--file Dockerfile \
		--cache-from=type=local,src=/tmp/.buildx-cache \
		--cache-to=type=local,dest=/tmp/.buildx-cache-new,mode=max \
		--load \
		-t $(IMAGE_NAME) .
	@rm -rf /tmp/.buildx-cache && mv /tmp/.buildx-cache-new /tmp/.buildx-cache 2>/dev/null || true

# Conditional build — use build-cached if USE_BUILDX_CACHE=1, else default build
build-smart:
	@if [ "$(USE_BUILDX_CACHE)" = "1" ]; then \
		$(MAKE) build-cached; \
	else \
		$(MAKE) build; \
	fi

up: build-smart
	@echo "Starting services with (Log level: $(LOG_LEVEL))..."
	LOG_LEVEL=$(LOG_LEVEL) docker compose up -d

up-debug:
	@echo "Starting services in DEBUG mode..."
	$(MAKE) up LOG_LEVEL=debug

up-info:
	@echo "Starting services in INFO mode..."
	$(MAKE) up LOG_LEVEL=info

down:
	@echo "Stopping and removing services..."
	docker compose down --volumes

logs:
	@echo "Following service logs..."
	docker compose logs -f $(SERVICE_NAME)

# ====================================================================================
# TESTING & QUALITY
# ====================================================================================
wait-for-server: up
	@echo "Waiting for server to be ready at http://localhost:8000/health..."
	@until curl --output /dev/null --silent --head --fail http://localhost:8000/health; do \
		printf '.'; \
		sleep 1; \
	done
	@echo "\nServer is up!"

test: check-venv down wait-for-server
	@echo "Running API tests with authentication..."
	@$(VENV_ACTIVATE) && pytest --junitxml=test-results.xml tests/

lint: check-venv
	@echo "Running linter..."
	@$(VENV_ACTIVATE) && ruff check .

fix: check-venv
	@echo "Running linter with auto-fix..."
	@$(VENV_ACTIVATE) && ruff check . --fix

format: check-venv
	@echo "Formatting code..."
	@$(VENV_ACTIVATE) && ruff format .

check-types: check-venv
	@echo "Running static type checker..."
	@$(VENV_ACTIVATE) && mypy .

quality: check-venv lint check-types
	@echo "Code quality checks passed!"

# ====================================================================================
# DOCUMENTATION GENERATION
# ====================================================================================
check-npm:
	@command -v npm >/dev/null 2>&1 || { echo >&2 "npm is required but not installed. Aborting."; exit 1; }

install-docs-deps: check-npm
	@echo "Installing documentation dependencies..."
	@npm install --no-save @redocly/cli@latest widdershins@latest @stoplight/spectral-cli@latest

docs-dir:
	@mkdir -p docs

generate-openapi: docs-dir
	@echo "Generating openapi.json..."
	$(MAKE) up
	@echo "Waiting for server to be ready..."
	@until curl --output /dev/null --silent --head --fail http://localhost:8000/health; do \
		printf '.'; \
		sleep 1; \
	done
	@curl -s http://localhost:8000/openapi.json | jq . > docs/openapi.json
	$(MAKE) down
	@echo "\nOpenAPI schema saved to docs/openapi.json"

generate-docs-html: docs-dir install-docs-deps generate-openapi
	@echo "Generating HTML documentation with Redocly..."
	@npx @redocly/cli build-docs docs/openapi.json --output=docs/index.html
	@echo "HTML documentation saved to docs/index.html"

generate-docs-markdown: docs-dir install-docs-deps generate-openapi
	@echo "Generating Markdown documentation with Widdershins..."
	@npx widdershins docs/openapi.json -o docs/api.md
	@echo "Markdown documentation saved to docs/api.md"

validate-openapi: docs-dir install-docs-deps generate-openapi
	@echo "Validating OpenAPI schema with Spectral..."
	@npx @stoplight/spectral-cli lint docs/openapi.json --ruleset .spectral.yaml
	@echo "OpenAPI schema validation passed"

generate-docs: generate-docs-html generate-docs-markdown validate-openapi
	@echo "All documentation generated successfully"

# ====================================================================================
# VERSION INFO
# ====================================================================================
version: check-venv
	@$(VENV_ACTIVATE) && bump-my-version show-bump
	@$(VENV_ACTIVATE) && bump-my-version replace

# ====================================================================================
# RELEASE & VERSIONING
# ====================================================================================
check-clean:
	@if [ -n "$$(git status --porcelain)" ]; then \
		echo "❌ Working tree is dirty. Please commit or stash all changes before releasing."; \
		exit 1; \
	fi
	@echo "✅ Working tree is clean."

bump-patch: check-venv check-clean quality
	@echo "Bumping version (patch)..."
	$(VENV_ACTIVATE) && bump-my-version bump patch

bump-minor: check-venv check-clean quality
	@echo "Bumping version (minor)..."
	$(VENV_ACTIVATE) && bump-my-version bump minor

bump-major: check-venv check-clean quality
	@echo "Bumping version (major)..."
	$(VENV_ACTIVATE) && bump-my-version bump major

release:
	@echo "Pushing new release to origin..."
	git fetch origin
	git push --tags
	git push
	@echo "✅ Release pushed to origin."

# ====================================================================================
# DEVELOPMENT & CLEANUP
# ====================================================================================
check-venv:
	@if [ ! -d "$(VENV_DIR)" ]; then \
		echo "---"; \
		echo "🐍 Virtual environment not found. Running 'make install' for you..."; \
		echo "---"; \
		$(MAKE) install; \
	fi

install:
	@echo "Initializing Python virtual environment..."
	python3 -m venv $(VENV_DIR)
	@echo "Installing all dependencies (including development extras)..."
	$(VENV_ACTIVATE) && pip install -e .[dev]
	@echo "Environment ready. Activate with: source $(VENV_DIR)/bin/activate"

clean:
	@echo "Cleaning up Python cache and build artifacts..."
	rm -rf build/ dist/ *.egg-info/ .pytest_cache/ $(VENV_DIR)
	find . -type f -name '*.pyc' -delete
	find . -type d -name '__pycache__' -delete

# ====================================================================================
# HELP
# ====================================================================================
help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Top-level Commands:"
	@echo "  install       Set up the local virtual environment and install all dependencies."
	@echo "  quality       Run all code quality checks (linting, type checking)."
	@echo "  test          Run the end-to-end API tests against a live container (auth enabled)."
	@echo "  release       Create a new patch release and push it to origin."
	@echo "  clean         Remove all build artifacts, caches, and the virtual environment."
	@echo "  fix           Fix linting errors."
	@echo "  version       Show current version from source and latest git tag."
	@echo ""
	@echo "Docker Commands:"
	@echo "  build         Build the Docker image for the service."
	@echo "  up            Start services."
	@echo "  up-debug      Start services in DEBUG mode."
	@echo "  down          Stop and remove services and volumes."
	@echo "  logs          Follow the logs of the running service."
	@echo ""
	@echo "Documentation:"
	@echo "  generate-docs Generate all API documentation (HTML, Markdown) and validate the schema."
	@echo ""
	@echo "Versioning:"
	@echo "  bump-patch    Release a new patch version (creates commit and tag)."
	@echo "  bump-minor    Release a new minor version (creates commit and tag)."
	@echo "  bump-major    Release a new major version (creates commit and tag)."
