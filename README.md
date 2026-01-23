# WebWatcher

A lightweight macOS menu bar utility that monitors websites for changes and delivers native notifications.

![macOS](https://img.shields.io/badge/macOS-13.0%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.0-orange)
![License](https://img.shields.io/badge/License-MIT%20with%20Attribution-green)

## Features

- **Menu Bar App** - Lives quietly in your menu bar, no dock icon clutter
- **Safari Integration** - Uses your existing Safari sessions (no separate login required!)
- **Multiple Watchers** - Monitor multiple websites simultaneously
- **Flexible Selectors** - Use CSS selectors or XPath expressions to target specific elements
- **Watch Types**:
  - Badge/Number tracking (e.g., notification counts)
  - Element count monitoring
  - Text change detection
  - Element existence/disappearance detection
- **Native Notifications** - Rich macOS notifications with custom icons, titles, and body templates
- **Configurable Intervals** - Check every 15s, 30s, 1, 2, 5, 10, or 30 minutes
- **Force Refresh** - Optional page reload before checking (fixes Safari's background tab suspension)
- **Custom Icons** - Set different notification icons for different watchers
- **Launch at Login** - Optionally start automatically when you log in
- **Persistent Configuration** - Your watchers are saved and restored between sessions

## Installation

### From Source

1. Clone the repository:
   ```bash
   git clone https://github.com/ivg-design/web-watcher.git
   cd web-watcher
   ```

2. Build with Xcode:
   ```bash
   xcodebuild -scheme WebWatcher -configuration Release build
   ```

3. Copy to Applications:
   ```bash
   cp -R ~/Library/Developer/Xcode/DerivedData/WebWatcher-*/Build/Products/Release/WebWatcher.app /Applications/
   ```

### Requirements

- macOS 13.0 or later
- Safari (for authenticated content)
- Xcode 15.0 or later (for building from source)

## Setup

### One-Time Safari Setup

WebWatcher reads content from Safari tabs using AppleScript. You need to enable this once:

1. Open Safari → Settings → Advanced
2. Check **"Show Develop menu in menu bar"**
3. In the menu bar: Develop → **"Allow JavaScript from Apple Events"**

### Permissions

On first run, WebWatcher will request:

1. **Automation permission** - To read content from Safari tabs
2. **Notification permission** - To deliver native macOS notifications
   - Go to System Settings → Notifications → WebWatcher
   - Enable "Allow Notifications"
   - Set alert style to "Banners" or "Alerts"

## Usage

### How It Works

WebWatcher reads content directly from your Safari tabs. This means:

- **You stay logged in** - Uses your existing Safari sessions
- **No separate login needed** - If you're logged into a site in Safari, WebWatcher can read it
- **Safari must have the tab open** - Keep the monitored page open in Safari (can be minimized)

### Adding a Watcher

1. **Open the site in Safari** and log in if needed
2. Click the WebWatcher icon in your menu bar
3. Click the "+" button to add a new watcher
4. Configure your watcher:
   - **Name**: A friendly name (e.g., "Contra Notifications")
   - **URL**: The base URL of the page open in Safari (e.g., `https://contra.com`)
   - **Selector**: CSS selector or XPath to the element you want to watch
   - **Watch Type**: Badge Number for notification counts
   - **Check Interval**: How often to check
5. Click **"Test Selector"** to verify it works
6. Click "Save"

### Finding Selectors

In Safari, right-click on the element you want to monitor → **Inspect Element**. Look for:

- `data-testid` attributes (most stable): `[data-testid="unread-notifications-count"]`
- Unique class names: `.notification-badge`
- Unique IDs: `#message-count`

**Tip:** `data-testid` attributes are kept stable by developers for testing purposes.

### Selector Examples

**CSS Selectors:**
```css
/* Data attribute (recommended) */
[data-testid="unread-notifications-count"]

/* Element with specific class */
.message-badge

/* Nested element */
.inbox .unread-count
```

**XPath Expressions:**
```xpath
//div[@data-testid='notification-count']
//span[contains(@class, 'badge')]
```

### Notification Templates

Use placeholders in your notification body:
- `{value}` - The current value (e.g., "3")
- `{name}` - The watcher name

Example: `You have {value} new messages in {name}`

## Configuration

### Data Storage

Watchers are stored in:
```
~/Library/Application Support/WebWatcher/watchers.json
```

Settings are stored in:
```
~/Library/Application Support/WebWatcher/settings.json
```

## Troubleshooting

### "Tab not found" error

- Ensure Safari has the page open (check the URL matches)
- The URL in WebWatcher should match the Safari tab (use base domain like `https://contra.com`)
- Don't use `www.` if Safari shows it without

### "Allow JavaScript from Apple Events" error

1. Open Safari → Settings → Advanced
2. Enable "Show Develop menu in menu bar"
3. Menu bar: Develop → "Allow JavaScript from Apple Events"
4. Restart Safari

### Notifications not appearing

1. Check System Settings → Notifications → WebWatcher
2. Ensure "Allow Notifications" is enabled
3. Set alert style to "Banners" or "Alerts" (not "None")

### Stale/outdated values (not updating)

Safari suspends background tabs to save resources. If you notice values not updating:

1. Edit the watcher and enable **"Force refresh before checking"**
2. Adjust the **settle delay** if needed (default 2.0s works for most sites)
3. This forces a page reload before each check, ensuring fresh content

**Note:** Force refresh adds latency to each check but guarantees up-to-date values.

### Element not found after sleep

Safari tabs may suspend after sleep. Click on the Safari window to wake it up, or enable "Force refresh" in watcher settings for automatic recovery.

## Architecture

```
Sources/WebWatcher/
├── WebWatcherApp.swift      # App entry point and menu bar setup
├── Models/
│   ├── Watcher.swift        # Watcher configuration model
│   ├── WatcherStore.swift   # Persistence layer
│   └── AppSettings.swift    # Global settings
├── Services/
│   ├── SafariScraper.swift  # AppleScript-based Safari scraping
│   ├── WatcherService.swift # Background monitoring service
│   └── NotificationService.swift # Native notification handling
└── Views/
    ├── MenuBarView.swift    # Main popover UI
    ├── WatcherEditorView.swift # Add/edit watcher form
    └── SettingsView.swift   # Settings screen
```

## Known Limitations

- **Requires Safari** - The monitored page must be open in a Safari tab
- **Sleep/Wake** - Safari tabs may need interaction after waking from sleep
- **No Firefox/Chrome** - Only Safari is supported (AppleScript limitation)

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the **MIT License with Attribution Requirement** - see the [LICENSE](LICENSE) file for details.

**Attribution required**: Any use or distribution must include visible attribution to the original author (IVGDesign) and project name (WebWatcher).

## Acknowledgments

- Built with SwiftUI and AppKit
- Uses AppleScript for Safari integration
- SF Symbols for UI icons
