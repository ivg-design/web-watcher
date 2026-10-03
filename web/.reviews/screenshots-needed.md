# Screenshots: captured vs still needed

Captured by the hidden Debug `--screenshots <dir>` / `WW_SCREENSHOTS` mode (sample data, `screencapture -l -o -x`
at 2x) and framed by `web/scripts/frame-shots.mjs` into `web/public/shots/` (`<name>.png` + `<name>@2x.png`):

| Shot | Window | Used on |
|---|---|---|
| popover | Menu-bar popover, three watchers (two web, one Gmail with count 3) | hero poster (`hero-poster`), docs/install |
| add-watcher-page | Add Watcher, step 1 Page | docs/first-watcher |
| add-watcher-element | Add Watcher, step 2 Element (Scan page candidates, Pick in Safari) | docs/first-watcher, docs/finding-the-element |
| add-watcher-confirm | Add Watcher, step 3 Confirm (live diagnosis) | docs/first-watcher |
| watcher-editor | Edit Watcher (text change, Advanced open) | docs/watch-types |
| gmail-sender-editor | Gmail sender watcher editor | docs/sender-and-domain-watchers, landing Gmail (optional figure) |
| settings-general | Settings, General | docs/settings |
| settings-gmail | Settings, Gmail (account with 3 unread) | docs/settings, docs/sign-in-with-google |
| settings-notifications | Settings, Notifications with Delivery = Herald | docs/settings, docs/herald-delivery |
| permissions | Settings, Permissions dashboard (all granted) | docs/permissions |

Not capturable from WebWatcher's own process (they are other apps' windows, or need a live page):

1. A real macOS Notification Center banner posted by WebWatcher (e.g. "Rive Community — 5 new") with its
   action buttons expanded. Needs a real change on a watched tab and a capture of Notification Center's
   window; the landing page draws it as a faithful DOM mock instead.
2. A real Herald banner for an email watcher (Herald's window). Mocked in DOM from Herald's test fixtures.
3. Safari with the in-page pick toolbar and the blue element outline on a real page (Safari's window, needs
   Allow JavaScript from Apple Events on a signed-in page). Reproduced in DOM from `ProbeProgram.swift`.
4. The menu bar itself with the hourglass-with-eye glyph and a neighbouring badge (the status item is drawn
   by SystemUIServer; `screencapture -l` cannot target it). The site uses its own Rive/SVG mark.

If the owner wants any of these as real captures, a manual run on his Mac with a real watcher is the only way;
`screencapture -i -W` on the notification/banner/Safari window, then `node scripts/frame-shots.mjs <dir>`.
