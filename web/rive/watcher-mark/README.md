# Watcher mark (Rive)

Artboard `Mark` (48x48, transparent), state machine `Mark`, view model `Mark` (default instance `Default`, exported).
Build: `rive . --once` (no scripts, so no signing needed) then copy `build/watcher-mark.riv` to `public/rive/watcher-mark.riv`.
Note: `--publish` output is watermarked until the project is bound with `rive push`; ship the `--once` build.

| Property | Type | Range / meaning |
|---|---|---|
| `lookX` | number | -1..1, iris x, maps to +-4 px (clamped) |
| `lookY` | number | -1..1, iris y, maps to +-3 px (clamped) |
| `badge` | number | count; >0 shows the capsule (opacity = clamp(badge,0,1)) |
| `hover` | boolean | true >= 3 s -> blink, then every 4 s. Also written by the file's own pointer enter/exit listeners |
| `reduced` | boolean | true stops the sand/flip loop on a static frame |
| `tick` | trigger | flips the glass immediately and pops the eye + capsule |
| `sand` | number | 0..1, progress of the current check. Bound through range mappers to the upper sand's height (13 to 0), the pile's height (0 to 22) and the stream's length (17.5 to 6.5). The page writes it ten times a second, so the glass drains over the real interval |
| `turn` | trigger | flips the glass without the pop (the page's 6.5 s idle loop at intervals above a minute) |

Layers: `Idle` (run -> flip 500 ms ease-out-quint on `tick` or `turn` -> run; the sand has no timeline, see `sand`), `Pop`, `Blink`.
No Luau: local builds carry unsigned scripts and web runtimes reject those, so the sand is data binding only. Never `rive push`.
Check: `node check.mjs` (puppeteer-core, writes `build/web-check.png`). Quick frames: `./shot.sh name advance [--data=prop=value]`.
