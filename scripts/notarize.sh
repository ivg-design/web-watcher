#!/bin/bash
#
# Sign, notarize, staple and verify a macOS app — reusable across projects.
#
# Credentials are read from a notarytool keychain profile, so no password or key
# is ever passed on the command line or stored in a repo. Create the profile once
# per machine (not per app):
#
#   App Store Connect API key (preferred — survives Apple ID password changes):
#     xcrun notarytool store-credentials NOTARY_PROFILE \
#       --key ~/.appstoreconnect/private_keys/AuthKey_XXXXXXXX.p8 \
#       --key-id XXXXXXXX --issuer <issuer-uuid>
#
#   App-specific password:
#     xcrun notarytool store-credentials NOTARY_PROFILE \
#       --apple-id you@example.com --team-id TEAMID --password xxxx-xxxx-xxxx-xxxx
#
# Usage:
#   scripts/notarize.sh                                  # build + notarize this project
#   scripts/notarize.sh --app /path/to/Some.app          # notarize an existing bundle
#   scripts/notarize.sh --dmg                            # also produce a notarized DMG
#   NOTARY_PROFILE=other scripts/notarize.sh             # use a different stored profile
set -euo pipefail

PROFILE="${NOTARY_PROFILE:-notary}"
CONFIG="${CONFIG:-Release}"
APP_PATH=""
MAKE_DMG=0

# Work from the project that contains an .xcodeproj: the directory above this script
# when it is vendored at <project>/scripts/, otherwise the current directory. This is
# what lets the same file work in-repo and installed globally on PATH.
_script_parent="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd || echo "")"
if [[ -n "$_script_parent" ]] && compgen -G "$_script_parent/*.xcodeproj" >/dev/null; then
  PROJECT_DIR="${PROJECT_DIR:-$_script_parent}"
else
  PROJECT_DIR="${PROJECT_DIR:-$PWD}"
fi

# Scheme defaults to the name of the .xcodeproj found in the project directory.
if [[ -z "${SCHEME:-}" ]]; then
  _proj="$(compgen -G "$PROJECT_DIR/*.xcodeproj" | head -1 || true)"
  SCHEME="$(basename "${_proj:-$PROJECT_DIR}" .xcodeproj)"
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app) APP_PATH="$2"; shift 2 ;;
    --dmg) MAKE_DMG=1; shift ;;
    --profile) PROFILE="$2"; shift 2 ;;
    -h|--help) sed -n '2,30p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

step() { printf '\n\033[1m==> %s\033[0m\n' "$1"; }
fail() { printf '\033[31mERROR: %s\033[0m\n' "$1" >&2; exit 1; }

# --- Preflight -------------------------------------------------------------
step "Preflight"
security find-identity -v -p codesigning | grep -q "Developer ID Application" \
  || fail "No 'Developer ID Application' certificate in the keychain."

xcrun notarytool history --keychain-profile "$PROFILE" >/dev/null 2>&1 \
  || fail "No notarytool profile '$PROFILE'. Create it once with 'xcrun notarytool store-credentials $PROFILE ...' (see header)."

IDENTITY=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | sed 's/.*"\(.*\)"/\1/')
TEAM_ID=$(echo "$IDENTITY" | sed -n 's/.*(\([A-Z0-9]*\))$/\1/p')
echo "identity: $IDENTITY"
echo "team:     $TEAM_ID"
echo "profile:  $PROFILE"

# --- Build -----------------------------------------------------------------
if [[ -z "$APP_PATH" ]]; then
  compgen -G "$PROJECT_DIR/$SCHEME.xcodeproj" >/dev/null \
    || fail "No $SCHEME.xcodeproj in $PROJECT_DIR. Run this from a project directory, or pass --app /path/to/Your.app."
  step "Building $SCHEME ($CONFIG)"
  cd "$PROJECT_DIR"
  xcodebuild -project "$SCHEME.xcodeproj" -scheme "$SCHEME" -configuration "$CONFIG" build \
    | grep -E "error:|warning: .*deprecated|BUILD" || true
  APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/"$SCHEME"-*/Build/Products/"$CONFIG" \
    -maxdepth 1 -name "$SCHEME.app" -print -quit)
