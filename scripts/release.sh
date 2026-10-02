#!/bin/zsh
set -euo pipefail
cd ~/github/web-watcher
VER=$1; BUILD=$2; PREV=$3; PREVB=$4; NOTE=$5
sed -i '' "s/CURRENT_PROJECT_VERSION = $PREVB;/CURRENT_PROJECT_VERSION = $BUILD;/g; s/MARKETING_VERSION = $PREV;/MARKETING_VERSION = $VER;/g" WebWatcher.xcodeproj/project.pbxproj
[ "$(grep -c "MARKETING_VERSION = $VER;" WebWatcher.xcodeproj/project.pbxproj)" = 2 ] || { echo "version bump failed"; exit 1; }
sed -i '' "s/WebWatcher v$PREV (Build $PREVB)/WebWatcher v$VER (Build $BUILD)/" Package.swift
python3 - "$VER" "$BUILD" "$NOTE" <<'PY'
import pathlib,sys,datetime
v,b,note=sys.argv[1:]; ch=pathlib.Path("CHANGELOG.md"); c=ch.read_text()
c=c.replace("## [Unreleased]\n",f"## [Unreleased]\n\n## [{v}] (Build {b}) - {datetime.date.today()}\n\n### Changed\n\n- {note}\n",1); ch.write_text(c)
PY
swift test 2>&1 | grep -E 'Executed [0-9]+ tests' | tail -1 | grep -q ' 0 failures' || { echo "tests failed"; exit 1; }
mac-notarize --dmg 2>&1 | tail -1
APP=/Users/ivg/Library/Developer/Xcode/DerivedData/WebWatcher-fwqxbkvzhxyjehclnajoftwgitvx/Build/Products/Release/WebWatcher.app
[ "$(defaults read "$APP/Contents/Info.plist" CFBundleShortVersionString)" = "$VER" ] || { echo "built wrong version"; exit 1; }
osascript -e 'tell application "WebWatcher" to quit' >/dev/null 2>&1 || true; sleep 2; pkill -x WebWatcher || true; sleep 1
rm -rf /Applications/WebWatcher.app && ditto "$APP" /Applications/WebWatcher.app && open /Applications/WebWatcher.app && sleep 3
pgrep -x WebWatcher >/dev/null && echo "running $(defaults read /Applications/WebWatcher.app/Contents/Info.plist CFBundleShortVersionString) b$(defaults read /Applications/WebWatcher.app/Contents/Info.plist CFBundleVersion)"
git add -A && git commit -q -m "Release $VER (Build $BUILD): $NOTE" && git checkout -q main && git merge -q --ff-only gmail && git tag -a "v$VER" -m "WebWatcher $VER (Build $BUILD)" && git push -q origin main gmail "v$VER" && git checkout -q gmail
gh release create "v$VER" "release/WebWatcher-$VER-build$BUILD-macOS.dmg" "release/WebWatcher-$VER-build$BUILD-macOS.dmg.sha256" --title "WebWatcher v$VER (Build $BUILD)" --notes "Signed, notarized and stapled. $NOTE See CHANGELOG.md." 2>&1 | tail -1
