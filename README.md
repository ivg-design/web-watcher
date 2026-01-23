# WebWatcher

A lightweight macOS menu bar utility that monitors websites for changes and delivers native notifications.

![macOS](https://img.shields.io/badge/macOS-13.0%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.0-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## Features

- **Menu Bar App** - Lives quietly in your menu bar, no dock icon clutter
- **Multiple Watchers** - Monitor multiple websites simultaneously
- **Flexible Selectors** - Use CSS selectors or XPath expressions to target specific elements
- **Watch Types**:
  - Detect any changes to element content
  - Watch for specific text to appear
  - Watch for specific text to disappear
- **Native Notifications** - Rich macOS notifications with custom icons, titles, and body templates
- **Configurable Intervals** - Check every 1, 5, 15, 30 minutes or hourly
- **Custom Icons** - Set different notification icons for different watchers (e.g., Contra icon for Contra, Rive icon for Rive)
- **Launch at Login** - Optionally start automatically when you log in
- **Persistent Configuration** - Your watchers are saved and restored between sessions

## Installation

### From Source

1. Clone the repository:
   ```bash
   git clone https://github.com/aspect-build/web-watcher.git
   cd web-watcher
   ```

2. Open in Xcode:
   ```bash
   open WebWatcher.xcodeproj
   ```

3. Build and run (⌘R)

### Requirements

- macOS 13.0 or later
- Xcode 15.0 or later (for building from source)

## Usage

### Adding a Watcher

1. Click the WebWatcher icon in your menu bar
2. Click the "+" button to add a new watcher
3. Configure your watcher:
   - **Name**: A friendly name for this watcher
   - **URL**: The webpage to monitor
   - **Selector**: CSS selector or XPath to the element you want to watch
   - **Selector Type**: Choose between CSS or XPath
   - **Watch Type**: What kind of change to detect
   - **Check Interval**: How often to check for changes
   - **Custom Icon**: (Optional) Path to a custom notification icon
   - **Notification Title/Body**: Customize the notification appearance

4. Click "Save"

### Selector Examples

**CSS Selectors:**
```css
/* Element with specific class */
.message-badge

/* Element with ID */
#notification-count

/* Nested element */
.inbox .unread-count

/* Attribute selector */
[data-testid="message-indicator"]
```

**XPath Expressions:**
```xpath
/* Element by class */
//div[@class='message-badge']

/* Element containing text */
//span[contains(text(), 'unread')]

/* Nested path */
//div[@id='inbox']//span[@class='count']
```

### Notification Templates

Use placeholders in your notification body:
- `{value}` - The current value of the watched element
- `{name}` - The name of the watcher

Example: `You have {value} new messages in {name}`

## Configuration

### Settings

Access settings via the gear icon in the popover:

- **Launch at Login** - Start WebWatcher when you log into your Mac
- **Default Check Interval** - Default interval for new watchers
- **Page Load Delay** - Wait time after page loads before checking (useful for JavaScript-heavy sites)

### Data Storage

Watchers are stored in:
```
~/Library/Application Support/WebWatcher/watchers.json
```

Settings are stored in:
```
~/Library/Application Support/WebWatcher/settings.json
```

## Permissions

WebWatcher requires the following permissions:

- **Notifications** - To deliver native macOS notifications
  - Go to System Settings → Notifications → WebWatcher
  - Enable "Allow Notifications"
  - Set alert style to "Banners" or "Alerts"
  - Enable "Play sound for notifications"

## Architecture

```
Sources/WebWatcher/
├── WebWatcherApp.swift      # App entry point and menu bar setup
├── Models/
│   ├── Watcher.swift        # Watcher configuration model
│   ├── WatcherStore.swift   # Persistence layer
│   └── AppSettings.swift    # Global settings
├── Services/
│   ├── WebScraper.swift     # WKWebView-based web scraping
│   ├── WatcherService.swift # Background monitoring service
│   └── NotificationService.swift # Native notification handling
├── Views/
│   ├── MenuBarView.swift    # Main popover UI
│   ├── WatcherEditorView.swift # Add/edit watcher form
│   └── SettingsView.swift   # Settings screen
└── Assets.xcassets/         # App icons
```

## Troubleshooting

### Notifications not appearing

1. Check System Settings → Notifications → WebWatcher
2. Ensure "Allow Notifications" is enabled
3. Set alert style to "Banners" or "Alerts" (not "None")
4. Enable "Play sound for notifications" if you want audio

### Element not found

1. Verify the URL is correct and accessible
2. Check your selector in browser DevTools
3. Increase "Page Load Delay" in settings for JavaScript-heavy sites
4. Try using XPath if CSS selector isn't working

### App not starting at login

1. Go to Settings in the app
2. Toggle "Launch at Login" off and on again
3. Check System Settings → General → Login Items

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built with SwiftUI and AppKit
- Uses WKWebView for web scraping
- SF Symbols for UI icons
