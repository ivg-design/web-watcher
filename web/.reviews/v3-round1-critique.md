# v3 round one — lead critique (as the owner would judge it)

Build reviewed: `gmail` after the worker pass, `next build && next start -p 3283`, headless Chrome at
1440×900, 1280, 1100, 834 and 390×844; every section and the interactive states (pre-moment, moment,
wall after two clicks, popover open, privacy all on, recording row, capture figure).

## Slop test
Pass. The fold is a condensed headline, a 340 px light extended `(0)` that becomes a red `(1)`, a
native-scale Safari tab that reloads five times, and a menu bar with a real clock. No blob, no card
grid, no eyebrow, no gradient outside a capture. The one thing a stranger could point at is "dark page,
one red": it is excused because the red only ever appears where the product shows red (badges, the
moment, a fired panel) and the UI accent is bone.

## What works
1. The moment reads in one pass: grey second line and grey `(0)` at t = 0.3 s, five ticks of `⌘R`,
   then three things change at once (tab, numeral, menu-bar badge) and the line lights. It is the
   product, not a metaphor for it.
2. The page keeps time for real: clock, 30 s checks, "Checks every … / Last check …" in the popover,
   and the interval list rewrites the arithmetic and the header's period.
3. The wall replaced the weakest v2 section with the strongest v3 one after the fold: six specimens
   at 160 px+, hairline wall, the real notification landing inside the panel that fired.
4. Night → day lands: the paper Download band after ten dark screens is a physical change of light.

## Issues found and fixed in this round
| # | Issue | Fix |
|---|---|---|
| 1 | The one-time chip sat inside the header over the nav links at 1440 | Anchored under the mark with a pointer; cuts in and out |
| 2 | On stacked layouts (< 1100) that chip covered the headline during the moment | The hero's record only ticks the badge there; the chip waits for the first demo |
| 3 | Header: nav wrapped and the Download button clipped at 1100–1359 | nowrap nav, 22 px gap, clock and GitHub link from 1360 |
| 4 | Headline broke into three lines at 1100–1279 | 8.4vw in that range, lines never wrap |
| 5 | Interval band: chips floating right, rows top-aligned, body copy orphaned under a second hairline | One composition: sentence + body left, a seven-row mono list right |
| 6 | App icon rendered ~30 px inside a 54 px box (transparent padding in the PNG) | Cropped tile icon in header, footer, download box and every notification mock |
| 7 | Em dashes and middle-dot chains in chip, Herald captions and changelog summaries | Sentences |
| 8 | The recording paused itself while the page scrolled to it | Pause only after the frame has been on screen during that playback |
| 9 | Lighthouse accessibility 94: mock greys under 4.5:1, an `h4` inside a mock, label/name mismatch on the wall buttons | Fixed in the quality pass (see the report) |
| 10 | Default Next 404 | "(0) Nothing to watch here." in the page's own terms |

## Residual weak points, in order
1. **The Rive mark does not adopt the interval.** The SVG renderer's sand loop follows `--ww-period`;
   the Rive renderer keeps its 6 s loop (no period property in the view model). The popover carries
   the truth either way. A `period` number in the VM would close it.
2. **Privacy is the quietest section.** The diagram is honest and legible but it is boxes and
   hairlines; it has one stepping dot. It does not need more, but it is where the energy is lowest.
3. **The recording has no voice-over** (file is silent; the sound control is there for when it has).
4. **Hero at 834** stacks headline, copy, CTAs, then the numeral: correct, but the numeral is below
   the first screen's centre of gravity; the two-column fold only exists from 1100.
5. **Docs keep the v2 light theme and blue accent.** Deliberate (readability, the owner's docs rules),
   but the header there is light while the landing's is the dark menu bar.
6. **Element Count specimen** reserves a blank fourth row before the click.
