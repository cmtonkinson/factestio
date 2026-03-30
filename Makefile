.PHONY: clean deps format lint test ci

clean:
	rm -rf results/* tmp/*

deps:
	luarocks test --prepare

format:
	stylua .

lint:
	luacheck .

test:
	busted -o gtest

ci: lint test
