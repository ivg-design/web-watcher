# v3 round 3 — plan (written before building)

Round 2's verdict: the fold keeps the promise, sections three to seven do not. They share one rhythm
(title left, lede, demo in a rounded panel) and time, the page's material, is absent from them. This round
recomposes How it works, Picker, the wall, Gmail and Herald. Rule for the pass: each section gets ONE
composition idea taken from the concept's own vocabulary (the ruler, a count, a tick, the before and after
of a change, scale contrast), no two neighbours share a layout, and every demo that exists keeps working
because the demos are the content. Before screenshots: scratchpad `r3/before/` at 1440, 1280, 834, 390.

Page rhythm after the pass (what the eye meets, top to bottom):

| # | Section | Layout | Idea |
|---|---|---|---|
| 1 | Hero | title left, numeral right | the moment |
| 2 | Interval | sentence left, list right, hour ruler | the hour, ruled |
| 3 | How it works | head row, full-width stage, transport bar under it | a film with a timecode |
| 4 | Picker | full-bleed band, demo first, giant readout, claim after | what it reads, at poster scale |
| 5 | Watch types | a board of six rows, each with its own countdown | every watcher keeps its own time |
| 6 | Gmail | the headline split in two columns, lit and dim | a sender, not an inbox |
| 7 | Herald | the section is the screen: banners top right, title bottom left, voice ruler | the ruler speaks |
| 8 | Privacy | three numerals | zero |

## 3. How it works

- **Now.** `h2` and lede on the left, then a framed stage in the left two thirds and three stacked step
  buttons on the right with `t+0.0 s` stamps at 12 px. The "time ruler" is three small squares.
- **New: an 11.2 second film with a timecode.** Head row: title left, lede right on the same row. The
  stage takes the full content width. Under it sits a transport, like the bottom edge of a player: on the
  left the running time of the demo in the page's light numeral at display size (`07.6`, a small mono `s`),
  stepping every tenth of a second; to its right a ruler of the whole run, one tick per 0.1 s (112 ticks),
  seconds labelled, ticks lit up to now. The three steps are the ruler's chapters: three buttons whose
  widths are their real durations (3.2 s, 4.4 s, 3.6 s), stamp, title and copy under each. When the
  notification lands in the stage (t+8.5 s) one tick on the ruler cuts to the signal red and stays:
  `t+8.5 s notified`. Clicking a chapter jumps there (existing behaviour, existing hold).
- **Why it is not generic.** The section's subject is a duration and the layout is that duration: you read
  how long each step takes from the width of its column, and the biggest thing on screen is a clock that
  runs with the demo. No card, no numbered circles, no alternating image and text.
- **Moment.** The numeral ticking tenths while the picker outline walks the page, and the red tick.
- Reduced motion: final frame, `11.2`, every tick lit, the red tick present. Under 700 px: ticks every
  0.2 s, chapters stack under the ruler as a list, numeral at 72 px.

## 4. Picker

- **Now.** Title and lede on the left, then one rounded panel with three columns (sheet, Safari sketch,
  popover). The value WebWatcher reads is a 13 px line in a definition list.
- **New: the page, read at poster scale.** A full-bleed band on the panel tone (no rounded panel). The demo
  comes first: Add Watcher sheet, the Safari sketch (wider), and a third column that is a readout: the
  value of the element that is outlined right now, set in the light numeral at up to 240 px (`3`), with the
  strategy and the selector in mono under it, and the menu popover below. Before a scan it reads a dash.
  Scan page: the sweep runs, the candidates' outlines cut in one after another (60 ms apart) and the readout
  rolls to `3`. Select another candidate, or move over the page in Pick mode, and the readout rolls to
  what that element reads (`Inbox (12)`, `48 items`); text values set smaller, numbers set huge, which is
  also the truth about what a watcher is best at. The claim comes after the demo: title bottom left, lede
  bottom right. On phones the title returns to the top (the stacked demo is long).
- **Why it is not generic.** The headline says "It reads the page" and the composition makes the reading
  the largest object, live under the pointer. The order (proof, then claim) is the reverse of every other
  section.
- **Moment.** Pick in Safari, sweep the mouse across the sketch: the giant value rolls with the outline.

## 5. Watch types (the wall)

- **Now.** Title, lede, a 3 × 2 grid of equal cards, each with a static `30 s` label. The most common
  layout on the web.
