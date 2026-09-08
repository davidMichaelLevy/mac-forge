.PHONY: check help

help:
	@echo "Targets:"
	@echo "  make check    Syntax-check scripts (shellcheck if installed)"

check:
	./scripts/check.sh
