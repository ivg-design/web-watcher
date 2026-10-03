#!/bin/zsh
# Records the hero demo from the real app, STAGED: the Debug build's hidden WW_DEMO mode draws its own stage
# (gradient backdrop, menu-bar strip, a Safari-styled page window with the demo page, the real Add Watcher window,
# the real popover, and the notification banner) inside a fixed region of the main display, drives the real
# Page → Element → Confirm flow against a real (off-stage) Safari tab, and records the region itself with
# `screencapture -V`. This script does the preflight, serves the demo page, holds Herald's banners for the take,
# launches the run, encodes the result and restores Herald. Nothing of the owner's is quit or moved.
#
#   scripts/record-demo.sh [take-name]        # output: web/.demo/<take-name|timestamp>/
#
# Each run is a focus-taking take (the app activates itself and opens a Safari tab off-stage).
set -euo pipefail
ROOT="${0:A:h:h}"
TAKE="${1:-$(date +%Y%m%d-%H%M%S)}"
OUT="$ROOT/web/.demo/$TAKE"
APP="$ROOT/build/demo-dd/Build/Products/Debug/WebWatcher.app"
PAGE_DIR="$ROOT/web/demo-page"
PORT="${WW_DEMO_PORT:-8765}"
SECONDS_REC="${WW_DEMO_SECONDS:-46}"
REGION="${WW_DEMO_REGION:-1120,28,1440,900}"
HERALD_DIR="$HOME/Library/Application Support/Herald"
mkdir -p "$OUT"

say_() { print -P "%F{blue}▸%f $*"; }
fail() { print -P "%F{red}✗%f $*" >&2; exit 1; }

# --- preflight (nothing here takes focus) -------------------------------------------------------------
[[ -d "$APP" ]] || fail "Debug app missing: $APP (build: xcodebuild -configuration Debug -derivedDataPath build/demo-dd CODE_SIGN_IDENTITY=\"Developer ID Application\" CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=7S422NVLUK)"
codesign -dv "$APP" 2>&1 | grep -q "TeamIdentifier=7S422NVLUK" || fail "Debug app is not Developer ID signed (TCC grants would not apply)"
pgrep -x Safari >/dev/null || fail "Safari is not running (the demo must not launch it)"
command -v ffmpeg >/dev/null || fail "ffmpeg missing"
lsof -iTCP:$PORT -sTCP:LISTEN >/dev/null 2>&1 && fail "port $PORT busy"
say_ "region $REGION on the main display ($(system_profiler SPDisplaysDataType 2>/dev/null | awk '/Main Display: Yes/{f=1} f&&/UI Looks like/{print $4" x "$6; exit}') points)"

# --- Herald: hold banners for the take ------------------------------------------------------------------
HERALD_QUIET=0
if pgrep -x Herald >/dev/null && [[ -r "$HERALD_DIR/token" && -r "$HERALD_DIR/port" ]]; then
  HP=$(cat "$HERALD_DIR/port"); HT="Authorization: Bearer $(cat "$HERALD_DIR/token")"
  if curl -s -m 3 -X PUT -H "$HT" -H "Content-Type: application/json" \
       -d '{"adHoc":{"minutes":3,"speech":true,"sounds":true,"banners":true}}' "http://127.0.0.1:$HP/v1/settings/quiet-hours" >"$OUT/herald-quiet.json"; then
    HERALD_QUIET=1; say_ "Herald banners held for 3 minutes"
  else say_ "could not set Herald quiet hours (continuing)"; fi
fi
# The ad-hoc hold expires on its own; a "resume" would also end the owner's scheduled quiet window, so only report.
restore_herald() { (( HERALD_QUIET )) && curl -s -m 3 -H "$HT" "http://127.0.0.1:$HP/v1/settings/quiet-hours" >"$OUT/herald-after.json" && say_ "Herald quiet state after the take: $(cat "$OUT/herald-after.json" | head -c 160)" || true; }

# --- demo page server ----------------------------------------------------------------------------------
( cd "$PAGE_DIR" && python3 -m http.server "$PORT" --bind 127.0.0.1 >"$OUT/http.log" 2>&1 ) &
HTTP_PID=$!
sleep 0.6
curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:$PORT/" | grep -q 200 || { kill $HTTP_PID; restore_herald; fail "demo page not served"; }
say_ "demo page on http://localhost:$PORT/?badge=3"

# --- the take -------------------------------------------------------------------------------------------
say_ "take '$TAKE': launching the demo run (${SECONDS_REC}s)"
set +e
WW_DEMO="$OUT" WW_DEMO_URL="http://localhost:$PORT/?badge=3" WW_DEMO_SECONDS="$SECONDS_REC" WW_DEMO_REGION="$REGION" \
  "$APP/Contents/MacOS/WebWatcher" --demo "$OUT" >"$OUT/stdout.log" 2>&1
STATUS=$?
set -e
kill $HTTP_PID 2>/dev/null || true
restore_herald
say_ "app exited with $STATUS; log:"; cat "$OUT/demo.log" 2>/dev/null || cat "$OUT/stdout.log"

# --- encode (60 fps, trimmed) -----------------------------------------------------------------------------
RAW="$OUT/raw.mov"
[[ -s "$RAW" ]] || fail "no recording at $RAW"
VID="$ROOT/web/public/video"; mkdir -p "$VID"
START="${WW_DEMO_TRIM_START:-1.0}"
END="${WW_DEMO_TRIM_END:-42.5}"
DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$RAW")
say_ "raw: ${DUR}s; keeping ${START}s → ${END}s"
ffmpeg -y -v error -ss "$START" -to "$END" -i "$RAW" -vf "scale=1440:-2:flags=lanczos,fps=60" -c:v libx264 -preset slow -crf 20 -maxrate 6M -bufsize 12M -pix_fmt yuv420p -movflags +faststart -an "$VID/demo.mp4"
ffmpeg -y -v error -ss "$START" -to "$END" -i "$RAW" -vf "scale=1440:-2:flags=lanczos,fps=60" -c:v libvpx-vp9 -b:v 3M -deadline good -cpu-used 2 -row-mt 1 -an "$VID/demo.webm"
ffmpeg -y -v error -ss "$(( START + 0.3 ))" -i "$RAW" -frames:v 1 -vf "scale=1440:-2:flags=lanczos" -q:v 2 "$VID/poster.jpg"
ffmpeg -y -v error -ss "$(( START + 0.3 ))" -i "$RAW" -frames:v 1 -q:v 2 "$VID/poster@2x.jpg"
for t in 3 9 15 21 27 33 38; do ffmpeg -y -v error -ss $t -i "$RAW" -frames:v 1 -vf scale=720:-2 "$OUT/frame-$t.png"; done
ls -la "$VID"
ffprobe -v error -show_entries stream=width,height,duration,r_frame_rate,bit_rate -of default=nw=1 "$VID/demo.mp4"
say_ "done → $VID (review frames in $OUT/frame-*.png)"
