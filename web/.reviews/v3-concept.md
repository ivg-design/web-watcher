# WebWatcher web v3 — concept

v2 (`web-v2-prebold`) is a correct, quiet, light-blue product page: Bricolage/Albert, numbered eyebrows, a
framed recording on the right, a dark picker band, a spec table of watch types, a blue download band.
Every demo is real and every interaction has an outcome; nothing in it would stop a motion designer. v3
keeps the demos, the strings, the facts and the test suite, and replaces the identity: the fold, the
type, the colour, the motion signature and the composition of every section.

SidebarFavorites v3 got "the page opens inside the sidebar": a desktop UI at poster scale, grey resolving
into colour, Schibsted + one Newsreader italic word, a magenta accent, one verb (resolve = cross-dissolve),
a GSAP pin that zooms out, warm paper. None of that appears here.

## The one idea: the page keeps time, and you see the moment

WebWatcher's whole promise is a single instant: a number changes somewhere you are not looking, and you
are told. Its material is time: an interval, a check, a count. So the site is built out of time.

**The fold is the loop you do by hand, and the moment it ends.** At 1440×900 the first screen is a
graphite page with a condensed headline, "Stop refreshing." over "Start knowing.", and beside it the
largest object on the page: `(0)`, the unread count from a tab title, set extended and light at 38 vh.
Under it, at 1:1 scale, a Safari tab: `(0) Inbox — Contra` (the owner's origin story, the client
message he missed for two days). The tab reloads. And reloads. A mono counter ticks `⌘R ×1 … ×5`
(400 ms each), the address-field progress fills and empties, and the count stays `(0)`.

At 2.4 s the loop stops: the tab title ticks to `(1)`, the giant `(0)` rolls to `(1)` and cuts to badge
red, the hourglass in the header flips (a check), its badge ticks to 1, and the one-time chip appears
beside it ("Logged in your menu bar — click it."). The second line of the headline, which was sitting
at 40 %, goes to full. That is the product in 2.4 s: anxiety is a loop; knowing is a tick. A small
Replay re-runs it. Reduced motion renders the end state.

Below the fold the hero continues with the real app: the 41 s recording at container width (a 1280 px
frame at 1440, bleeding at ≥ 1100), poster = the real popover, plays in place with sound control.

**The page keeps time.** The header is the menu bar: a 64 px graphite strip with the app icon
(54 px, links home), the nav, the mark, and a live clock (`Thu 8:14 PM`, real, ticks each minute, like the
one the glyph sits next to on a Mac). The site watcher checks on the app's real default interval, 30 s:
the hourglass flips, the popover says "Checks every 30 seconds · Last check: 12 seconds ago". In
"The interval" band the visitor can pick any of the app's seven intervals (15 s … 30 min); the
arithmetic ticks (`2,880` looks a day at 30 s; `5,760` at 15 s) and the header mark adopts the interval.

**Motion verb: tick.** Nothing on this page fades, dissolves, scales or bounces. Things cut in
(entrances are hard cuts staggered 60 ms, like a flip board), numbers roll one step (a 0.6 em vertical
roll, 180 ms, ease-out-expo), colours cut (bone → red, 0 ms). The only continuous motion is the sand in
the hourglass, which is time itself. Scroll-driven counters snap to integers. This is the opposite of
SBF's one verb, and it is what a counter, a clock and a badge actually do.

**Night → day.** The page is graphite (a cool near-black, tinted toward the blue of the old accent,
never pure black) with bone type, because the product works while you are not looking, and because the
owner's vivid gradient captures are the only colour and read as lit windows on a dark desk. The last
section, Download, is the one theme switch: bone paper, ink type, "Stop refreshing today." The page
ends in daylight. Changelog and footer stay on paper.

**Monitor wall.** The six watch types stop being a table. They are six panels on the dark page, each a
live specimen at ≥ 160 px (a bell with a badge, a status chip, a list, a product tag, a waitlist button,
a bell with no badge), each with a mono label and its own tiny next-check tick. Click a panel: the change
rolls, the panel's hairline cuts to red for 1.2 s, the real notification (title = watcher name, body
from `NotificationService`) lands inside the panel, the header badge ticks. "Put it back" resets.

## Why it is true to the product

- The giant `(0)`/`(1)` is a reading strategy the app really has (the `(N)` in a tab title) and the
  thing everyone recognises from a Gmail tab. The Contra inbox is the reason the app exists.
