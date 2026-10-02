# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.10.8] (Build 33) - 2026-10-02

### Changed

- Vendored Herald client re-synced with Herald 1.4.1: rich text (`lines`/markup), host-app resolution for Open, reply action kind

## [1.10.7] (Build 32) - 2026-10-02

### Changed

- Vendored Herald client re-synced with Herald 1.4.0: action arrangements (`actions.include/align/wrap/spacing`, `button.actionId`), button styles, the `openApp` action kind, agent apps, and the client routes for the parity API

## [1.10.6] (Build 31) - 2026-10-01

### Changed

- Vendored Herald client re-synced with Herald 1.3.0: SF Symbol styling on buttons, icons and badges (`HeraldSymbol`), the updated component schema, template, bundle, stack and quiet-hours models; WebWatcher's Herald manifests and banners can now carry symbols

## [1.10.5] (Build 30) - 2026-10-01

### Fixed

- The menu-bar icon is the hourglass-with-eye again (1.10.3/1.10.4 drew a plain hourglass while fixing its size and centring); it is scaled to the standard glyph height and centred, badge included
- A Herald template that adds `extra` values to a button's callback no longer makes WebWatcher reject its
  Gmail and Open buttons: the `extra` key is set aside before the payload is compared with what WebWatcher sent
- The Herald email banner now shows the title and body the email-watcher editor produces (custom text, the
  "[Preview]" marker, the recent-subjects list, the snippet) instead of only sender, subject and snippet; an
  install that still has the earlier untouched default template is given the new one

- Herald banner buttons now act before Herald is told they worked: the callback server answers with the
  outcome of the Gmail action (200 done, 409 failed, 504 still running), so Herald keeps the banner and
  shows a failure instead of dismissing a banner whose email was not archived, deleted or marked read
- After WebWatcher relaunches, buttons on banners that were already on screen still work: the callback
  payloads are re-learned from Herald's history, and the table holds 1024 notifications instead of 256
- Vendored Herald client files re-synced (request limits, loopback-only callbacks, URL placeholder fix)

## [1.10.4] (Build 29) - 2026-10-01

### Added

