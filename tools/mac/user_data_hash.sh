#!/usr/bin/env bash
# Fingerprint of the owner's ARTEM user data on macOS (paths, sizes, mtimes, content
# hashes). Run before and after visual QA: equal output means nothing was touched.
#   tools/mac/user_data_hash.sh [dir]   (default: Godot app_userdata/ARTEM)
set -euo pipefail
dir="${1:-$HOME/Library/Application Support/Godot/app_userdata/ARTEM}"
if [ ! -d "$dir" ]; then
  echo "absent $dir"
  exit 0
fi
cd "$dir"
find . -print0 | LC_ALL=C sort -z | while IFS= read -r -d '' path; do
  if [ -f "$path" ]; then
    printf '%s %s %s\n' "$path" "$(stat -f '%z %m' "$path")" "$(shasum -a 256 <"$path" | cut -c1-64)"
  else
    printf '%s %s\n' "$path" "$(stat -f '%m' "$path")"
  fi
done | shasum -a 256 | cut -c1-64