- **New: the board.** Six full-width rows ruled by hairlines, like a departure board. Columns: the
  countdown to that watcher's next check in the light numeral (`0:12`), ticking once a second; the type
  name in the condensed display face at 40 px with its description; the live specimen; the reading column
  (the current value in mono, `was 3` and `now 5` after a change, and the real notification landing
  there). The six watchers have different intervals from the app's own list (15 s, 30 s, 1 min, 2 min,
  5 min, 10 min) and different phases, because in the app each watcher has its own timer. When a countdown
  reaches zero the row checks: the hourglass glyph flips, the countdown cuts back to the interval and the
  row stamps the time it last read. Clicking a row changes its page and checks it now: value rolls, the
  row's hairline cuts to red for 1.2 s, the notification lands in the row, the header badge ticks. "Put it
  back" resets. The head is one line across the full width with the lede at the right.
- **Why it is not generic.** Six clocks out of phase, each counting to its own check, is the product's
  real model (a timer per watcher) made visible, and a board that keeps ticking while you read it.
- **Moment.** The column of countdowns, one of which is always about to reach zero.
- Leftover fixed here: Element Count's `3 items` sits directly under the third row before the click.
- Reduced motion: no ticking; the countdown column prints the interval (`every 30 s`).

## 6. Gmail

- **Now.** Copy left, a rounded panel right with a notification floating over a white inbox; the editor
  capture in a full-width gradient frame below.
- **New: the headline is the diagram.** Two columns. Left, lit: "Watch a sender," and under it the single
  notification that counts up. Right, at 40 % ink like the fold's second line before the moment: "not an
  inbox." and under it the inbox, restaged on the night surface with every row dim except the watched
  sender's, which are bone. One thing lit on the left, the noise dimmed on the right, a hairline between.
  Mail arrives on the right; the count rolls on the left. Actions on the left act on the rows on the right.
  Second row, mirrored: the real editor capture in its vivid frame on the left (7 columns), the paragraph,
  Sign in with Google and the scope line on the right (5).
- **Why it is not generic.** The two halves of the sentence label the two halves of the screen, and the
  contrast the sentence makes (one sender against a whole inbox) is the contrast in light.
- **Moment.** A mail from the sender arrives in the dim inbox, its row is the only lit one, and the count
  on the left rolls.

## 7. Herald

- **Now.** Copy left, a small framed "desktop" right with two banners, captions under it.
- **New: the section is the screen, and the ruler speaks.** Full-bleed on the panel tone. The banner
  stack hangs at the top right of the section where banners live on a Mac, under a thin menu-bar line. The
  title sits bottom left at the fold's scale with the copy and Get Herald. Across the full width between
  them runs the page's ruler once more, but its ticks are the waveform of the Kokoro sample: the real
  amplitude envelope of the mp3 (computed from the file at build time into a small JSON), one tick per
  40 ms. Press the speaker on a banner: the sample plays and the ticks light up to the playhead with a mono
  time (`0:02.4 / 0:05.1`). At rest the waveform is drawn dim. Click to play only; nothing speaks by
  itself.
- **Why it is not generic.** "Make it talk back" is shown by making the page's own time ruler into the
  voice. Banners sit where they sit on a real screen instead of inside a card.
- **Moment.** Pressing the speaker and watching the full-width ruler become speech.
- Reduced motion: the sample still plays on click; ticks light without transitions (they already cut).

## Rive mark

Round 2 could not bind animation speed, so the Rive mark only mounted above 60 s. This round the sand is
not a timeline: a view-model number `sand` (0 to 1) is bound through range mappers to the upper sand's
height, the pile's height and the stream's length, and the page writes the progress of the current check
into it every frame. A second trigger `turn` flips the glass without the eye's pop, for the idle loop at
intervals above a minute. Built locally with `rive . --once`, no Luau, nothing pushed.

## Leftovers

- Element Count label: with the board (above).
- First-change chip over the numeral's bracket at 1440: move the chip so its box clears the numeral.
- Mobile Lighthouse 88: find the LCP element in the trace and fix what delays it.

## Order of work

Plan (this file), before screenshots, five workers with disjoint files (one section each: its component,
its demo, its stylesheet, its test), the lead on the Rive mark and the leftovers, then a critique of the
whole page by eye at four widths, one more iteration on the weakest section, all suites, tsc, lint,
build, Lighthouse desktop and mobile, and an After section appended here.

## After

Measured on the final production build (:3285) after the last change: 15 suites, all exit 0 (docs 96,
download 18, gmail-mock 179, herald 247, hero-moment 35, hero-video 31, interval 36, layout 12, picker 69,
privacy 37, qa 11, steps 32, time 24, watch-types 427, watch 108 assertions); `tsc` clean; lint 0 errors
(2 unused-variable warnings in tests/gmail-mock.mjs); Lighthouse desktop 100 / 100 / 100 / 100 (LCP 0.7 s,
CLS 0, TBT 0); mobile 90 / 100 / 100 / 100 (FCP 1.2 s, LCP 3.6 s simulated, CLS 0, TBT 10 ms). No
horizontal overflow at 1440, 1280, 834, 390. Screenshots: scratchpad `r3/after/` (viewport shots per
section and whole-section clips, `tests/v3clips.mjs`).

