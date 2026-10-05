# WebWatcher docs: restructure inventory

Read as rendered (`/docs/*`) and as source (`content/docs/*.md`) on 2026-10-04. A "blob" is a passage where
the reader has to parse a dense sentence to extract settings, options, steps, file formats, permissions, menu
paths or commands. Style guide: `docs-style.md`.

## Before

19 pages, 39 blobs.

| Page | Blobs | What is wrong |
|---|---|---|
| install | 2 | No statement of who needs the page. Requirements mix hard requirements, permissions and optional extras in one list. The checksum command sits inside a tip. Updating is one paragraph with a file path, no steps. No "what you see" after opening the app, no troubleshooting. |
| permissions | 2 | The trust-model sentence claims the app talks to nothing but Safari and Notification Center (it also talks to Herald and Google). Automation is described as "Safari and System Events"; the source never uses System Events, the third row is the default browser. Steps do not say what you see. The in-app Permissions group is shown but never explained. |
| first-watcher | 2 | "What happens next" is a blob (interval range, which types notify when). Three screenshots stacked after the list instead of at their steps. No troubleshooting. |
| finding-the-element | 5 | Headings numbered by hand ("1. Page") with paragraphs instead of steps. Scan groups, Pick in Safari and the keys are one paragraph each. Confirm is one sentence listing five things. The manual fallback is a whole menu path in one sentence. Keys are raw HTML. |
| scan-vs-pick | 2 | Two prose sections where a comparison table belongs; "when to choose" is buried at the end of each. Em dashes. |
| watch-types | 2 | The table has no "choose it when" column and no example. Anything Changes Inside mixes concept, warning and fix in two paragraphs. Reading strategies are named but never placed in the UI. |
| site-profiles | 3 | The built-in list packs strategy details into bullets with em dashes. Host matching is one dense sentence. "Recipes" is an orphan section. No how-to for picking a profile. |
| force-refresh | 3 | Four short sections that each restate the same cause. Settings (Force refresh, Settle delay) in prose with ranges inline. No steps. |
| example-watchers | 1 | Field lists as bullets, not tables. Does not say where the fields go. Uses internal name `anchoredBadge`. |
| sign-in-with-google | 3 | Sign in is one sentence of three actions. "Add a sender watcher" is one sentence of four actions. Step 4 of the advanced list holds three decisions. Scope explained in passing. |
| sender-and-domain-watchers | 3 | No how-to at all. Sender pattern format in a sentence. Notification actions (Mark as Read, Archive, Delete, Spam) and click behaviour in one paragraph. |
| notification-templates | 1 | Defaults described in a sentence with two templates inline. Example is prose. Does not say where the fields are. |
| gmail-limitations | 1 | Three unrelated limits in one list, one of them a dense sentence. Two orphan sections. |
| custom-notifications | 3 | Shows the Settings Delivery picker as the figure for per-watcher fields. Title/body defaults and three placeholders in one paragraph. "Smart filtering" repeats another page. "Where to change them" is an orphan with a menu path in a sentence. |
| herald-delivery | 2 | Opens with a feature list. Issuer ids and button behaviour in two paragraphs. "One switch, no Herald, no change." is a slogan. "Get Herald" is an orphan. |
| settings | 2 | Bullets with no defaults and no "when to change". Per-watcher options mixed into app settings. Permissions group, Poll interval, account switch, Enter manually and the Herald status line are missing. |
| data-and-privacy | 2 | Lists one file; the app writes five and a backups folder. "The three permissions" is an orphan sentence. |
| troubleshooting | 1 | Fixes as sentences with menu paths inline; no cause/fix structure; covers five messages only. |
| building-from-source | 1 | Requirements in one sentence. "Or open in Xcode" has no steps. License is an orphan. |

Structural problems across the set:

- No page says who it is for. Ledes are slogans ("Everything stays on your machine.").
- Menu paths written with arrows in running text; UI names in italics, bold or plain at random.
- Figures use the alt text as the caption, and several sit away from the sentence they illustrate.
- Fenced blocks have a language but no label; ordered lists look like any other list.
- Em dashes on six pages.

## Version-history framing found

None of the 19 pages has a "new in" section or a version number outside the requirements. Two phrasings
contrasted with the past and were rewritten as present behaviour: "Preferences on older macOS" (permissions)
and "the built-in recipe already accounts for" (example-watchers, site-profiles).

## After

