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

## Contradictions between the docs and the source

See the end of this file; the list is completed as each page is rewritten.
