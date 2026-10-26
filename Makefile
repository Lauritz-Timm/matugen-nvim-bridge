NVIM ?= nvim
PYTHON ?= python3

.PHONY: test test-matugen

test:
	$(NVIM) --headless --clean -u NONE -i NONE -n -l tests/run.lua

test-matugen:
	$(PYTHON) tests/matugen.py --nvim "$(NVIM)"
