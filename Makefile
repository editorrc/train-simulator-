# Developer shortcuts. Set GODOT to your Godot 4.7.2 binary, e.g.
#   make test GODOT=~/bin/Godot_v4.7.2-stable_linux.x86_64
GODOT ?= godot


.PHONY: check test import lint format validate web web-check reference demo web-export serve

check: validate lint test web-check

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

# Rebuild the self-contained browser preview (web_preview/index.html).
web:
	python3 tools/build_web_preview.py

# JS port must match the GDScript trajectory; committed index.html must be fresh.
web-check:
	node web_preview/parity_check.js
	python3 tools/build_web_preview.py --check

# After an intentional physics change: re-record the GDScript reference trajectory.
reference: import
	$(GODOT) --headless --path game -s res://tests/parity/record_reference.gd

# Run the 2D demo.
demo:
	$(GODOT) --path game

# Export the game for the browser (needs Godot export templates 4.7.2 installed).
web-export: import
	mkdir -p build/web
	$(GODOT) --headless --path game --export-release "Web" ../build/web/index.html

# Serve the browser build locally: http://localhost:8000
serve:
	cd build/web && python3 -m http.server 8000
