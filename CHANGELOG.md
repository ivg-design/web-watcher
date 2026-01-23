# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.1] - 2026-01-22

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

## [1.0.0] - 2026-01-22

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