fi
[[ -d "$APP_PATH" ]] || fail "App bundle not found: $APP_PATH"
echo "app: $APP_PATH"

# --- Verify the signature is distributable ---------------------------------
step "Verifying signature"
codesign --verify --deep --strict --verbose=2 "$APP_PATH" 2>&1 | tail -2

# Capture once rather than piping into `grep -q`: under `set -o pipefail`, grep -q
# exits on first match, SIGPIPEs codesign, and the pipeline reports failure even
# though the match succeeded.
SIG_INFO=$(codesign -dvvv "$APP_PATH" 2>&1 || true)
ENTS=$(codesign -d --entitlements :- "$APP_PATH" 2>/dev/null || true)

grep -q "Authority=Developer ID Application" <<<"$SIG_INFO" \
  || fail "Not signed with Developer ID (still ad-hoc?). Check CODE_SIGN_IDENTITY / DEVELOPMENT_TEAM."

grep -q "flags=.*runtime" <<<"$SIG_INFO" \
  || fail "Hardened runtime is not enabled. Notarization requires ENABLE_HARDENED_RUNTIME=YES."

# This one silently fails notarization if left in; Xcode injects it unless
# CODE_SIGN_INJECT_BASE_ENTITLEMENTS is set to NO for the release configuration.
if grep -q "get-task-allow" <<<"$ENTS"; then
  fail "com.apple.security.get-task-allow is present — notarization will be rejected. Set CODE_SIGN_INJECT_BASE_ENTITLEMENTS = NO."
fi
echo "signature, hardened runtime and entitlements all OK"

# --- Notarize --------------------------------------------------------------
step "Submitting for notarization"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
ZIP="$WORK/$(basename "$APP_PATH" .app).zip"
ditto -c -k --keepParent "$APP_PATH" "$ZIP"

set +e
SUBMIT_OUT=$(xcrun notarytool submit "$ZIP" --keychain-profile "$PROFILE" --wait 2>&1)
SUBMIT_RC=$?
set -e
echo "$SUBMIT_OUT"

if [[ $SUBMIT_RC -ne 0 ]] || ! grep -q "status: Accepted" <<<"$SUBMIT_OUT"; then
  SUB_ID=$(grep -m1 -Eo '\bid: [0-9a-f-]{36}' <<<"$SUBMIT_OUT" | head -1 | awk '{print $2}')
  if [[ -n "$SUB_ID" ]]; then
    step "Notarization failed — fetching Apple's log"
    xcrun notarytool log "$SUB_ID" --keychain-profile "$PROFILE"
  fi
  fail "Notarization was not accepted."
fi

# --- Staple and confirm ----------------------------------------------------
step "Stapling"
xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"

step "Gatekeeper assessment"
spctl -a -vvv "$APP_PATH" 2>&1 | head -4

# --- Optional DMG ----------------------------------------------------------
if [[ $MAKE_DMG -eq 1 ]]; then
  step "Building DMG"
  VERSION=$(defaults read "$APP_PATH/Contents/Info" CFBundleShortVersionString 2>/dev/null || echo "1.0")
  BUILD=$(defaults read "$APP_PATH/Contents/Info" CFBundleVersion 2>/dev/null || echo "1")
  OUT_DIR="$PROJECT_DIR/release"
  mkdir -p "$OUT_DIR"
  DMG="$OUT_DIR/$(basename "$APP_PATH" .app)-$VERSION-build$BUILD-macOS.dmg"
  rm -f "$DMG"

  STAGE="$WORK/dmg"
  mkdir -p "$STAGE"
  ditto "$APP_PATH" "$STAGE/$(basename "$APP_PATH")"
  ln -s /Applications "$STAGE/Applications"
  hdiutil create -volname "$(basename "$APP_PATH" .app)" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null

  # The DMG is a separate artifact and must be signed and notarized in its own right.
  codesign --sign "$IDENTITY" --timestamp "$DMG"
  xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait
  xcrun stapler staple "$DMG"
  shasum -a 256 "$DMG" > "$DMG.sha256"
  step "DMG ready"
  echo "$DMG"
  cat "$DMG.sha256"
fi

step "Done"
echo "$APP_PATH is signed, notarized and stapled."
