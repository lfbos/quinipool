.PHONY: help install build test test-gas snapshot fmt fmt-check lint clean coverage coverage-html coverage-open

# Default target: print available commands
help:
	@echo "MergeGain — available commands:"
	@echo ""
	@echo "  make install        Install/update Foundry dependencies (git submodules)"
	@echo "  make build          Compile contracts"
	@echo "  make test           Run all tests"
	@echo "  make test-gas       Run tests with gas report"
	@echo "  make snapshot       Generate gas snapshot (.gas-snapshot)"
	@echo "  make fmt            Format Solidity code"
	@echo "  make fmt-check      Check format without modifying files (useful in CI)"
	@echo "  make coverage       Coverage report in terminal"
	@echo "  make coverage-html  Generate HTML report in ./coverage/"
	@echo "  make coverage-open  Generate and open HTML report in browser"
	@echo "  make clean          Remove build and coverage artifacts"

install:
	forge install

build:
	forge build

test:
	forge test -vvvv

test-gas:
	forge test --gas-report

snapshot:
	forge snapshot

fmt:
	forge fmt

fmt-check:
	forge fmt --check

coverage:
	forge coverage --no-match-coverage "(test|script)"

coverage-html: lcov.info
	@command -v genhtml >/dev/null 2>&1 || { \
		echo "Error: 'genhtml' not found. Install it with: brew install lcov"; exit 1; \
	}
	genhtml lcov.info \
		--output-directory coverage \
		--branch-coverage \
		--ignore-errors inconsistent,corrupt \
		--quiet
	@echo "Report generated ./coverage/index.html"

lcov.info:
	forge coverage --report lcov --no-match-coverage "(test|script)"

coverage-open: coverage-html
	make clean && make coverage-html && open coverage/index.html

clean:
	forge clean
	rm -rf coverage lcov.info