- Herald stacking group keys: email notifications carry the sender address (lowercased; an email watcher's accumulated banner uses its first sender pattern) and web watcher notifications carry the site host, so Herald stacks per sender or site. Both manifests declare `family: "webwatcher"`.

### Changed

- The vendored Herald client was re-synced (new HeraldStacks.swift and HeraldTemplateBundle.swift).

## [1.10.3] (Build 28) - 2026-10-01

### Fixed

- Menu bar icon: the badge variant of the hourglass symbol rendered the glyph small and low; the
  icon is now a plain hourglass drawn centred on a fixed 22 pt template canvas, matching the size
  and baseline of neighbouring menu bar items

## [1.10.2] (Build 27) - 2026-10-01

### Fixed

- Menu bar icon was small and off-centre: the status item now uses a variable-length slot and a
  larger, medium-weight glyph
- WebWatcher registered a redundant legacy "webwatcher" app with Herald next to its two issuers;
  only "WebWatcher · Web" and "WebWatcher · Email" are registered now, and leftover banners under
  the old id are dismissed once on launch

## [1.10.1] (Build 26) - 2026-10-01

### Added

- WebWatcher registers Herald manifests for web and email watchers (fields with samples, actions,
  icon) and ships default grid templates, so banners can be redesigned in Herald's Designer

### Changed

- Herald client re-synced (grid templates, voice and quiet-hours types)

## [1.10.0] (Build 25) - 2026-10-01

### Added

- Notifications can be delivered through Herald, the standalone banner service, when it is
  running (Settings → Notifications). Banners are persistent, always on top, carry the watcher's
  image, and keep the Mark as Read / Archive / Delete / Spam actions; macOS notifications remain the
  fallback when Herald is not running

## [1.9.1] (Build 24) - 2026-09-29

### Changed

- Notification icons are copied into WebWatcher's own folder when chosen, so moving or deleting
  the original image no longer breaks the notification
- Notification thumbnails are a centred square crop rendered at 512 px, so non-square images
  fill the thumbnail instead of being letterboxed inside it

## [1.9.0] (Build 23) - 2026-09-29

### Added

- Email watchers now keep a live unread count: each check asks Gmail for unread inbox mail from
  the watched senders, so reading a message in Gmail lowers the count without touching WebWatcher
- One accumulating notification per email watcher ("2 new from Acme Billing", latest subjects,
  time of the newest) that replaces the previous banner instead of stacking
- Custom icon, title and body templates for email watchers, with `{count}`, `{sender}`,
  `{address}`, `{subject}`, `{time}` and `{name}` placeholders, plus a preview button
- The menu shows the unread count next to each email watcher

### Changed

- Clicking an email notification opens the email itself when there is one unread message, or a
  Gmail search for the unread mail from those senders when there are several
- Mark as Read, Archive, Delete and Spam on an email notification act on all counted messages

## [1.8.1] (Build 22) - 2026-09-29

### Fixed

- Google sign-in ended with "Failed to fetch user profile": the app asked Google's generic
  userinfo endpoint for the account address, which the Gmail-only scope does not allow. It now
  reads the address from Gmail's own profile endpoint, and any remaining failure names its cause

## [1.8.0] (Build 21) - 2026-09-28

### Added

- Guided assistant for custom watchers: three steps — Page → Element → Confirm — that find the
  tab, open it if needed, scan automatically, and explain what they see
- Pick refinement: after picking an element in Safari, use ↑/↓/←/→ to select its parent, child,
  or siblings before confirming, with a toolbar in Safari or the app's own "Use this" button
- New watch type "Anything Changes Inside": fingerprints an element's subtree and notifies when
  it changes, for elements (like a bell icon) with no visible count to track
- Editor and Settings windows now appear in Cmd+Tab while open
- Built-in Google sign-in: "Add Gmail Account" / "Sign in with Google" now works without any
  console or JSON step, using WebWatcher's own embedded OAuth client; importing your own client
  remains available under Settings → Gmail → Advanced

### Fixed

- Scan page / Pick in Safari results were discarded by the response parser, so both appeared to
  do nothing

## [1.7.0] (Build 20) - 2026-09-26

### Added

- Gmail sender watchers: notify when new mail arrives from a specific address or `@domain`,
  with the arrival time shown in the menu bar
- Google OAuth client import: paste in your own Desktop OAuth client JSON from Settings →
  Gmail instead of relying on a bundled client
- Per-account "Notify for every new email" toggle for connected Gmail accounts
- Reconnect flow for Gmail accounts whose access has expired or been revoked

### Fixed

- Placeholder Google OAuth credentials that made "Add Gmail Account" silently fail
- An empty refresh token from Google being accepted instead of surfaced as an error
- A redundant read-only Gmail scope requested alongside the scope that already covers it

## [1.6.0] (Build 19) - 2026-09-26

### Added

- Scan page / Pick in Safari assistant in the watcher editor, so adding a watcher no longer
  requires DevTools
- Anchor + any-number (`autoBadge`) strategy for badges that are absent from the page at zero
- Advanced / Notification disclosure groups in the watcher editor, collapsed by default

### Fixed

- Probing an unloaded ("suspended") Safari tab no longer misreads it as missing and opens a
  duplicate tab
- Probes now prefer the visible tab over a hidden duplicate on the same URL
- At most one reload per check, instead of repeated reloads
- Built-in Rive profiles now refresh hidden tabs before reading their badge, since Safari
  pauses background tabs and stops repainting live counts

## [1.5.0] (Build 18) - 2026-07-28

### Added

- Gmail: connect one or more Gmail accounts (OAuth with PKCE over a local loopback redirect, tokens
  in the Keychain) and get a notification for each new message with Mark as Read, Archive, Delete
  and Spam actions
- Built-in site recipes for LinkedIn, Rive Community, Reddit and Contra, plus a generic
  "tab title (N)" recipe, selectable from the Site menu in the watcher editor
- Selector Doctor (step-by-step diagnosis) and anchor suggestions in the watcher editor
- Watchers can open their page in a background tab automatically when no tab is found
- A watcher that stays broken now sends one notification naming the cause and the remedy

### Changed

- A check that could not observe the page (no tab, signed out, bot check, selector miss) is no
  longer recorded as "0"; the last confirmed reading is kept and the menu shows the real status
- Failed checks back off exponentially; failures right after wake from sleep are not counted
- watchers.json is backed up before each save and an unreadable file is quarantined instead of
  being overwritten

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