- The interval options, the 30 s default, "Last check" and the body strings are the app's own.
- The header is where the app lives: a menu bar with a clock and the hourglass-with-eye.
- Every mock is the real anatomy (tab strip, notification, popover). The hero's second row is the real
  app recorded.

## Why it is bold

- A fold that performs anxiety with four objects (a tab, a counter, a numeral, a menu-bar glyph) and
  resolves in one tick. No decoration, no blob, no screenshot carousel.
- A motion signature nobody uses on a product page: hard cuts and single-step rolls. It reads as a
  departure board, a clock, a badge.
- A page that genuinely keeps time: real clock, real interval, checks you can watch happen.
- A wall of six living specimens instead of a feature table.
- A single theme switch at the end that means something (night → day).

## Type system

- One family, two widths: **Archivo** (variable, `wdth` 62–125, `wght` 100–900, via `next/font/google`
  with `axes: ["wdth"]`). Nothing from SBF (Schibsted, Newsreader), lerp (Figtree, Azeret, Newsreader),
  fnav (Nunito) or v2 (Bricolage, Albert).
  - Headline: `font-stretch: 62%`, weight 800, `clamp(72px, 9.6vw, 148px)`, leading 0.9,
    tracking −0.02em, sentence case. Two lines. No accent word, no italic, no serif.
  - The numeral `(0)`: `font-stretch: 125%`, weight 200, `clamp(160px, 38vh, 360px)`, tabular lining
    numerals, tracking −0.06em. The only light weight on the page.
  - Section titles: stretch 62 %, weight 800, `clamp(40px, 5.6vw, 72px)`, leading 0.94, tracking −0.02em.
    No eyebrows, no numbering, no icons above headings.
  - Body: Archivo 100 % width, 400, 17/1.55 (16 on phones), measure ≤ 62ch. Lede 20/1.45, bone-2.
  - Labels (panel names, the ⌘R counter, interval chips, clock): **JetBrains Mono** 500, 12–13 px,
    `tabular-nums`, tracking 0.02em, uppercase only for 3-letter labels. Mono is used for data (counts,
    times, selectors, versions), never as a vibe.
  - Inside macOS mocks: the system font, native metrics.
- `font-variant-numeric: tabular-nums lining-nums` on every element that ticks.
- No em-dash or middle-dot separators in copy except where the app itself prints them (the popover
  rows). Facts line uses commas and full stops.

## Palette (OKLCH, tokens on `.night` scope; docs keep v2 tokens)

