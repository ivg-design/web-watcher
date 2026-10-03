# WebWatcher landing + docs — build brief (from the approved wireframe)

Wireframe: design/exports/webwatcher-landing-wireframe.png (1440 wide), docs: design/exports/webwatcher-docs-wireframe.png. Source of truth for copy and section order; the PNG is the design, this file is what the PNG cannot show.

## Identity
- Light page, blue-tinted neutrals (bg #F4F5FA, surface #FCFCFE, ink #14161C, muted #646A78, line #D8DBE6), electric blue accent #1F5EFF with soft #E3EBFF, dark sections #14161C / #20242E.
- Display: Bricolage Grotesque (800 for the hero, 600 for titles). Body: Albert Sans. Mono: JetBrains Mono (only in code/selector samples). Google Fonts via next/font.
- Hero headline two lines: "Stop refreshing." (ink) / "Start knowing." (accent), 92 px desktop. Full-bleed accent download section with white type and a black button.
- App icon: design/assets/webwatcher-icon.png (nav, notification mocks, download box, footer, docs header). Herald icon/logo: design/assets/herald-icon.png, herald-logo.png (Herald band).

## Section order (landing)
Nav (Docs link, GitHub, Download) · Hero (copy left; right: the demo video https://github.com/user-attachments/assets/8adbf24e-0b20-4d1a-8bc1-d2593f2a02f7 — muted autoplay loop, bleeds off the right edge, poster = the Safari+popover mock, play overlay "Watch the demo · 0:40" opens it with sound; "Watch the 40-second demo" link under the CTAs) · How it works (three bare columns with mocks: URL bar / picker toolbar with ↑↓←→ ⏎ ⎋ / notification) · Guided picker (dark, 140 px padding; candidate list mock + copy; headline 60 px) · Watch types (editorial table: icon | name | description | example chip in mono 20 px bold) + profiles row · Gmail (copy + editor mock + accumulated notification with count capsule + action buttons) · Herald band (dark; logo mark left; "Make it talk back." 44 px; copy; blue CTA with Herald icon "Get Herald — it's free"; banner mock right) · Privacy (four inline-icon rows + three-switch checklist) · Download (full-bleed blue; "Stop refreshing today." 88 px white; requirements; white box with icon, "WebWatcher 1.10.9 · Build 34", black button "Download for Mac · DMG · 3 MB", SHA link, releases link) · Changelog (three latest from CHANGELOG.md, mono version + date columns) · Footer (brand with icon, Product / Help / Resources / More from Forge columns).
Facts: macOS 13+, Apple Silicon only, DMG ≈ 3 MB, MIT, releases at https://github.com/ivg-design/web-watcher/releases (link the latest DMG asset dynamically from the GitHub API at build time or hardcode the latest tag and refresh per release).

## Docs site (/docs)
Three columns: section tree (Getting started: Install, Permissions (3 switches), Your first watcher · Watching pages: Finding the element, Scan page vs Pick in Safari, Watch types, Site profiles & recipes, Force refresh & hidden tabs, Example watchers · Gmail: Sign in with Google, Sender & domain watchers, Notification templates, Limitations · Notifications: Custom icon/title/body, Herald delivery · Reference: Settings, Data & privacy, Troubleshooting, Building from source), article, on-this-page. Content from README.md (sections map 1:1) — write each page as real prose from the README, not stubs. ⌘K search over page titles/headings. Prev/next links.

## Motion & delight (animate/delight skills)
- Hero signature: badge 0→3 rolls up in the poster mock, the Rive row lights with its count capsule, then the menu-bar glyph gains the eye — one 1.6 s sequence, then still; reduced-motion = final frame.
- Three steps: cards rise 16 px + fade, 100 ms stagger; step 2's toolbar keys press in sequence and the outline hops twice.
- Picker: hovering a candidate row highlights the matching element in a small page sketch; "best match" pulses once.
- Watch types: hovering a row animates its example (before slides out, after slides in).
- Gmail: count 1→2→3 as subjects stack in, then one is read and the count drops to 2 (3 s loop, once).
- Herald band: banner mock enters from top-right like a real banner; Snooze hover shows "returns at 9:00".
- Download: 2 px press; label "Starting download…" 1.2 s; copy-SHA flips to a check. Easter egg: hover the nav hourglass 3 s → the eye blinks.
- Global: transform/opacity only, ease-out-quart/quint/expo, exits 75 % of entrances, prefers-reduced-motion disables all but hover feedback. One staggered reveal on load, no scattered micro-interactions.
