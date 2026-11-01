.PHONY: clean deps format format-check help lint major minor patch release smoke test verify

ROCKSPEC := $(lastword $(sort $(wildcard *.rockspec)))
LUA_VERSION := $(shell cat .lua-version)

# Project-local Lua toolchain, built by hererocks into $(LUA_TREE). Nothing here
# depends on the ambient shell, so every target works from a cold shell. Override
# HEREROCKS when it is not run through uvx; CI installs it and passes HEREROCKS=hererocks.
LUA_TREE := .hererocks
LUA_BIN := $(CURDIR)/$(LUA_TREE)/bin
HEREROCKS ?= uvx hererocks
LUAROCKS := $(LUA_BIN)/luarocks
LUACHECK := $(LUA_BIN)/luacheck
BUSTED := $(LUA_BIN)/busted

clean: ## Delete results and tmp files
	rm -rf factestio_results/* results/* tmp/*

$(LUAROCKS):
	$(HEREROCKS) $(LUA_TREE) --lua $(LUA_VERSION) --luarocks latest --no-readline

deps: $(LUAROCKS) ## Build the local Lua toolchain and install dev dependencies
	$(LUAROCKS) install --only-deps "$(ROCKSPEC)"
	$(LUAROCKS) test --prepare "$(ROCKSPEC)"
	@echo ""
	@echo "Note: stylua must be installed separately:"
	@echo "  brew install stylua"

format: ## Rewrite files with stylua
	stylua .

format-check: ## Check formatting without rewriting
	stylua --check .

lint: ## Run luacheck
	$(LUACHECK) .

test: ## Run unit tests
	$(BUSTED) -o gtest

verify: format-check lint test ## Run format-check, lint, and test

# Headless Factorio is Linux x86-64 only, hence the amd64 container (emulated on
# Apple silicon). --init lets Ctrl+C through; the script as PID 1 would ignore it.
smoke: ## Run the example scenarios on real headless Factorio, in a Docker container
	docker run --rm --init --platform linux/amd64 -v "$(CURDIR):/src:ro" \
		ubuntu:24.04 /src/scripts/smoke.sh --container

release: ## Cut a release: make release <major|minor|patch>
	scripts/release.sh --$(word 2,$(MAKECMDGOALS))

# Bump levels are positional arguments to `release`; on their own they do nothing.
major minor patch:
	@:

help: ## Show available targets
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F ':.*## ' '{printf "  %-13s %s\n", $$1, $$2}'
