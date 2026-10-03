# WebWatcher site — design direction (round 2)

Owner verdict on round 1: "every single interactivity/animation example is bad… absolutely pointless",
"copying the wireframe without any thoughts", "I want to be wowed". Section order and copy from
design/BUILD-BRIEF.md stay. Execution is rebuilt.

## The one idea: the page is a watched page

WebWatcher's whole promise is "something else watches, and tells you the moment it changes". So the
site carries its own watcher. The menu-bar mark (the hourglass with the eye, the app's real
menu-bar glyph `hourglass.badge.eye`) lives in the sticky header and literally watches:

- the **eye follows the cursor** (it is watching), the **sand runs** on the check interval and the
  glass flips when a check runs;
- every demo on the page reports the change it produced to `useWatch().record(...)`
  (`src/components/watch/WatchContext.tsx`). The mark **ticks its badge**, a **notification lands
  top-right** exactly like the macOS notification WebWatcher posts (icon, title, body), and
  **clicking the mark opens the popover** — the app's real popover design, listing what it saw
  on this page ("Rive Community · bell — 3 → 5, just now"). The page's own interaction log *is* the
  product UI. Hover the mark for 3 s and it blinks (easter egg from the brief).
- Nothing moves without meaning: eye = watching, sand = interval, flip = check, badge = changes,
  notice = the product's output.

## What each section demonstrates (all real behaviour of the app)

| # | Section | Demonstrates | Interaction with a visible outcome |
|---|---|---|---|
| — | Hero | The real app | Real popover capture as poster; click → the 1:13 demo plays IN PLACE with sound (no modal, no muted autoplay). Pause/mute on the frame. |
| 01 | How it works | Page → Element → Confirm, the origin story (the Contra client message the author missed for two days) | One stage, a faithful mini Safari window on contra.com inbox. Three beats auto-play while in view and are clickable: (1) the tab is found ("Found in Safari: Inbox · Contra"), (2) the REAL in-page pick toolbar appears, keys press ↑ ↓ → ⏎ in sequence and the blue outline hops (`outline:2px solid #3B74F6; background:rgba(59,116,246,.15)`, toolbar `#1e1f27` pill bottom-centre: "← → siblings · ↑ parent · ↓ child · ⏎ use · ⎋ cancel" + Use / Cancel), (3) the badge goes 0 → 1 and the notification posts → `record()`. |
| 02 | Guided picker (dark) | The same flow, hands-on, on a Rive Community page | Scan page → ranked candidates → outline on the page; Pick in Safari → mouse/arrow keys walk the DOM with the real toolbar; Confirm → live read → Add watcher → the row appears in the popover mock AND `record()`. |
| 03 | Watch types | The six strategies | Each row IS the demo: click anywhere on the row (or its "see it" control) and the example element changes in context (a bell badge 3→5, a status chip "Open"→"Closed", a tab title "(0) Inbox"→"(3) Inbox", a list gaining items, an aria-live counter, a price). Then the resulting notification shows in a single shared notice slot under the table AND `record()`. No "Play" buttons in a column. |
| 04 | Gmail | Sender watchers, grouped count, buttons that act on every counted message | Mini Gmail inbox list beside the notification. New mail arrives (rows stack in, count 1→2→3, auto once on view then on demand "Deliver another"). On the notification itself: Open · Mark as Read · Archive · Delete · Spam — pressing one acts on the mini inbox (rows un-bold / leave / strike), the count follows, the notification collapses when nothing is left. `record()` on arrivals. |
| 05 | Herald | Persistent banners with buttons, read aloud | A faithful Herald banner (dark card: image/icon left, app line, title, body, pill buttons Open · Mark as Read · Archive · Snooze, close ×) enters from top-right like a real banner, stays. Snooze hides it and shows "returns at 9:00", then it returns. The speaker button reads the title aloud with `speechSynthesis` (Herald really reads banners aloud). |
| 06 | Privacy | Nothing leaves the Mac | Editorial, no icon-grid: a single diagram of the data path Safari tab ⇄ WebWatcher ⇄ Notification Center, with "internet" visibly not on the path; the three switches as a checklist you can tick (ticking all three lights "ready"). |
| 07 | Download | Latest release | Real GitHub API data with fallback; press feedback; "Starting download…" label; SHA copy flips to a check. Facts: Apple Silicon only, macOS 13+. |
| 08 | Changelog | Three latest | Mono version/date columns, unchanged. |

## Visual system (keep tokens in globals.css)

- Light page, blue-tinted neutrals, electric blue accent, two dark bands (picker, Herald), one
  full-bleed blue band (download). Bricolage Grotesque 800 for the hero, 600 for titles; Albert Sans
  body; JetBrains Mono only in selectors/values/version numbers.
- Section eyebrows carry an editorial number: `<p className="eyebrow"><span className="eyebrow__n">02</span>Guided picker</p>`.
- Asymmetric compositions, generous rhythm (sections 96–140 px), no cards-in-cards, no identical
  card grids, no glow, no glassmorphism, no gradient text, no icon-above-every-heading, no bounce.
- Motion: transform/opacity only; ease-out-quart/quint/expo (`--ease-quart/quint/expo`); exits
  ≈75 % of entrances; `prefers-reduced-motion` → final states, no autoplay sequences.
- Mobile 390 is designed, not shrunk: stages stack above their copy, controls ≥44 px, no
  horizontal overflow, every demo still operable by touch.
- Mock fidelity: when we draw the app or macOS, draw it right (real popover rows, real toolbar
  text, real notification anatomy: 36 px icon, bold title, body, "now").

## Engineering rules

- Next 16 app router, React 19, Tailwind v4 present but sections use plain CSS files under
  `src/styles/` imported by their component. Client components only where state is needed.
- Verify against the owner's live dev server **http://localhost:3101** (read-only; never start,
  restart or kill it; never run `next dev`/`next build` yourself — the lead builds). Tests:
  `BASE=http://localhost:3101 node tests/<name>.mjs` with puppeteer-core (`tests/_h.mjs`).
  Headless only. If the page shows a compile error from a file you do not own, wait 20 s and retry.
- Keep the tree compiling at all times: create new files first, switch imports last.
- Strict file ownership (see the task you were given). `globals.css`, `page.tsx`, `layout.tsx`,
  `WatchContext.tsx` are the lead's — ask for additions in your report instead of editing.
- `data-testid` on every interactive piece; a puppeteer test per demo that drives the real
  interaction and asserts the visible outcome (text, class, geometry), not implementation details.
- `asset()` from `@/lib/config` for every root-relative URL.
- Lint must stay clean (`npm run lint`).
