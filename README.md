# WebWatcher

A macOS menu bar app that monitors websites for changes and sends native notifications.

https://github.com/user-attachments/assets/8adbf24e-0b20-4d1a-8bc1-d2593f2a02f7

## The problem

Notification badges get lost in browser tabs. Emails land in spam. Platform notifications assume you're checking constantly.

I missed a client message on Contra for two days because the badge was buried in 20 tabs. Built this to fix it.

## How it works

WebWatcher reads from Safari tabs you already have open. No separate login. No browser extension. It uses AppleScript to run JavaScript in your existing authenticated sessions, then pipes results to macOS Notification Center.

![Main popover](assets/popover.png)

## Features

- **Menu bar app** - Lives in your menu bar, not the dock
- **Uses Safari sessions** - No re-login required. Reads from tabs you're already logged into
- **CSS selectors or XPath** - Monitor any element: badges, message counts, text changes
- **Smart filtering** - Only notifies when values change. Badge went 2 → 3? Notification. Still 3? Silence
- **Custom icons** - Set a different icon for each watcher so you know which platform pinged you
- **Configurable intervals** - Check every 15 seconds to 30 minutes
- **Native notifications** - Shows up in Notification Center with sound

## Privacy

**Everything stays on your machine.** No servers, no analytics, no data collection. Configuration is stored locally at `~/Library/Application Support/WebWatcher/watchers.json`. The app only talks to Safari via AppleScript. Nothing leaves your computer.

## Screenshots

### Adding a watcher

![Add watcher](assets/add-watcher.png)

Configure URL, selector, watch type, and notification preferences.

### Settings

![Settings](assets/settings.png)

Launch at login and other preferences.

## Watch types

| Type | What it does |
|------|--------------|
| Badge/Number | Extract a numeric value (unread count, notification badge) |
| Element Count | Count how many elements match the selector |
| Text Change | Notify when text content changes |
| Element Exists | Notify when an element appears |
| Element Disappears | Notify when an element is removed |

## Setup

1. Download the latest release
2. Move `WebWatcher.app` to Applications
3. Open the app (it appears in your menu bar)
4. Grant permissions when prompted (see below)
5. Open Safari and navigate to the page you want to monitor
6. Add a watcher with the URL and CSS selector

## Permissions

WebWatcher needs three permissions to work. macOS will prompt for most of these on first run.

### 1. Safari: Allow JavaScript from Apple Events

This is the most important one. Without it, WebWatcher can't read page content.

1. Open **Safari**
2. Go to **Safari → Settings** (or Preferences on older macOS)
3. Click the **Advanced** tab
4. Check **Show features for web developers** (this enables the Develop menu)
5. Close Settings, then go to **Develop** menu in the menu bar
6. Check **Allow JavaScript from Apple Events**

If you skip this step, watchers will fail with: "Enable 'Allow JavaScript from Apple Events' in Safari Settings → Developer"

### 2. Automation (System Events & Safari)

macOS will show permission dialogs asking if WebWatcher can control Safari and System Events. Click **OK** on both.

If you accidentally clicked "Don't Allow":
1. Open **System Settings → Privacy & Security → Automation**
2. Find **WebWatcher** in the list
3. Enable both **Safari** and **System Events**

### 3. Notifications

macOS prompts for notification permission on first run. If you want to change settings later:

1. Open **System Settings → Notifications**
2. Find **WebWatcher**
3. Enable notifications and choose your preferred alert style (Banners or Alerts)

## Finding the right selector

1. Open Safari → Develop → Show Web Inspector (enable Develop menu in Safari preferences if needed)
2. Click the element inspector tool
3. Click the element you want to monitor (badge, counter, etc.)
4. Right-click the highlighted element → Copy → Copy Selector

## Example watchers

**Contra messages:**
- URL: `https://contra.com/messages`
- Selector: `[data-sentry-component='Messages'] [class*='badge']`
- Watch type: Badge/Number

**LinkedIn notifications:**
- URL: `https://www.linkedin.com/feed/`
- Selector: `.notification-badge__count`
- Watch type: Badge/Number

**Rive Community:**
- URL: `https://community.rive.app/`
- Selector: `.notification-indicator, [class*='notification'] [class*='count']`
- Watch type: Badge/Number

**GitHub PR reviews:**
- URL: `https://github.com/notifications`
- Selector: `.notification-indicator`
- Watch type: Element Exists

## Force refresh

Safari suspends background tabs to save resources. If your watcher shows stale values, enable "Force refresh before checking" in the watcher settings. This reloads the tab before scraping.

The "Settle delay" option (0.5s - 5.0s) controls how long to wait after reload for dynamic JavaScript content to update.

## Requirements

- macOS 13.0+
- Safari with "Allow JavaScript from Apple Events" enabled (see Permissions above)
- Target page open in a Safari tab
- Automation permissions for Safari and System Events
- Notification permissions (optional, but recommended)

## Troubleshooting

**"Enable 'Allow JavaScript from Apple Events' in Safari Settings → Developer"**

Safari's JavaScript access is disabled. See Permissions section above.

**"Tab not found. Open [URL] in Safari."**

The page isn't open in Safari, or the URL doesn't match. Make sure:
- The page is open in a Safari tab (not just bookmarked)
- The URL in your watcher matches what's in Safari's address bar
- You're not in Private Browsing mode

**"Not permitted to send Apple events to Safari"**

macOS blocked automation access. Go to System Settings → Privacy & Security → Automation → WebWatcher and enable Safari.

**Watcher shows stale/unchanging values**

Safari suspends background tabs. Enable "Force refresh before checking" in the watcher settings.

**No notifications appearing**

Check System Settings → Notifications → WebWatcher. Make sure notifications are enabled and set to Banners or Alerts (not "None").

## Building from source

```bash
cd WebWatcher
swift build
```

Or open `WebWatcher.xcodeproj` in Xcode and build.

## License

MIT