20 pages (19 rewritten, 1 added: `watcher-options`, which takes the per-watcher fields out of Settings). No page
was removed or renamed, so no redirect is needed. Blobs left: 0 by the checks in `tests/docs.mjs` (history
patterns, fences without a language, tables wider than four columns, em dashes outside quoted app strings) and
by a read of every page. Titles changed in the sidebar only: "Permissions", "Scan or pick", "Site profiles",
"Force refresh and hidden tabs", "Sender and domain watchers", "Gmail limits", "Custom notifications",
"Data and privacy".

Pages still weaker than the rest:

- `scan-vs-pick` says little that `finding-the-element` does not; it survives as a short "which one" page.
- `site-profiles` has no figure: the fresh set has no capture of the Site picker.
- `troubleshooting` is long (about 30 problems). It is grouped by area, but it has no figure of a failing row.
- `settings` documents three controls that the app stores and never reads (see contradictions).

## Figures placed (page: images)

| Page | Images |
|---|---|
| CLAUDE | none |
| building-from-source | none |
| custom-notifications | watcher-editor-advanced |
| data-and-privacy | none |
| example-watchers | add-watcher-page |
| finding-the-element | add-watcher-page, add-watcher-element, add-watcher-confirm |
| first-watcher | add-watcher-page, add-watcher-element, add-watcher-confirm, popover |
| force-refresh | watcher-editor-advanced |
| gmail-limitations | none |
| herald-delivery | settings-notifications |
| install | popover-empty |
| notification-templates | gmail-sender-editor |
| permissions | permission-automation, permission-notifications, settings-permissions |
| scan-vs-pick | none |
| sender-and-domain-watchers | add-watcher-gmail, gmail-sender-editor, popover-changed |
| settings | popover, settings-general, settings-permissions, settings-defaults, settings-notifications, settings-gmail, settings-data-about |
| sign-in-with-google | settings-gmail-signin, settings-gmail, gmail-signin |
| site-profiles | none |
| troubleshooting | none |
| watch-types | watcher-editor, watcher-editor-badge, watcher-editor-anything-changes |
| watcher-options | add-watcher-page, watcher-editor, watcher-editor-advanced, gmail-sender-editor |

## Shot wish-list (nothing in `public/shots/manifest.json` shows these)

| Page and sentence | Window | State |
|---|---|---|
| site-profiles, "Use a profile" step 2 | Add Watcher | **Site** menu open: Custom, the eight profiles, "Any site — tab title (N)". |
| site-profiles, the "You see" line of step 2 | Add Watcher | A profile chosen: the explanation line, **URL to Monitor (must be open in Safari)**, "Using the built-in recipe for …" with **Set up manually instead**, and **Run Diagnosis**. |
| finding-the-element, "Pick in Safari" step 2 | Safari | The outline on an element and the toolbar with **Use this element** and **Cancel**; WebWatcher showing "Selected:". |
| finding-the-element, "How should WebWatcher watch it?" | Add Watcher | The choice card with "Recommended" and **Continue**. |
| watch-types, fix for a noisy watcher | Add Watcher, Confirm | The warning "This area has N elements — a busy container may notify more often than you want." |
| force-refresh step 4 | Edit Watcher, Advanced | **Force refresh before checking** on, with the **Settle delay** slider showing. |
| custom-notifications, "Preview a notification" | macOS | A delivered "[Preview]" notification, and the same in Herald. |
| herald-delivery, "The buttons on a banner" | Herald | A page-watcher banner with **Open**, and a Gmail banner with its four buttons. |
| sender-and-domain-watchers, "The notification" | macOS | A delivered email notification with **Mark as Read**, **Archive**, **Delete**, **Spam**. |
| notification-templates step 2 | Edit Email Watcher | **Notification** expanded: icon, title and body fields with the placeholders caption, **Preview Notification**. |
| sign-in-with-google, "Import the client into WebWatcher" | Settings, Gmail | **Advanced: use your own Google OAuth client** expanded; and the "Enter Google OAuth client" sheet. |
| sign-in-with-google, "Reconnect or remove an account" | Settings, Gmail | An account row with "Error:" and **Reconnect**. |
| troubleshooting, "Where the messages appear" | Popover | A row with a failing status such as "Signed out" or "No tab open". |
| permissions, Safari section | Safari Settings | **Advanced** with **Show features for web developers**, and **Developer** with **Allow JavaScript from Apple Events**. |
| permissions, Automation | macOS | The system Automation prompt, and System Settings > Privacy & Security > Automation with WebWatcher listed. |

Captures that do not match the app:

- `add-watcher-confirm.png` lists a check named "Reads a value". That label exists only in the screenshot demo data
  (`WebWatcherApp.swift`); the real Confirm card never shows it. The captions do not mention it. Re-capture
  with the real check labels ("Element found", "Fingerprint", …).
