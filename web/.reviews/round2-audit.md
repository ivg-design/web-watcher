# Round 2 audit — WebWatcher site (independent review of the lead's build)

Build reviewed: `gmail` @ cd785dd, `next build && next start -p 3213`, headless Chrome at 1440 and 390.
Lead's suite against this build: 361 pass / 3 fail (keyboard @1440/@390: the five Gmail notification
buttons are not Tab-reachable before the notification shows; images: two `webwatcher-icon.png` with
`alt=""` and no `aria-hidden`). Console clean on /, /docs, two doc pages and /changelog at both widths;
CLS 0; no horizontal overflow (scrollWidth 1425/375).

## Anti-patterns verdict: PASS, with two tells
Not AI-slop: editorial numbering, Bricolage/Albert pairing, asymmetric compositions, mocks drawn with
real anatomy, no gradient text, no glow, no card grids — except (a) the three How-it-works steps
collapse into three identical cards at 390 and (b) the Watch-types table reads as a generic spec table
with a tiny example floating at the far right.

## Critical
1. **macOS speech synthesis** — `src/components/landing/herald/HeraldDemo.tsx:95,175,183,211-216`
   uses `speechSynthesis` / `SpeechSynthesisUtterance`. Hard owner violation. Replace with the
   pre-rendered Kokoro samples now in `public/audio/herald-*.mp3` (af_heart), click-only, visible
   playing state, never on load/hover/tests.
2. **Invented product behaviour** (accuracy vs `Sources/WebWatcher`):
   - Notification text "Badge went 3 → 5", "Text went “Open” → “Closed”", "Elements went 3 → 4",
     "Inbox badge went 2 → 3" (`WatchTypes.tsx:23-28`, `steps/StepsDemo.tsx:88`, `steps/Stage.tsx:160`,
     `HeraldDemo.tsx:282-294`). Real defaults (`NotificationService.swift:316-356`): title = watcher
     name; body "You have N new messages" (badge), "N new items (T total)" (count), "Content updated"
     + new text as subtitle (text), "Element appeared" / "Element disappeared", "Something changed
     inside the watched area".
   - "Six ways to read a page" lists **Document title** as a watch type (`WatchTypes.tsx:27`). The
     enum (`Watcher.swift:23-30`) is Badge/Number, Element Count, Text Change, Element Exists,
     Element Disappears, Anything Changes Inside. Tab title "(N)" is a *reading strategy* of badge watchers.
   - Gmail native notification has an **Open** button (`GmailDemo.tsx`, `gm-open`); the real actions
     are Mark as Read, Archive, Delete, Spam (`NotificationService.swift:49-72`); clicking the banner opens.
   - Gmail "Undo" after Archive/Delete/Spam is not a product feature (actions are one-shot API calls);
     "All read · Nothing left to read" notification is invented — the real app clears the notification
     when unread hits 0 (`GmailPollingService.swift:191-197`).
   - Copy "counts back down as you read in Gmail" (`Gmail.tsx:27`): the menu count follows; the
     banner is rewritten only on new mail and cleared at 0.
   - `public/llms.txt:7` says Gmail is "read-only"; scope is `gmail.modify` and the app archives/deletes.
   - Docs "only notifies when the value changes" (`content/docs/first-watcher.md:22`,
     `custom-notifications.md:17-19`): badge/count watchers notify only when the number rises
     (`WatcherService.swift:258-267`); text/subtree on any change.
   - Herald Gmail banner buttons "Open · Mark as Read · Archive · Snooze": the bridge sends Mark as
     Read, Archive, Delete, Spam (`HeraldBridge.swift:713-731`); Snooze is Herald's own option
     (`snooze:true`), kept because the owner's brief asks for it, but Open is not sent for mail.
3. **Third-party request at runtime** — the Rive runtime fetches
   `https://unpkg.com/@rive-app/canvas@2.44.0/rive.wasm` (no `RuntimeLoader.setWasmUrl` in `src/`).
   A privacy-led product site must not phone a CDN. Self-host in `public/rive/`.

## High
4. **Double notification, systemic** — every stage that draws its own macOS-style notification
   (How-it-works beat 3, every Watch-types row, Gmail arrivals, picker Add) also fires an identical
   site notice top-right via `record()` → `WatchNotices.tsx`. Two copies of the same banner, 150 px
   apart (beat 3 at 1440 even overlaps). The site watcher should *react* (badge tick, glance, popover
   row) and teach itself once with a distinct callout anchored to the mark, not repost the stage's banner.