- `--n-bg: oklch(0.205 0.012 255)` graphite (≈ #1A1C23), `--n-bg-2: oklch(0.245 0.013 255)` panel,
  `--n-line: oklch(0.34 0.012 255)` hairline, `--n-line-2: oklch(0.42 0.012 255)` hover hairline.
- `--n-ink: oklch(0.96 0.006 90)` bone (≈ #F3F1EC), `--n-ink-2: oklch(0.80 0.008 90)`,
  `--n-muted: oklch(0.66 0.01 255)`.
- `--n-signal: oklch(0.63 0.22 27)` badge red (macOS red, ≈ #FF3B30 family) — used ONLY where the
  product shows red: badges, the moment, the wall's fired hairline, the one-time chip arrow. Never for
  links, buttons or focus.
- UI accent is bone: primary button = bone fill, graphite text; ghost = hairline; links = bone with a
  1 px underline; focus ring = bone.
- Paper (Download, Changelog, Footer): `--p-bg: oklch(0.955 0.008 90)` bone paper, `--p-ink:
  oklch(0.20 0.012 255)`, `--p-line: oklch(0.86 0.01 90)`, `--p-muted: oklch(0.48 0.012 255)`.
- Vivid gradient (the owner's capture backdrop, orange → magenta → violet) appears only inside frames
  that hold a capture or the recording. Never as a page background, never under text.
- Texture: a 2 % mono grain (`<svg feTurbulence>` data URI, fixed) on the graphite so it is a surface,
  not a flat fill. No glow, no blur, no glass, no gradients outside the frames.

## Motion language

- Easing for anything that moves on its own: `--ease-expo cubic-bezier(.16,1,.3,1)`. Pointer-follow
  (the eye) keeps its damped lerp.
- **Cut**: entrances are `visibility`/opacity steps with no tween (`steps(1)`), staggered 60 ms on the
  fold only (headline line 1 at 0, line 2 at 60, numeral at 120, strip at 180, CTAs at 240). Nothing
  else on the page animates on entry. No scroll-reveal fades anywhere.
- **Roll**: a numeral change is a two-layer vertical roll (old up, new in from below) of 0.6 em over
  180 ms, ease-expo, `overflow: hidden`, no blur. Used by the giant numeral, the tab title count, the
  ⌘R counter, the interval arithmetic, the wall's values, the badge (already rolls).
- **Fire**: the moment = roll + colour cut to signal + the header mark's flip (500 ms, existing) +
  badge tick (existing). 0 ms of easing on the colour.
- **Keep time**: the mark's sand loop is the only continuous animation; it adopts the chosen interval
  as its loop length when the interval is ≤ 60 s (sand drains over the interval; at longer intervals it
  keeps the 6.5 s loop and the popover carries the truth).
- **Scroll**: counters in "The interval" tick from 0 to their value over the band's first 60 % of
  entry (IntersectionObserver + rAF, no library); they snap to integers and their final value is in
  the HTML. No pin, no scrub-video, no parallax.
- Reduced motion: end states, no loop, no cuts (everything present at t = 0), rolls become swaps.
- Loops stop off-screen and when the tab is hidden. No tickers, no marquee.

## Sections and what each interactive element demonstrates

1. **Hero: the moment.** Hover the tab strip: reload button highlights (it is a control: click = one
   more manual refresh, the counter ticks, the count stays 0 — you can keep refreshing by hand and it
   never helps). Replay re-runs the 2.4 s. The Download button is the real DMG from the GitHub API with
   fallback; facts line: Apple Silicon only, macOS 13 or later, signed and notarized, MIT, nothing
   leaves your Mac. The recording row: play in place with sound, pause, mute; caption. Header mark:
   eye follows, hover 3 s blinks, click opens the popover listing the Contra change.
2. **The interval.** Seven interval chips (the app's `CheckInterval` cases). Click one: the sentence's
   numbers roll (`86 400 / interval` per day, ×7 per week), the header mark adopts the interval, the
   popover reads "Checks every N". Copy: "Every 30 seconds it looks. 2,880 looks a day. You make none."
3. **How it works.** The v2 stage (Page → Element → Confirm on the Contra inbox) with the three beats as
   a time ruler (t+0.0 s, t+3.2 s, t+7.6 s), clickable; the beat that is live is lit. Stage fills the
   left two thirds.
4. **Guided picker.** The v2 simulation, restyled; the popover mock moves beside the Safari sketch at
   ≥ 1280 instead of over it.
5. **The wall.** Six panels (above). Each click: roll, red hairline, real notification inside the
   panel, header badge. "Put it back" resets. Site-profiles note under the wall.
6. **Gmail.** The v2 demo (arrivals, Mark as Read / Archive / Delete / Spam acting on the mini inbox),
   restyled; the sender-editor capture at ≥ 440 px in a vivid frame.
7. **Herald.** The v2 banner demo (snooze returns, Kokoro samples click-only with the level meter),
   restyled on a graphite panel.
8. **Privacy.** The v2 data-path diagram and the three switches (ticking all three lights "Ready").
9. **Download (paper).** DMG with version and size from the release, SHA copy flips to a check, press
   feedback; requirements. 10. **Changelog** rows on paper. Footer on paper.

## Three alternatives I rejected

- **The eye as protagonist.** A 300 px cursor-following eye in the hero. It is a mascot page for a
  product with no mascot, and the mark already does it at 36 px where it belongs: in the menu bar.
- **The split-screen film, "you refreshing vs it watching".** The truest narrative, but a 10 s film
  the visitor must wait for; it became the fold's 2.4 s loop and the one-line arithmetic of "The
  interval".
- **The popover at poster scale.** UI at 3× with the rows ticking. That is SidebarFavorites' move.
- (Also rejected: warm paper with a serif pivot, the house style of two sibling sites; and a
  dashboard with gauges and green status dots, the "operations landing" every tool reaches for.)

## What stays from v2

All demos and their real strings; `WatchContext`/mark/popover/chip system; the recording and its
in-place player; Kokoro samples click-only; `.nw` nowrap for proper nouns; `scrollbar-gutter: stable`;
docs shell (centred, 64/54 header, decoded entities, tables never wrap code) with its light theme;
release fetch with fallback; the puppeteer suite (extended for the moment, the interval, the wall);
`browser.close()` always.
