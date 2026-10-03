# v3 round 2 — independent review

Reviewed: `gmail` at 95a815e, production build served on :3284, headless Chrome at 1920, 1600, 1440, 1280,
834 and 390; every section, the interactive states, docs, changelog, 404; 2x crops of the header, mark and
popover. Screenshots: scratchpad `r2/before/` (names quoted below). Suites before any change: all 15 green.

## Verdict

1. **Wowed? Not yet.** The fold is the real thing (a tab reloaded five times, `(0)` to a red `(1)`, 2.5 s
   measured on first load and on reload). After it the page stops keeping time: the clock and the hourglass
   are 13 px and 36 px in a corner, and sections two to eight are a well-made dark product page with the
   same left title, lede, demo rhythm. The promised idea ("the page keeps time") is a header detail.
2. **Distinct from SidebarFavorites? Yes.** No UI at poster scale, no gradient world, no serif pivot word,
   no magenta, no pinned zoom. Graphite, bone, one red, condensed grotesk, hard cuts.
3. **Distinct from Herald? Yes, now.** Herald's own round 2 moved it to Georama with wide titles on a
   cobalt blueprint ground (herald d7719bc). WebWatcher is the only one on Archivo, condensed at 62 %, on
   graphite, with JetBrains Mono against Herald's Fragment Mono. Side by side (`r2/sib/herald-fold.png` vs
   `before/hero-fold-1440.png`) nothing is shared but the header's icon-nav-button order, which is the
   family convention. No change needed on the WebWatcher side.

## Blockers

- **B1. The recording row reads as a layout bug** (owner's report). `before/hero-rec-1440.png`, `-1920.png`:
  the frame starts at the content margin and runs off the right edge with square right corners, 1345×837 at
  1440 (taller than the viewport under the header), and the recorded window sits in its left two thirds.
  Cause: `src/styles/hero.css:39-41` (`--bleed`, negative right margin, `border-radius: 20px 0 0 20px`).
  Fix: no bleed. The frame is centred in the container, four 16 px corners, a hairline, and its width is
  capped so the whole desktop fits one screen: `min(100%, (100svh - 200px) * 1440 / 896)`. Label left and
  caption right on one mono line under it.
- **B2. A control that does nothing.** The recording has no audio stream (`ffprobe`: one h264 stream, one
  vp9), yet playback shows a mute button and the code calls it "with sound". `HeroDemo.tsx:139-141`, and
  `start()` unmutes. Fix: remove the mute control and its state; the video is `muted` always; comments and
  the test updated.
- **B3. Docs are a different site.** `before/pg-doc.png`: light blue-grey page, blue links and active
  states, a light header, against the landing's graphite menu bar. Cause: `src/styles/docs.css` still on
  the v2 `:root` tokens. Fix: docs take the v3 identity: the same graphite menu-bar header (icon 54, links
  home), body on paper tokens (bone, ink), accent ink with underlines, mono labels in JetBrains Mono, code
  chips on paper-2. Centred layout, decoded entities, non-wrapping code in tables and the stable gutter
  stay as they are and stay tested.

## Major

- **M1. The concept is under-delivered after the fold.** Time is the page's material and it is nearly
  invisible. Two moves:
  - *The header keeps the interval.* The menu bar's bottom hairline becomes the countdown to the next
    check: a bone line that advances one step a second across the full width and cuts back to zero when
    the hourglass flips. It follows the interval the visitor picks. It is the app's real behaviour (a
    timer per watcher), visible at every scroll position, and it is the tick verb.
  - *The interval band draws the hour.* Under the sentence, a full-width ruler of the current hour: one
    tick per check (120 at 30 s, 240 at 15 s, 2 at 30 min), ticks already past lit bone, the rest hairline,
    minute labels in mono, "now" marked by the real clock. Picking an interval re-rules it. The band's
    arithmetic becomes something you see. `Interval.tsx`, `interval.css`.
