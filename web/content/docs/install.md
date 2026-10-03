Download the DMG, drag the app to Applications, and open it. WebWatcher lives in the menu bar, not the Dock, so look for the hourglass-with-an-eye icon after it launches.

![The menu bar popover with three watchers](/shots/popover.png)

## Requirements

- macOS 13.0 or later.
- Safari, with the page you want to watch open in a tab.
- Safari's *Allow JavaScript from Apple Events* setting turned on, plus Automation permission for Safari and System Events (see [Permissions](/docs/permissions)).
- Notification permission is optional but recommended.
- Optional: a Google account if you want [Gmail sender watchers](/docs/sign-in-with-google), and [Herald](/docs/herald-delivery) if you want banners that stay on screen.

## Install

1. Download the latest release from the [download section](/#download) or from GitHub Releases. The file is a signed and notarized DMG of about 3 MB.
2. Open the DMG and move `WebWatcher.app` to Applications.
3. Open the app. It appears in your menu bar.
4. Grant the three permissions when prompted. The next page walks through each one.
5. Open Safari, go to the page you want to monitor, and add a watcher.

> **Tip.** You can verify the download against the SHA-256 checksum published next to the DMG on the release page: run `shasum -a 256 WebWatcher-*.dmg` and compare.

## Updating

WebWatcher is a plain app bundle. To update, download the newer DMG and replace the app in Applications. Your watchers live in `~/Library/Application Support/WebWatcher/watchers.json` and are not touched by a replacement.
