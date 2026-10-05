#!/bin/zsh
# Re-takes every docs / landing-page screenshot at the CURRENT source and frames them.
#   1. Debug build into a derived-data dir (never touches /Applications/WebWatcher.app)
#   2. Runs the app's Debug screenshot mode (WW_SCREENSHOTS): sample data only, every window offscreen at
#      (-30000,-30000), never activated, captured by window id; raw captures land in $RAW
#   3. Frames each raw capture (gradient + soft shadow + margin) into web/public/shots (<name>.png + @2x)
# Env: WW_SHOTS_DD (derived data), WW_SHOTS_RAW (raw dir), WW_SHOTS_ONLY=name,name (subset), WW_SHOTS_SKIP_BUILD=1
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DD="${WW_SHOTS_DD:-${TMPDIR:-/tmp}/ww-shots-dd}"
RAW="${WW_SHOTS_RAW:-${TMPDIR:-/tmp}/ww-shots-raw}"
rm -rf "$RAW"; mkdir -p "$RAW"

if [[ "${WW_SHOTS_SKIP_BUILD:-0}" != 1 ]]; then
  xcodebuild -project "$ROOT/WebWatcher.xcodeproj" -scheme WebWatcher -configuration Debug \
    -derivedDataPath "$DD" build CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)" || true
fi
BIN="$DD/Build/Products/Debug/WebWatcher.app/Contents/MacOS/WebWatcher"
[[ -x "$BIN" ]] || { echo "no Debug binary at $BIN"; exit 1; }

WW_SCREENSHOTS="$RAW" "$BIN" 2>&1 | grep -E "^screenshots:" || true

cd "$ROOT/web"
node scripts/frame-shots.mjs "$RAW" --out public/shots
echo "--- capture log ($RAW/capture.log)"; cat "$RAW/capture.log"