5. **Popover lists the same watcher N times** — `WatchPopover.tsx:63-65` renders one row per
   recorded change: "Gmail · @rive.app · Last: 2 / Last: 1 / Last: 3 / Last: 2 / Last: 1". The real
   popover has one row per watcher with its latest reading. Coalesce by `name`.
6. **Rive load ignores reduced motion / Save-Data / touch** — `WatchMark.tsx:55-93` always imports
   the 232 KB chunk + 132 KB .riv + WASM after idle+visible, even when the eye-follow (its reason to
   exist) is a no-op on touch. Gate on `prefers-reduced-motion`, `saveData`/2g, coarse pointer <640,
   and wait for the first pointer/scroll/key interaction.
7. **Touch targets at 390** — `.gx__acts button` 30 px (`gmail.css:55`), `.hx__pill` 28 px
   (`herald.css:40`), `.hx__x` 22 px (`herald.css:34`), `.pd__pill`/`.sh__btn` 30 px
   (`picker.css:38,46`), `.ww-mark` 36 px (`watch.css:2`). Add `@media (pointer: coarse)` min-height
   44 or an `::after` hit-area.
8. **Heading hierarchy** — home reads h1,h2,h4,h2,h5…; docs start with h4 sidebar titles before the h1
   (`Footer.tsx:7`, `DocsChrome.tsx:18,124`, `Toc.tsx:31`). Use `<p>` with the same class.
9. **Six polite live regions on the home page** fire on timers (`WatchTypes.tsx:87`, `Privacy.tsx:88`,
   `GmailDemo.tsx:201`, `DownloadBox.tsx:50`, `HeraldDemo.tsx:311`, `WatchNotices.tsx:79` plus
   `role=status` in `PickerDemo.tsx:311,313`, `GmailDemo.tsx:167`). Keep live only on user-initiated
   outcomes (download, privacy "Ready", the site watcher); demo stages `aria-live="off"`.
10. **Real screenshot at the wrong size** — the sender-watcher editor shot (`gmail-sender-editor`)
    renders ~218 px wide under the Gmail copy at 1440: unreadable. Either a proper figure
    (≥ 420 px, 2x) or drop it.
11. **Oversized images** — `public/images/herald-icon.png` 1.2 MB rendered at 56–88 px;
    `herald-logo.png` 386 KB; `webwatcher-icon.png` 136 KB rendered at 16–66 px. Resize to 2× render.

## Medium
12. "Recent updates" shows 1.10.5 as newest while the hero/download say 1.10.9 (`recentUpdates()`
    skips Herald re-syncs on purpose, but nothing says so). Show the latest row as well.
13. Contrast: white on `#3b82f6` 3.7:1 for site UI (`watch.css:53`); white on `#e5362b` 4.3:1
    (`watch-types.css:36`). Mock-fidelity colours (picker toolbar `#3B74F6`) are exempt.
14. Herald Snooze tooltip "returns at 9:00" renders over the neighbouring "Mark as Read" label
    (`herald.css` `.hx__tip`); place it below the pill.