| Section | Built as |
|---|---|
| How it works | The title alone at up to 108 px. The stage at the full content width. Under it the transport: the demo's running time (`04.5`) in the light numeral at 136 px stepping tenths, the lede under it, and a 112-tick ruler of the 11.2 s run with the three steps as chapters whose widths are their durations. The tick at 8.5 s cuts to red with `t+8.5 s notified` when the notification lands. |
| Picker | Full-bleed band on the panel tone, demo first, claim after (title back on top under 1100). Third column is the readout: the value under the outline at up to 240 px (`3`), text values smaller, strategy and selector in mono, the menu popover under it. The scan runs by itself once when the sketch scrolls into view (five candidate outlines cut in, the readout rolls); "Start over" returns to the manual Scan page. The sheet is a fixed-height window whose list scrolls, so the band never changes height. Keyboard focus survives the scan. |
| Watch types | A board of six ruled rows: countdown to the row's own next check at 80 px (15 s, 30 s, 1, 2, 5 and 10 min, out of phase, from the wall clock), the type in the condensed face, the specimen, the reading at 44 px with the time it was last read. A click changes the page and checks it: old value muted, new value rolls, red hairline, the notification lands in the row. |
| Gmail | One `h2` split over two columns and a hairline: "Watch a sender," lit over the single notification and the paragraph; "not an inbox." at 40 % over an inbox on the night surface where only the watched sender's rows are bone. Second row: the real editor capture, three ruled facts in the capture's own words, Sign in with Google. |
| Herald | The section is the screen: a menu-bar line, the banners hanging top right, logo and title bottom left at 128 px, and across the bottom a ruler whose ticks are the real waveform of the Kokoro sample (peaks from the mp3s by `scripts/herald-peaks.mjs`, 40 ms windows). Pressing a banner's speaker lights the ticks to the playhead with a running time. The in-banner meter uses the same peaks. |

Second iteration (after looking at the first results): the picker's dead column and "nothing yet"
opening (fixed sheet height, automatic scan); the board's small readings and tall rows (44 px readings,
80 px countdowns, 220 px rows, no red hint); Gmail's empty lit column and thin second row (paragraph
moved under the notification, ruled facts, stacked order on phones, arrivals start when the notification
slot is in view); How it works' empty space under the clock and its head row, which matched the board's
(title alone, lede under the clock).

Rive mark: done. `sand` (0..1) is bound through three range mappers to the upper sand, the pile and the
stream; `turn` flips the glass without the pop. The page writes the progress of the current check ten
times a second, so the Rive mark is the renderer at the default 30 s and at every other interval (at
60 s or less the glass drains over the interval; above it, the 6.5 s idle loop as before). Built with
`rive . --once`, no Luau (unsigned scripts are rejected by web runtimes), nothing pushed. Tested: the
canvas's upper bulb loses bone pixels over 6 s at 15 s, and `data-sand` advances at the right rate at 15 s
and 30 s. The file's own badge capsule is kept at 0 because it showed as a red sliver beside the DOM badge.

Leftovers: Element Count's label sits under the last list row before and after the click (asserted).
The first-change chip is one line (37 px) from 1100 up and ends 23 px above the numeral's ink (asserted
by pixels). Mobile LCP: the element is the hero lede; it was held back 240 ms by the staged cut, so the
observed LCP was 364 ms after the first paint. It now paints in the first frame (observed LCP = FCP).
The simulated figure moved from 3.8 s to 3.6 s and the score from 88 to 90.

### Still weak or unverified

- Mobile performance is 90, not 95+. The simulated LCP is now the model's cost of 122 KB of fonts and
  the framework's JavaScript on slow 4G, not a late paint. Dropping a font axis or the mono preload would
  be the next step and would cost the identity.
- The board is long on phones (about 3,980 px at 390) because each row reserves its notification's height.
- How it works at 1100 to 1280: the first chapter is 190 to 224 px wide and its copy runs six lines.
- Picker: the sheet shows about two candidates at a time (the list scrolls); the Pick-mode selector
  tip can sit over the "Latest topics" label (as before).
- Gmail: the dim half of the headline is about 3:1 against the ground. It is the second half of one
  `h2`, readable, but below 4.5:1 by design. With eight rows and three arrivals the last seed row leaves.
- Herald's waveform ticks are 40 ms peaks, about 105 ticks for a 4.2 s sample; on a 1440 screen they are
  12 px apart, sparser than the interval ruler.
- The countdowns on the board and the hour ruler are arithmetic on the wall clock, not a log of real
  checks by this page.
- Not verified: real Safari, real touch devices, audio output by ear (the test asserts playback state
  and time, not sound), the Rive mark on a real retina display, the forge deploy path.
