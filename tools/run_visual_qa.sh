#!/usr/bin/env bash
# Visual/audio regression scripts (tests/visual/*_regression.gd) on a virtual display.
# Needs Godot 4.7.2 (GODOT=...), an existing DISPLAY + window manager, or xvfb-run
# and openbox (for window maximize/restore checks). AUDIO_DRIVER=Dummy works in clouds.
# On macOS it opens real windows on the current display (no Xvfb needed).
# Audio assets come from tools/prepare_demo_audio.sh (recordings and station voice).
#   GODOT=~/bin/Godot_v4.7.2-stable_linux.x86_64 tools/run_visual_qa.sh [audio desktop ...]
set -uo pipefail
repo_dir="$(cd -- "$(dirname -- "$0")/.." && pwd)"
godot="${GODOT:-godot}"
tests=("$@")
[ ${#tests[@]} -eq 0 ] && tests=(audio camera desktop navigation window lifecycle)
# Inner mode, already on the virtual display: window manager + one regression script.
if [ "${1:-}" = "--inner" ]; then
  if command -v openbox >/dev/null; then
    openbox >/dev/null 2>&1 &
    wm=$!
    sleep 1
  fi
  audio_args=()
  [ -n "${AUDIO_DRIVER:-}" ] && audio_args=(--audio-driver "$AUDIO_DRIVER")
  "$godot" --rendering-driver opengl3 --path "$repo_dir/game" \
    "${audio_args[@]}" -s "res://tests/visual/$2_regression.gd" 2>&1
  code=$?
  [ -n "${wm:-}" ] && kill "$wm" 2>/dev/null
  exit $code
fi
qa_data_dir="$(mktemp -d "${TMPDIR:-/tmp}/artem-visual-qa.XXXXXX")"
trap 'rm -rf -- "$qa_data_dir"' EXIT
# macOS ignores XDG_DATA_HOME, and the editor-mode import ignores a custom user dir;
# Godot takes ~/Library/Application Support from HOME, so a temporary HOME keeps the
# owner's ARTEM settings and editor settings untouched.
darwin=0
[ "$(uname -s)" = Darwin ] && darwin=1
# Godot makes app_userdata/<name> itself, but not these parents (no shader cache without them).
mac_home() { mkdir -p "$qa_data_dir/$1/Library/Application Support" "$qa_data_dir/$1/Library/Caches"; }
import_env=()
[ "$darwin" = 1 ] && mac_home import && import_env=(HOME="$qa_data_dir/import")
if ! env "${import_env[@]}" "$godot" --headless --path "$repo_dir/game" --import >/dev/null 2>&1; then
  echo "Godot import failed" >&2
  exit 1
fi
failed=0
for name in "${tests[@]}"; do
  # Preferences/layouts from another test or a real trip must not change the fixture.
  mkdir -p "$qa_data_dir/$name"
  if [ "$darwin" = 1 ]; then
    # Real window on the owner's display, with the project's own macOS driver as in the game.
    mac_home "$name"
    audio_args=()
    [ -n "${AUDIO_DRIVER:-}" ] && audio_args=(--audio-driver "$AUDIO_DRIVER")
    log="$(HOME="$qa_data_dir/$name" "$godot" --path "$repo_dir/game" \
      "${audio_args[@]}" -s "res://tests/visual/${name}_regression.gd" 2>&1)"
  elif [ -n "${DISPLAY:-}" ]; then
    audio_args=()
    [ -n "${AUDIO_DRIVER:-}" ] && audio_args=(--audio-driver "$AUDIO_DRIVER")
    log="$(XDG_DATA_HOME="$qa_data_dir/$name" "$godot" --rendering-driver opengl3 --path "$repo_dir/game" \
      "${audio_args[@]}" -s "res://tests/visual/${name}_regression.gd" 2>&1)"
  else
    log="$(XDG_DATA_HOME="$qa_data_dir/$name" GODOT="$godot" xvfb-run -a -s "-screen 0 1920x1080x24" "$0" --inner "$name")"
  fi
  code=$?
  verdict="$(grep -E '^[A-Z_]+_QA ' <<<"$log" | tail -1)"
  echo "${name}: ${verdict:-no verdict}"
  diagnostics='^SCRIPT ERROR:|^ERROR:|ObjectDB.*leaked|resources still in use|RID allocations.*leaked'
  if [ "$code" -ne 0 ] || ! grep -q '^[A-Z_]*_QA PASS\([[:space:]]\|$\)' <<<"$verdict" \
      || grep -Eq "$diagnostics" <<<"$log"; then
    failed=1
    echo "${name}: failed (exit=$code)"
    grep -E "$diagnostics" <<<"$log" | sort | uniq -c | head -10
  fi
done
exit $failed