- `manifest.json` gives 530 × 762 for the settings crops, but the files are now per-group crops of other
  sizes, and `settings-defaults.png`, `settings-permissions.png` and `settings-data-about.png` are on disk but
  not listed. The renderer reads sizes from the PNG, so nothing breaks; the manifest needs regenerating.

## Contradictions between the docs and the source

| Old page said | Source says | Now |
|---|---|---|
| Settings: "Show badge in menu bar", "Default check interval" and "Page load delay" described as working. | `AppSettings` stores all three; no other file reads them (`grep` finds no use outside `AppSettings.swift` and `SettingsView.swift`). New watchers start at 30 seconds (`WatcherEditorView`), the wait after a reload is the watcher's `refreshDelay`. | settings.md says so in a note. This is an app bug to fix or three controls to remove. |
| Automation for "Safari and System Events". | "System Events" appears nowhere in `Sources/`. The rows are Safari and the default browser (`SettingsView`, `BrowserNavigationService`). | permissions, install, settings. |
| "The app talks to Safari and Notification Center, and to nothing else." / "Everything stays on your machine." | It also talks to Herald on localhost and to Google's token and Gmail hosts. | permissions, data-and-privacy. |
| A "Scan page" button. | No such button (`ElementPickerSection`): the scan runs when the tab is found; the button is **Rescan**. The app's own status text still says "use Scan page instead". | finding-the-element, scan-vs-pick, first-watcher. |
| Errors "Tab not found. Open [URL] in Safari.", "Not permitted to send Apple events to Safari", "Enable 'Allow JavaScript from Apple Events' in Safari Settings → Developer". | None of these strings exist. Real statuses are in `Observation.swift` ("No tab open", "Automation permission needed", "Enable JS from Apple Events", …). | troubleshooting rebuilt on the real messages. |
| The watcher URL must match Safari's address bar. | A tab matches by URL prefix, else by domain including subdomains; visible tabs first (`ProbeScript`). | troubleshooting, site-profiles. |
| "Badge watchers already reload the tab before reading it." | Only a blank tab is always reloaded; a hidden tab is reloaded when Force refresh or the profile's refresh is on; a visible tab never (`ProbeScript` `needReload`). | force-refresh, watcher-options. |
| Element Count "notifies when the count changes"; "text watchers notify on any change". | Element Count notifies only when the count rises; the first reading of most types is a baseline; Element Exists notifies on the first check that finds it (`WatcherService`). | watch-types, custom-notifications, first-watcher. |
| Five site profiles, vaguely named; Reddit example reads `initial-count`. | Eight profiles plus "Any site — tab title (N)" (`SiteProfile.swift`); the Reddit profile reads the badge text because `initial-count` is only the page-load value. Old example selectors and URLs differ from the profiles. | site-profiles, example-watchers. |
| Profiles "match on the tab's host, most specific first". | `profiles(matching:)` is never called by the UI; the profile's domain only chooses the tab. | site-profiles. |
| Confirm button captioned "Add Watcher". | The button is **Save**, disabled until name, URL and selector are set. | first-watcher. |
| Built-in Google client "for most people". | A built-in client exists only if `google-oauth-client.json` is in the bundle; without any client **Add Gmail Account** is disabled. `swift build` does not embed it; only the Xcode Run Script does. | sign-in-with-google, building-from-source. |
| "Notify you the moment it lands." | Mail is polled every 30 seconds to 10 minutes (default 1 minute). | gmail pages. |
| Default email body "latest subjects then received {time}". | Up to three bulleted subjects, the newest snippet (120 characters), "received {time}", and the account when several are connected (`NotificationService`). | notification-templates. |
| Domain watcher "baseline can miss a message". | Each poll searches the 25 newest matches within two years and re-filters locally; a domain matches exactly, not subdomains. | gmail-limitations. |
| Data: one file, `watchers.json`. | Also `backups/`, `email_watchers.json`, `gmail_accounts.json`, `site_profiles.json`, `icons/`, Keychain items. | data-and-privacy. |
| Licence "MIT". | `LICENSE` is "MIT License with Attribution Requirement". | building-from-source, data-and-privacy. |
| "Apple Silicon (arm64)" requirement. | Neither `Package.swift` nor the project sets an architecture. | Dropped. |

Not verifiable from the repo and kept with care: the Safari menu wording ("Show features for web developers"),
Google Cloud Console button names, that the released app ships a built-in Google client, Herald's own features.
