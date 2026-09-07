.PHONY: clean deps format format-check lint test verify

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

clean:
	rm -rf factestio_results/* results/* tmp/*

$(LUAROCKS):
	$(HEREROCKS) $(LUA_TREE) --lua $(LUA_VERSION) --luarocks latest --no-readline

deps: $(LUAROCKS)
	$(LUAROCKS) install --only-deps "$(ROCKSPEC)"
	$(LUAROCKS) test --prepare "$(ROCKSPEC)"
	@echo ""
	@echo "Note: stylua must be installed separately:"
	@echo "  brew install stylua"

format:
	stylua .

format-check:
	stylua --check .

lint:
	$(LUACHECK) .

test:
	$(BUSTED) -o gtest

verify: format-check lint test
