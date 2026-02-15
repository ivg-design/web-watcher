# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.4.11] (Build 17) - 2026-02-13

### Added

- New "Open System Automation Settings" button in Settings, alongside the existing notifications shortcut
- New permission status dashboard in Settings with green/red indicators and action buttons for:
  - Notifications
  - Safari Automation
  - System Events Automation
  - Default browser automation

## [1.4.10] (Build 16) - 2026-02-13

### Fixed

- Added missing hardened-runtime automation entitlement (`com.apple.security.automation.apple-events`) so WebWatcher can be listed under System Settings -> Privacy & Security -> Automation and request browser control permissions correctly

## [1.4.9] (Build 15) - 2026-02-13

### Fixed

- Monitoring startup now waits for Safari automation permission instead of launching checks that immediately fail with repeated AppleEvents authorization errors
- Safari automation authorization failures now trigger a targeted permission flow and user-facing guidance instead of raw "Not authorized to send Apple events" watcher errors
- Automation alert retry instructions are now browser-specific (Safari monitoring vs Chromium tab-reuse action)

## [1.4.8] (Build 14) - 2026-02-13

### Fixed

- Chrome automation permission requests now retry with WebWatcher activated in the foreground, so macOS can show consent and register Chrome under Automation
- Added a direct AppleScript fallback permission probe for Chromium browsers when the AppleEvents preflight returns an unknown state
- Reduced false "enable automation" loops by treating unknown consent state as a fallback-to-open case instead of a hard deny

## [1.4.7] (Build 13) - 2026-02-13

### Fixed

- Browser automation permission requests now use the macOS AppleEvents permission API to more reliably trigger consent for the default browser (including Chrome)
- Added an in-app "Reset Automation Permission" action when a browser is missing from the Automation list, so Chrome consent can be requested again
- Updated AppleEvents usage description text to include both Safari monitoring and default-browser tab reuse behavior

## [1.4.6] (Build 12) - 2026-02-11

### Fixed

- Browser automation AppleScript now targets the default browser by explicit bundle identifier (`application id`) to improve permission targeting and tab reuse reliability

## [1.4.5] (Build 11) - 2026-02-11

### Fixed

- Fallback URL opens are now forced through the resolved default browser app, avoiding unexpected browser routing
- Added explicit default-browser automation probes and clearer permission-failure handling for tab reuse

## [1.4.4] (Build 10) - 2026-02-11

### Fixed

- Reuse logic now only checks the default browser for existing tabs, preventing unintended focus switches to other browsers (for example Safari) when Chrome is default

## [1.4.3] (Build 9) - 2026-02-11

### Fixed

- Added timeouts to browser reuse AppleScript calls to prevent blocked automation checks from stopping fallback URL opens
- Row click-to-open now uses an explicit button for more reliable click handling in the popover

## [1.4.2] (Build 8) - 2026-02-11

### Fixed

- Tab reuse now matches by both exact host and root domain (e.g., sibling subdomains)
- Reuse now checks the default browser first, then other supported running browsers for existing matching tabs before opening a new tab

## [1.4.1] (Build 7) - 2026-02-11

### Fixed

- Browser tab reuse matching now correctly invokes local AppleScript handlers, allowing existing-tab activation in Google Chrome and Safari by domain

## [1.4.0] (Build 6) - 2026-02-11

### Added

- API lookup command support on watchers to resolve message URLs dynamically before opening
- Clickable watcher rows in the popover (outside toggle/reload/edit controls) to open watcher destinations
- New setting: "Reuse existing browser tab by domain"
- Browser navigation service that attempts domain-tab reuse in Safari and Chromium-based browsers

### Changed

- Notification clicks now use the same destination resolution flow as popover row clicks
- Launch-at-login registration is refreshed from the installed app location when starting from `/Applications`

### Fixed

- Focus restoration now only happens when Safari is still frontmost after a scrape
- Safari scraping requests are serialized to reduce focus churn from overlapping checks
- Per-watcher in-flight guards prevent overlapping checks from stacking
- Notification replacement now keeps a single active visible notification per watcher
- Duplicate app instances are blocked at startup, preferring the `/Applications` instance

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
