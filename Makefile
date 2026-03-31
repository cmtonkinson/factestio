.PHONY: clean deps format lint test ci

ROCKSPEC := $(lastword $(sort $(wildcard *.rockspec)))

clean:
	rm -rf factestio/results/* results/* tmp/*

deps:
	luarocks install --only-deps "$(ROCKSPEC)"
	luarocks test --prepare "$(ROCKSPEC)"
	@echo ""
	@echo "Note: stylua and luacheck must be installed separately:"
	@echo "  brew install stylua"
	@echo "  luarocks install luacheck"

format:
	stylua .

lint:
	luacheck .

test:
	busted -o gtest

verify: format lint test
