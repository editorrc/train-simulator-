#!/usr/bin/env bash
# Visual/audio regression scripts (tests/visual/*_regression.gd) on a virtual display.
# Needs Godot 4.7.2 (GODOT=...), xvfb-run and, for window maximize/restore checks, openbox.
# Audio assets come from tools/prepare_demo_audio.sh (recordings and station voice).
#   GODOT=~/bin/Godot_v4.7.2-stable_linux.x86_64 tools/run_visual_qa.sh [audio desktop ...]
set -uo pipefail
repo_dir="$(cd -- "$(dirname -- "$0")/.." && pwd)"
godot="${GODOT:-godot}"
tests=("$@")
[ ${#tests[@]} -eq 0 ] && tests=(audio camera desktop navigation window)
# Inner mode, already on the virtual display: window manager + one regression script.
if [ "${1:-}" = "--inner" ]; then
  if command -v openbox >/dev/null; then
    openbox >/dev/null 2>&1 &
    wm=$!
    sleep 1
  fi
  "$godot" --rendering-driver opengl3 --path "$repo_dir/game" \
    -s "res://tests/visual/$2_regression.gd" 2>&1
  code=$?
  [ -n "${wm:-}" ] && kill "$wm" 2>/dev/null
  exit $code
fi
"$godot" --headless --path "$repo_dir/game" --import >/dev/null 2>&1
failed=0
for name in "${tests[@]}"; do
  log="$(GODOT="$godot" xvfb-run -a -s "-screen 0 1920x1080x24" "$0" --inner "$name")"
  verdict="$(grep -E '^[A-Z_]+_QA ' <<<"$log" | tail -1)"
  echo "${name}: ${verdict:-no verdict}"
  if ! grep -q " PASS" <<<"$verdict"; then
    failed=1
    grep -E '^ERROR: ' <<<"$log" | sort | uniq -c | head -10
  fi
done
exit $failed
