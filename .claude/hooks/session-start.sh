#!/bin/bash
# Cloud sessions: Godot 4.7.2 (official, SHA512-checked), lint/data tools, fonts, generated
# recordings and a virtual display with a window manager, so `make check` and
# `make visual-qa` work right away. Idempotent; the container is cached afterwards.
# Export templates and the TTS station voice are heavy and installed on demand:
#   python3 tools/install_godot.py --templates;  bash tools/prepare_demo_audio.sh
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi
cd "$CLAUDE_PROJECT_DIR"

pip install -q -r tools/requirements.txt

missing=()
for tool in xvfb-run openbox xorriso; do
  command -v "$tool" >/dev/null || missing+=("$tool")
done
if [ ${#missing[@]} -gt 0 ]; then
  packages=("${missing[@]/xvfb-run/xvfb}")
  apt-get install -y -q "${packages[@]}" >/dev/null 2>&1 \
    || (apt-get update -q >/dev/null 2>&1 && apt-get install -y -q "${packages[@]}" >/dev/null 2>&1) \
    || echo "session-start: could not install ${packages[*]}" >&2
fi

godot="$(python3 tools/install_godot.py | tail -1)"
echo "export GODOT=\"$godot\"" >> "$CLAUDE_ENV_FILE"

python3 tools/prepare_fonts.py >/dev/null
if [ ! -s game/audio/recordings/horn_sustain.wav ]; then
  ARTEM_SKIP_TTS=1 bash tools/prepare_demo_audio.sh >/dev/null
fi
"$godot" --headless --path game --import >/dev/null 2>&1 || true