- **M2. Privacy is the flattest screen** (`before/1440-privacy.png`, `st-privacy.png`): three boxes, a
  dashed box, a struck box, then a half-empty switch row. Fix: lead with the claim as numerals in the
  hero's own voice. The `(0)` that meant anxiety at the top means the promise here: `(0) servers`,
  `(0) analytics`, `(0) data collected` (the three facts are verbatim from docs/data-and-privacy.md), set
  in the wide light numeral at display size, the path diagram under it, the switches beside their title
  without the dead half column.
- **M3. Changelog rows on the landing are cut mid-sentence and glued.** `before/1440-changelog.png`:
  "…makes WebWatcher reject its Gmail... The Herald email banner now…". Cause: `src/lib/changelog.ts:56-67`
  cuts each of three items at 108 characters and joins them. Fix: one item per row, the first, cut only at
  a sentence end; never an ellipsis followed by another sentence.
- **M4. The giant zero reads as the letter O.** `before/st-hero-pre.png`: `(O)`. Archivo's wide light zero
  is a near circle. Fix: the slashed-zero feature if the font carries it, otherwise narrow the numeral's
  width axis until the zero is an oval. The moment depends on the glyph being a number.
- **M5. Hero at 640–1099 wastes the fold** (`before/st-fold-834.png`): the headline leaves the right 45 %
  empty and the numeral, the subject of the page, starts 520 px down. Fix: from 700 px the numeral sits to
  the right of the headline (title left, numeral right, top-aligned), strip and caption under the CTAs.
