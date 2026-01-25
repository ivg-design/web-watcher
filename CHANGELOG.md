# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.0] (Build 5) - 2026-01-25

### Added

- **Custom Badge Attribute support** - Specify a custom HTML attribute to read badge values from
  - Essential for modern web components that use Shadow DOM (e.g., Reddit's `<dynamic-badge initial-count="5">`)
  - New "Badge Attribute" field appears when Badge/Number watch type is selected
  - Examples: `initial-count`, `data-count`, `aria-label`
- **Auto-detection of common badge attributes** - When no custom attribute is specified, automatically checks:
  - `initial-count` (Reddit)
  - `data-count` (common pattern)
  - `count`
  - Falls back to `innerText`/`textContent`

### Technical

- Added `badgeAttribute` property to Watcher model with backwards-compatible Codable support
- Updated SafariScraper to prioritize custom attribute over default detection chain

## [1.2.0] (Build 4) - 2026-01-24

### Changed

- Version display now shows build number (e.g., "v1.2.0 (4)")

## [1.2.0] (Build 3) - 2026-01-23

### Added

- **Force Refresh option** - Reloads Safari tab before scraping to fix stale content
  - Safari aggressively suspends background tabs, causing DOM reads to return outdated values
  - Enable "Force refresh before checking" in watcher settings to force a page reload
- **Configurable settle delay** - Slider to set wait time (0.5s - 5.0s) after page reload
  - Allows dynamic JavaScript content to fully update before scraping
  - Default: 2.0 seconds
- Background-safe refresh - Safari stays in background, focus is preserved
- Version number displayed in menu bar popover header
- Info button in popover header linking to GitHub README documentation

### Fixed

- Safari background tab suspension causing stale/outdated notification counts
- Dynamic content not updating without manual page reload
- Version display in Settings now reads from bundle (was hardcoded as 1.0.0)

### Technical

- Added `forceRefresh` and `refreshDelay` properties to Watcher model
- AppleScript waits for `document.readyState === "complete"` before scraping
- Backwards-compatible Codable implementation (existing watchers load with defaults)

## [1.1.0] (Build 2) - 2026-01-23

### Changed

- **Major architecture change**: Switched from WKWebView to Safari AppleScript integration
- WebWatcher now reads content directly from Safari tabs instead of isolated WebView
- No separate login required - uses your existing Safari sessions
- Removed WebScraper.swift and LoginWebView.swift (no longer needed)
- Standardized status messages to show "Nothing new" consistently

### Added

- SafariScraper.swift - AppleScript-based Safari tab scraping
- Focus preservation - Safari stays minimized when checking tabs
- Better handling of missing badge elements (returns "0" instead of error)

### Fixed

- SwiftUI not updating when watcher results change
- Badge monitoring now correctly shows "0" when no badge is visible

### Removed

- In-app login browser (LoginWebView) - no longer needed with Safari integration
- WKWebView-based WebScraper - replaced with SafariScraper

### Notes

- Requires Safari with "Allow JavaScript from Apple Events" enabled
- Monitored pages must be open in Safari tabs

## [1.0.1] (Build 1) - 2026-01-22

### Fixed

- Fixed Swift task continuation leak in WebScraper causing watchers to hang
- Refactored WebScraper to use actor-based architecture for better concurrency handling
- Fixed app sandbox restrictions that prevented file browsing and web requests
- Disabled app sandbox for proper WKWebView and file picker functionality
- Fixed notification delegate to properly show banners in foreground

### Changed

- Improved WebScraper reliability with dedicated worker class per request
- Better timeout handling using Swift structured concurrency
- Cleaner separation of concerns in web scraping code

## [1.0.0] (Build 1) - 2026-01-22

### Added

- Initial release of WebWatcher
- Menu bar application with popover interface
- Support for multiple website watchers
- CSS selector support for element targeting
- XPath expression support for element targeting
- Watch types:
  - Badge/Number tracking
  - Element count monitoring
  - Text change detection
  - Element existence detection
  - Element disappearance detection
- Configurable check intervals (15s, 30s, 1min, 2min, 5min, 10min, 30min)
- Native macOS notifications with:
  - Custom notification titles
  - Customizable body templates with `{value}` and `{name}` placeholders
  - Custom icon support per watcher
- Notification preview functionality
- Settings screen with:
  - Launch at login option
  - Default check interval configuration
  - Page load delay configuration
- Persistent storage of watchers and settings in ~/Library/Application Support/WebWatcher/
- Custom app icon
