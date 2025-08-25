#!/usr/bin/env make -f

# REPOCLI Makefile
# Provides standard build targets for development and distribution

VERSION := 1.0.0
PREFIX ?= /usr/local
BINDIR := $(PREFIX)/bin
LIBDIR := $(PREFIX)/lib/repocli

.PHONY: all install uninstall test clean help

all: help

help: ## Show this help message
	@echo "REPOCLI v$(VERSION) - Makefile targets:"
	@echo ""
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-12s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

install: ## Install repocli to system (PREFIX=/usr/local by default)
	@echo "Installing REPOCLI to $(PREFIX)..."
	install -d $(BINDIR)
	install -d $(LIBDIR)/providers
	install -m 755 repocli $(BINDIR)/
	install -m 644 lib/*.sh $(LIBDIR)/
	install -m 644 lib/providers/*.sh $(LIBDIR)/providers/
	@echo "✅ Installation complete!"
	@echo "Run 'repocli init' to configure your provider"

install-user: ## Install repocli to user directory (~/.local)
	@$(MAKE) install PREFIX=$$HOME/.local

uninstall: ## Uninstall repocli from system
	@echo "Uninstalling REPOCLI from $(PREFIX)..."
	rm -f $(BINDIR)/repocli
	rm -rf $(LIBDIR)
	@echo "✅ Uninstallation complete!"

uninstall-user: ## Uninstall repocli from user directory
	@$(MAKE) uninstall PREFIX=$$HOME/.local

test: ## Run test suite
	./tests/run-tests.sh

test-github: ## Test GitHub provider specifically
	./tests/test-github.sh

test-gitlab: ## Test GitLab provider specifically
	./tests/test-gitlab.sh

lint: ## Check shell scripts for syntax errors
	@echo "Linting shell scripts..."
	@for file in repocli lib/*.sh lib/providers/*.sh tests/*.sh; do \
		if [ -f "$$file" ]; then \
			echo "Checking $$file..."; \
			bash -n "$$file" || exit 1; \
		fi; \
	done
	@echo "✅ All scripts passed syntax check"

clean: ## Clean temporary files
	find . -name "*.tmp" -delete
	find . -name "*~" -delete
	find . -name "test-*.conf" -delete
	rm -f repocli.conf

dist: clean ## Create distribution tarball
	@echo "Creating distribution tarball..."
	tar czf repocli-$(VERSION).tar.gz \
		--exclude='.git*' \
		--exclude='*.tar.gz' \
		--exclude='Formula' \
		--transform 's,^,repocli-$(VERSION)/,' \
		*
	@echo "✅ Created repocli-$(VERSION).tar.gz"

homebrew-test: ## Test Homebrew formula (requires brew)
	@if ! command -v brew >/dev/null 2>&1; then \
		echo "❌ Homebrew not found"; \
		exit 1; \
	fi
	brew install --build-from-source --formula ./Formula/repocli.rb

version: ## Show version information
	@echo "REPOCLI version $(VERSION)"

# Development targets
dev-setup: ## Setup development environment
	@echo "Setting up development environment..."
	@if [ ! -f repocli.conf ]; then \
		echo "Creating sample configuration..."; \
		cp repocli.conf-example repocli.conf; \
	fi
	@echo "✅ Development environment ready"
	@echo "Run './repocli --help' to test"

dev-test: ## Run repocli in development mode
	./repocli --help
	./repocli --version