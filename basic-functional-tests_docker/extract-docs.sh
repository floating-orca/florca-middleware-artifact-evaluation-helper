#!/bin/bash
#
# Extracts the rendered FloatingOrca user/developer guide (built from the
# archived v0.8.1 source as part of ./build.sh, via mdBook - see
# Dockerfile's "book" stage) to ./book-output, and opens it in a browser
# (on WSL2, via `wslview`).
#
# Usage: ./build.sh && ./extract-docs.sh

set -Eeuo pipefail

DIR="$(dirname "$(realpath "$0")")"
OUT_DIR="$DIR/book-output"

if ! docker image inspect florca-ae >/dev/null 2>&1; then
  echo "The florca-ae image is not built yet. Run ./build.sh first." >&2
  exit 1
fi

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

id="$(docker create florca-ae)"
docker cp "$id:/usr/src/florca/book-docs/." "$OUT_DIR"
docker rm "$id" >/dev/null

echo "Documentation extracted to $OUT_DIR"

opener=""
# xdg-open: Linux desktop. open: macOS. wslview: WSL2 -> Windows browser.
# explorer.exe/cmd.exe: Git-Bash-on-native-Windows fallback (rare path;
# WSL2 above is the supported/recommended one).
for candidate in xdg-open open wslview explorer.exe; do
  command -v "$candidate" >/dev/null && opener="$candidate" && break
done

if [ -n "$opener" ]; then
  echo "Opening $OUT_DIR/index.html with $opener ..."
  "$opener" "$OUT_DIR/index.html" >/dev/null 2>&1 &
elif command -v cmd.exe >/dev/null; then
  echo "Opening $OUT_DIR/index.html with cmd.exe /c start ..."
  cmd.exe /c start "" "$(cygpath -w "$OUT_DIR/index.html" 2>/dev/null || echo "$OUT_DIR/index.html")" >/dev/null 2>&1 &
else
  echo "No browser opener found - open $OUT_DIR/index.html manually."
fi
