# Developer shortcuts. Set GODOT to your Godot 4.7.2 binary, e.g.
#   make test GODOT=~/bin/Godot_v4.7.2-stable_linux.x86_64
GODOT ?= godot

.PHONY: check test import lint format validate

check: validate lint test

import:
	$(GODOT) --headless --path game --import

test: import
	$(GODOT) --headless --path game -s res://tests/run_tests.gd

lint:
	gdformat --check game/
	gdlint game/

format:
	gdformat game/

validate:
	python3 tools/validate_data.py
	python3 -m unittest discover -s tools/tests
