# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-01-22

### Added

- Initial release of WebWatcher
- Menu bar application with popover interface
- Support for multiple website watchers
- CSS selector support for element targeting
- XPath expression support for element targeting
- Three watch types:
  - Any change detection
  - Text appearance detection
  - Text disappearance detection
- Configurable check intervals (1, 5, 15, 30 minutes, 1 hour)
- Native macOS notifications with:
  - Custom notification titles
  - Customizable body templates with `{value}` and `{name}` placeholders
  - Custom icon support per watcher
- Notification preview functionality
- Settings screen with:
  - Launch at login option
  - Default check interval configuration
  - Page load delay configuration
- Persistent storage of watchers and settings
- Permission handling for notifications
- Proper entitlements for:
  - Outgoing network connections
  - User notifications