- **M6. The Rive mark ignores the interval** (builder's #1): the sand loop is 6 s whatever the page says.
  Fix: a `period` number in the view model driving the loop's speed, built locally; if the file cannot be
  rebuilt cleanly, the SVG renderer (which does follow the interval) stays in charge and the Rive one is
  not mounted.

## Minor

- m1. Element Count specimen shows an empty fourth row before the click (`before/1440-watch-types.png`):
  reserve the height on the list, not as an empty bordered row.
- m2. "Three switches, once" leaves 60 % of its row empty at 1440.
- m3. The poster and the video are 1440 px wide; at the old 1345 px frame they were under 2x. The capped
  frame (about 1100 px at 1440×900) eases it; the source cannot be improved without re-recording.
- m4. Under 1100 the first-change chip waits for the first demo. Accepted: at those widths it would cover
  the headline during the moment; the badge still ticks.
- m5. /changelog leaves the right third of 1440 empty. Accepted for a reading column; it gets the v3 docs
  header treatment with B3.
- m6. Recoloured mark and the three recompressed icons inspected at 2x (`before/x2-header.png`,
  `x2-popover.png`, the 128 px sources): no banding or fringe. No change.
- m7. Add the brand-home assertion to the suite (the fix from 2263b5a works: 8065 px with `#privacy` to
  0 and no hash).

## Checked and fine

Moment timing 2.46–2.57 s after navigation, first load and reload; reduced motion renders the end state;
no proper noun wraps at 390; no horizontal overflow at any width; Kokoro samples are click-only and
there is no `speechSynthesis`; icons are transparent PNGs; "41 s" appears nowhere.

## After

Measured on the final production build (:3284) after the last change: 15 suites, all green (docs and
layout exit 0; download 18, gmail-mock 83, herald 193, hero-moment 35, hero-video 31, interval 36,
picker 48, privacy 37, qa 11, steps 22, time 24, watch-types 180, watch 105 assertions); `tsc` and lint
clean; Lighthouse desktop 100 / 100 / 100 / 100 (LCP 0.7 s, CLS 0, TBT 0); mobile 88 / 100 / 100 / 100
(LCP 3.8 s simulated, CLS 0, TBT 10 ms). Screenshots: scratchpad `r2/after/`.

| # | Before | After |
|---|---|---|
| B1 | Recording bled off the right edge, square right corners, 837 px tall, window in the left two thirds | Frame is the content width, centred, four 16 px corners and a hairline, at 1280, 1440, 1600 and 1920. The poster is now the frame at 4.6 s of the same recording (Safari left, the Add Watcher window right), so the still is balanced. Play control centred on the frame. Label and caption share one line under it. The video files are untouched. |
| B2 | Mute button on a silent recording | Removed, with its state; the video is `muted`; the test asserts there is no sound control and no audio track. |
| B3 | Docs light blue-grey with a blue accent and a light header | Graphite menu-bar header (icon 54 links home), bone paper body, ink links with underlines, ink active states, mono labels, hairline code blocks, tables and callouts; the search overlay follows. Layout, gutter and entity tests unchanged and passing; new assertions for header colour, no old blue, brand href, nowrap code in tables. |
| M1 | Time was a 13 px clock | The menu bar's bottom edge is the countdown to the next check: one step a second, cuts to zero on a check (timed, a recorded change, or "Check All Now"), follows the chosen interval; absent under reduced motion. The interval band draws the current hour, one tick per check, lit up to the real clock, re-ruled when the interval changes (ten minutes on phones), with a live line: "Since 1:00 PM a watcher on this interval has looked 37 times. 83 to go before 2:00 PM." Checks now re-arm after every check so the line never lies. |
| M2 | Privacy: boxes and one dot | Three `(0)` numerals (servers, analytics, data collected, the words of docs/data-and-privacy.md) that count down to zero once, the diagram under them, the switches as three full-width columns. |
| M3 | Changelog rows cut and glued | First item only, whole sentences, one ellipsis at most and nothing after it; asserted. |
| M4 | `(O)` | The numeral is set at 88 % width; the zero is an oval and reads as a number, in the hero, in Privacy and on the 404. |
| M5 | Numeral 520 px down at 834 | From 700 to 1099 the numeral sits to the right of the headline; the tab strip and caption follow the CTAs. |
| M6 | Rive sand loop 6 s at every interval | Not fixed in the file: animation speed is not bindable in the Rive format without moving the glass into a nested artboard, and a rebuilt file with a `period` property rendered identically at every value, so it was reverted. Instead the Rive renderer mounts only above 60 s, where both renderers use the idle loop; at 60 s or less (the default 30 s included) the SVG mark, whose sand follows the interval, is the one on screen. |
| m1 | Empty fourth row in Element Count | Three rows before the click, the fourth cuts in, panel height constant; asserted. |
| m2 | Dead half column beside the switches | Gone (see M2). Menu path segments no longer break mid-name. |
| m7 | No test for the brand link | time.mjs: from `/#privacy`, the brand returns to scrollY 0 and clears the hash, at 1440 and 390. |

Also changed: the hero poster no longer loads at high priority (it is below the fold on phones; mobile
performance 85 to 88).

### Still weak or unverified

- **The Rive mark is off screen at the default interval.** It is the honest state, but the Rive piece
  only shows at intervals above a minute. A nested-artboard rebuild with a bindable speed would bring
  it back everywhere.
- **Mobile Lighthouse performance is 88** (simulated LCP 3.8 s on the hero paragraph; fonts and the
  render-blocking stylesheet). Not chased further.
- **Sections three to seven keep the same rhythm** (title left, lede, demo). The header line and the
  ruler carry the idea through the page; How it works, Picker, Gmail and Herald were not recomposed.
- **Element Count** keeps its "3 items" label under the reserved slot, about 50 px below the list
  before the click.
- **The first-change chip** still covers the top of the hero numeral's bracket for its 8 s at 1440, and
  under 1100 it still waits for the first demo.
- **The recording is 1440 px wide**, so the frame is under 2x on retina at desktop widths.
- The hour ruler's ticks are arithmetic on the wall clock, not a log of this page's own checks; the
  sentence says "a watcher on this interval", which is what it shows.
- Not verified: real Safari and real touch devices (headless Chrome only), the Rive renderer's colours
  at 2x (file unchanged this round), the forge deploy path.
