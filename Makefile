.PHONY: clean deps format lint test ci

clean:
	rm -rf factestio/results/* results/* tmp/*

deps:
	luarocks test --prepare
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

ci: lint test
