# Hero demo recording — how it was made, and how to redo it

The hero video (`web/public/video/demo.mp4` / `demo.webm`, 1440×896, 60 fps, 41 s, poster `poster.jpg` + `poster@2x.jpg`)
is take 4 of a STAGED recording from WebWatcher 1.10.9's Debug build, not the old GitHub asset.

## What is real and what is staged

Real: the app (Debug build of the current source, Developer ID signed so the installed app's TCC grants apply),
its menu-bar popover, the Add Watcher window and the whole Page → Element → Confirm flow run by the real
`ElementPickerModel` against a REAL Safari tab (`SafariScraper`, Apple Events, scan, candidates, live reading,
save, baseline check, change check, the `NotificationService` title/body).

Staged (so nothing of the owner's desktop is in frame and nothing of his can land in it):
- a 1440×900-pt stage window with the site's hero gradient, a menu-bar strip (the real hourglass-with-eye glyph,
  wifi, battery, "Thu 8:14 PM"); the popover is anchored to that glyph instead of the real status item;
- a Safari-styled page window (drawn chrome + `WKWebView`) showing the same demo page the real Safari tab shows;
  the real tab sits off-stage at the bottom-left of the screen and is closed at the end;
- the notification is drawn by the app as a macOS-style banner from the exact title/body the service produced
  (demo mode never reaches Notification Center or Herald); the "click" beat is scripted (press, slide out,
  page raised, badge pulse);
- Herald's banners were held for 3 minutes via `PUT /v1/settings/quiet-hours {adHoc:{minutes:3,banners:true}}`
  (expires by itself; no `resume`, which would have ended the owner's own 22:30–06:30 window);
- the cursor is hidden and warped out of the region; the app records the region itself
  (`screencapture -V 46 -R 1040,28,1440,900`), so TCC attributes the capture to WebWatcher.app.

## Takes

| Take | Result |
|---|---|
| 1 (unstaged) | Safari's `front window` was the owner's other window; his desktop filled the region; editor never closed; badge timer suspended in the hidden tab → rejected |
| 2 | stage worked, but closing the editor deactivated the app and another app's window covered the stage → rejected |
| 3 | stage at `.floating` level: clean; cursor visible and the popover clipped at the right edge → rejected |
| 4 | **kept**: no failures in `demo.log`, banner at t=34.6, click at t=37.1; encoded 1.0 s → 42.2 s, top 4 pt cropped |

Raw takes live in `web/.demo/<take>/` (gitignored) with `demo.log`, `raw.mov`, `herald-quiet.json` and review frames.

## Redo it in one go

```bash
cd ~/github/web-watcher
xcodebuild -project WebWatcher.xcodeproj -scheme WebWatcher -configuration Debug -derivedDataPath build/demo-dd \
  CODE_SIGN_IDENTITY="Developer ID Application" CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=7S422NVLUK build
WW_DEMO_REGION=1040,28,1440,900 scripts/record-demo.sh take5     # Safari must be running; ~50 s; writes web/public/video/*
```

Env knobs (all optional): `WW_DEMO_REGION` (x,y,w,h in points on the main display), `WW_DEMO_SECONDS` (46),
`WW_DEMO_URL` (`http://localhost:8765/?badge=3`), `WW_DEMO_CLOSE_TAB=0` to keep the Safari tab,
`WW_DEMO_TRIM_START`/`WW_DEMO_TRIM_END` for the encode. The demo page is `web/demo-page/index.html`
(badge persists in `localStorage`, `window.bump()` raises it; served by `python3 -m http.server 8765`).

## Not done / caveats

- No voice-over (Kokoro VO was not rendered; the hero plays with the sound control but the file is silent).
- The old README embed (GitHub user-attachments URL) is replaced by a poster link to the committed mp4; GitHub
  does not inline-play repo files, so for an inline player the owner should drag `demo.mp4` into the README
  editor once (that mints a new user-attachments URL).
