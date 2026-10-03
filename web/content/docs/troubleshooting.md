Find the message you see, then follow the fix.

## "Enable 'Allow JavaScript from Apple Events' in Safari Settings → Developer"

Safari's JavaScript access is disabled. See [Permissions](/docs/permissions).

## "Tab not found. Open [URL] in Safari."

The page is not open in Safari, or the URL does not match. Make sure that:

- The page is open in a Safari tab, not just bookmarked.
- The URL in your watcher matches what is in Safari's address bar.
- You are not in Private Browsing mode.

## "Not permitted to send Apple events to Safari"

macOS blocked automation access. Go to System Settings → Privacy & Security → Automation → WebWatcher and enable Safari.

## The watcher shows stale or unchanging values

Safari suspends background tabs. Enable *Force refresh before checking* in the watcher settings. See [Force refresh](/docs/force-refresh).

## No notifications appear

Check System Settings → Notifications → WebWatcher. Make sure notifications are enabled and set to Banners or Alerts, not None.

## Known limitations

- **Private windows** cannot be told apart from normal ones. WebWatcher probes the first matching Safari tab regardless of whether it is in a private window.
- **Cross-origin iframes.** An element embedded in a frame from a different origin cannot be reached by Scan page or Pick in Safari. Pick in Safari tells you when this happens.
- **Closed shadow roots.** Elements inside a closed Shadow DOM are not visible to the assistant, for the same cross-boundary reason.
- **Background tabs go stale.** A badge that updates over a WebSocket may not repaint until the tab is visible again.
