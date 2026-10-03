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

Layers: `Idle` (sand 6 s -> flip 500 ms ease-out-quint, loop), `Pop`, `Blink`.
Check: `node check.mjs` (puppeteer-core, writes `build/web-check.png`). Quick frames: `./shot.sh name advance [--data=prop=value]`.
