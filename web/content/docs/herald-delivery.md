Herald is a standalone menu-bar notification service with persistent, always-on-top banners, per-app history, stacking by sender, snooze, and fully customizable banner layouts. WebWatcher can deliver its notifications through it.

## How it works

When Herald is running, WebWatcher registers two issuers: `webwatcher.web` for page watchers and `webwatcher.email` for Gmail watchers. It sends banners with the same title, body, icon and buttons it would otherwise hand to macOS.

Buttons such as Open, Mark as Read, Archive and Delete call back into WebWatcher and report their outcome, so a banner is only dismissed once the action succeeded. If a Gmail action fails, Herald keeps the banner and shows the failure.

## Turning it on

Go to Settings → Notifications → Delivery. Two choices:

- **Herald when available** (the default). Falls back to macOS notifications when Herald is not running.
- **macOS notifications.** Always use the system banners.

One switch, no Herald, no change.

![Settings, Notifications: the Delivery picker with Herald when available](/shots/settings-notifications.png)

## Stacking

Page-watcher banners group by site, and email banners group by sender address, so mail from one sender folds into a single stack in Herald.

## Get Herald

Herald is at [github.com/ivg-design/herald](https://github.com/ivg-design/herald).