15. Layout-property animations: `herald.css:23` height, `gmail.css:38` margin. Use grid-rows/transform.
16. `WatchMark.tsx:165` blink interval never pauses on `document.hidden`.
17. `alt=""` without `aria-hidden` on two `webwatcher-icon.png` (lead's own images check).
18. The How-it-works mini Safari is 740×420 with two mails in the top 150 px — 60 % empty white.
19. Hero video `demo.mp4` (1.0 MB) is fully fetched at 390 within 3 s although `preload="metadata"`;
    hold `src` until play on coarse pointers / Save-Data.

## Low
20. "Watch the demo · 0:41" appears twice at 1440 (text link under the CTAs and the on-frame button).
21. The video frame bleeds 2 px past the container at 1440 (`hero.css` stage width) — reads as a
    crop of the menu-bar clock.
22. Changelog preview truncates mid-word ("…reject its Gmail… · The Herald email").
23. `tests/qa.mjs:7` unused `_res` lint warning.

## Demo video (web/public/video/demo.mp4, take 4) — judged from frames at 0/10/20/23–41 s
Stage, chrome and legibility are good; the real popover, Add Watcher, Confirm diagnosis and the real
banner at 33.6 s all read at 1440. Two flaws, both script-level (no re-record performed):
- dead holds: 29.0–33.5 s (badge already 4, nothing happens until the banner) and 37.5–41.2 s
  (static tail) — ~8 s of 41 s. Script: trigger the check right after the bump and cut the tail to ~1.5 s
  (`WW_DEMO_TRIM_END`, and the check-interval wait in the demo driver).
- after the row insert the WKWebView shows a dark overlay scrollbar on the page (frames 29 s+).
  Script: `::-webkit-scrollbar{display:none}` / `overflow:hidden` on `web/demo-page/index.html`.

## Positive
Global `:focus-visible`, reduced-motion in every animated file, no bounce/`transition: all`, fonts
self-hosted via `next/font`, 2× screenshots with srcset, scrollbar-gutter stable, nowrap nouns
hold at 390, console clean, CLS 0, docs header/icon at the specified height, real captures framed
consistently, every demo has a puppeteer test.

---

## After the fixes (commit f066344, verified on a fresh `next build` at :3213, 1440 and 390)

| # | Finding | State |
|---|---|---|
| 1 | speechSynthesis | **Gone** (`grep -rn speechSynthesis src` → 0). Speaker plays `public/audio/herald-*.mp3` (Kokoro af_heart, rendered once locally), lazily on first click, click again stops; visible "reading" meter + title underline; never on load/hover/tests (tests stub `Audio`). |
| 2 | Invented behaviour | Notification text = watcher name + real default body everywhere (steps, watch types, Herald web banner). Six real types (Document title removed, Element Exists / Element Disappears split). Gmail: no Open button (card click opens), no Undo ("Put it back (demo)"), notification folds at 0 with "Nothing unread… — notification cleared". Herald mail banner: Mark as Read · Archive · Delete · Spam · Snooze; web: Open · Snooze. llms.txt, first-watcher, custom-notifications, sender-and-domain-watchers, herald-delivery corrected. |
| 3 | unpkg WASM | Self-hosted `public/rive/rive.wasm` (+ fallback), `RuntimeLoader.setWasmUrl`; verified: the only wasm request is `localhost/rive/rive.wasm`, no unpkg/jsdelivr. Switched to `@rive-app/react-canvas-lite` (WASM 901 KB instead of 1.99 MB; the mark is vector-only). |
| 4 | Double notification | Stages keep their own banner. The site reacts with the badge tick + one-time **in-header chip** left of the mark ("Contra · Logged in your menu bar — click it. →"; "Logged here →" under 600 px). It lives inside the header so it can never sit on a stage banner (the first under-the-mark callout did overlap beat 3's banner; replaced). |
| 5 | Popover rows | Coalesced per watcher; one Gmail row with the live count; value rolls on change; toggles drawn in the on-state. |
| 6 | Rive gating | No load under reduced motion, Save-Data/2g, coarse pointer < 640; otherwise after load + first pointer/scroll/key + idle + visible. Blink interval pauses on `document.hidden`. |
| 7 | Touch targets | 44 px hit areas on coarse pointers for Gmail actions, Herald pills/×/speaker/link, picker pills, the mark. |
| 8 | Headings | Footer/docs sidebar/TOC titles are `<p>`; outline is h1 → h2 → h3. |
| 9 | Live regions | Demo stages `aria-live="off"`; only user-initiated outcomes (Snooze/Done, "Nothing unread…", download, privacy Ready) and the site chip are live. |
| 10 | Editor screenshot | Full-width framed figure (≤ 560 px, 2× srcset) with caption, shown ≥ 1100 px. |
| 11 | Image weight | herald-icon 1.2 MB → 46 KB, herald-logo 386 KB → 15 KB, webwatcher-icon 136 KB → 12 KB; separate 180 px apple-touch icon. |
| 12 | Recent updates | 1.10.9 "Latest" row prepended; word-boundary truncation. |
| 13 | Contrast | Site-UI blues/reds on tokens (`--danger: #d92d20`); mock-fidelity colours kept. |
| 14 | Snooze tooltip | Below the pill. |
| 15 | Layout animations | Herald slot and Gmail card fold with grid-template-rows (banner stays mounted while folding; measured 0 → −97 → −168 → −177 px over 300 ms). |
| 16 | Blink interval | Pauses when hidden, off under reduced motion. |
| 17 | alt="" + aria-hidden | All decorative images. |
| 18 | Empty How-it-works stage | Four mails; the new one turns bold in beat 3. |
| 19 | Video on mobile | `src` assigned on play for coarse pointers / Save-Data. |
| 20–21 | Hero duplicates/bleed | Text link hidden ≥ 1100; stage width from `100cqw`. |
| 23 | Lint | Clean. |

Suite: 461 pass / 0 fail (the lead's 11 files, updated to the new behaviour; every check runs at 1440/1280 and 390).
Console clean on /, /docs, two doc pages, /changelog at both widths; CLS 0; scrollWidth 1425/375.
