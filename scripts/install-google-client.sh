#!/bin/bash
# Installs a Google OAuth "Desktop app" client JSON as WebWatcher's built-in Google
# client, so "Add Gmail Account" / "Sign in with Google" works without an Advanced
# import step. The file is copied byte-for-byte (never printed) because Google's own
# guidance treats installed-app client secrets as non-confidential, but we still don't
# want it echoed into shell history or CI logs.
#
# Usage: scripts/install-google-client.sh <path to client_secret_*.json>

set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <path to client_secret_*.json>" >&2
  echo "  Download one from Google Cloud Console -> APIs & Services -> Credentials" >&2
  echo "  (OAuth client ID -> Application type: Desktop app -> Download JSON)." >&2
  exit 1
fi

SRC="$1"
if [ ! -f "$SRC" ]; then
  echo "error: file not found: $SRC" >&2
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST_DIR="$REPO_ROOT/Sources/WebWatcher/Resources"
DEST="$DEST_DIR/google-oauth-client.json"

mkdir -p "$DEST_DIR"
cp "$SRC" "$DEST"

echo "Installed built-in Google client at $DEST"
echo "This path is gitignored; rebuild (swift build, or Xcode) to pick it up."
