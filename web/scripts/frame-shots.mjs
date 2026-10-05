// Composites raw window captures (screencapture -l -o, 2x, alpha corners) onto a vivid diagonal gradient with a
// soft drop shadow and a consistent margin. Writes <name>@2x.png and <name>.png (1x) into public/shots.
//
//   node scripts/frame-shots.mjs <rawDir> [--out public/shots] [--margin 40]
//
// Gradients are parameterised per shot in GRADIENTS (angle in degrees, CSS-style: 135 = top-left to bottom-right).
import { readdirSync, mkdirSync } from "node:fs";
import { basename, extname, join, resolve } from "node:path";
import sharp from "sharp";

const GRADIENTS = {
  sunset: { angle: 150, stops: ["#f6b25c", "#ef7a6b", "#e0508a", "#b44fd0"] },
  ocean:  { angle: 140, stops: ["#37d0e6", "#3a8cf0", "#5a4de0", "#8a3fd6"] },
  forest: { angle: 150, stops: ["#c6e05a", "#4cc98a", "#1fa4b0", "#2f6fd8"] },
  berry:  { angle: 145, stops: ["#ff9a8b", "#ff5e8e", "#c23fcf", "#6a47e6"] },
  lagoon: { angle: 135, stops: ["#ffe27a", "#7be0a3", "#2ec6d6", "#3b82f6"] },
  ember:  { angle: 155, stops: ["#ffd166", "#ff8a4c", "#f0506e", "#a83fd0"] },
};
// shot name -> gradient preset (anything unlisted uses the default)
const PRESET = {
  popover: "sunset", "popover-dark": "berry", "popover-changed": "ember", "popover-changed-dark": "ocean",
  "popover-empty": "lagoon", "popover-empty-dark": "ocean",
  "add-watcher-page": "ocean", "add-watcher-element": "ocean", "add-watcher-confirm": "ocean", "add-watcher-gmail": "berry",
  "watcher-editor": "forest", "watcher-editor-dark": "ocean", "watcher-editor-advanced": "forest",
  "watcher-editor-badge": "lagoon", "watcher-editor-text-change": "forest", "watcher-editor-element-count": "ocean",
  "watcher-editor-element-exists": "sunset", "watcher-editor-element-disappears": "ember", "watcher-editor-anything-changes": "berry",
  "gmail-sender-editor": "berry", "gmail-sender-editor-dark": "ocean", "gmail-signin": "sunset",
  "settings-general": "lagoon", "settings-general-dark": "ocean", "settings-gmail": "berry", "settings-gmail-dark": "ocean",
  "settings-gmail-signin": "sunset", "settings-notifications": "ember", "settings-notifications-dark": "berry",
  permissions: "forest", "permissions-dark": "ocean", "settings-whole": "lagoon",
  "permission-notifications": "ember", "permission-automation": "sunset", notification: "sunset",
};
const DEFAULT_PRESET = "sunset";

const args = process.argv.slice(2);
const flag = (k, d) => { const i = args.indexOf(k); return i >= 0 ? args[i + 1] : d; };
const rawDir = resolve(args[0] ?? ".");
const outDir = resolve(flag("--out", "public/shots"));
const MARGIN_PT = Number(flag("--margin", 40)); // margin in pt for a normal-width window; narrow windows get ~9% of their width (so the frame stays "a little")
mkdirSync(outDir, { recursive: true });

function gradientSvg(w, h, { angle, stops }) {
  const a = ((angle - 90) * Math.PI) / 180; // CSS angle -> vector
  const cx = w / 2, cy = h / 2, len = Math.abs(w * Math.cos(a)) + Math.abs(h * Math.sin(a));
  const x1 = cx - (Math.cos(a) * len) / 2, y1 = cy - (Math.sin(a) * len) / 2;
  const x2 = cx + (Math.cos(a) * len) / 2, y2 = cy + (Math.sin(a) * len) / 2;
  const s = stops.map((c, i) => `<stop offset="${(i / (stops.length - 1)) * 100}%" stop-color="${c}"/>`).join("");
  return Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}"><defs><linearGradient id="g" gradientUnits="userSpaceOnUse" x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}">${s}</linearGradient></defs><rect width="${w}" height="${h}" fill="url(#g)"/></svg>`);
}

async function shadowOf(win, blur, opacity) {
  const { width, height } = await sharp(win).metadata();
  const alpha = await sharp(win).ensureAlpha().extractChannel(3).raw().toBuffer();
  const a = Buffer.alloc(width * height * 4, 0);
  for (let i = 0; i < width * height; i++) a[i * 4 + 3] = Math.round(alpha[i] * opacity);
  return sharp(a, { raw: { width, height, channels: 4 } }).blur(blur).png().toBuffer();
}

/** Frame `win` (PNG buffer, 2x) on a canvas. If `canvas` is given the window is scaled to fit inside it instead of sizing the canvas to the window. */
export async function frame(win, preset, canvas) {
  let { width: ww, height: wh } = await sharp(win).metadata();
  let W, H;
  if (canvas) {
    W = canvas.w; H = canvas.h;
    const scale = Math.min((W * 0.8) / ww, (H * canvas.fill) / wh);
    ww = Math.round(ww * scale); wh = Math.round(wh * scale);
    win = await sharp(win).resize(ww, wh, { kernel: "lanczos3" }).png().toBuffer();
  } else { const m = Math.min(MARGIN_PT, Math.round(ww / 2 * 0.09)) * 2; W = ww + m * 2; H = wh + m * 2; }
  const left = Math.round((W - ww) / 2), top = Math.round((H - wh) / 2);
  const pad = 80;
  const sh1 = await shadowOf(await sharp(win).extend({ top: pad, bottom: pad, left: pad, right: pad, background: { r: 0, g: 0, b: 0, alpha: 0 } }).png().toBuffer(), 28, 0.38);
  const sh2 = await shadowOf(await sharp(win).extend({ top: pad, bottom: pad, left: pad, right: pad, background: { r: 0, g: 0, b: 0, alpha: 0 } }).png().toBuffer(), 6, 0.3);
  // Place a shadow layer at (x, y) on the W x H canvas, cropping whatever overhangs the edges.
  const place = async (buf, x, y) => {
    const m = await sharp(buf).metadata();
    const cx = Math.max(0, -x), cy = Math.max(0, -y);
    const cw = Math.min(m.width - cx, W - Math.max(0, x)), ch = Math.min(m.height - cy, H - Math.max(0, y));
    const input = cx || cy || cw < m.width || ch < m.height ? await sharp(buf).extract({ left: cx, top: cy, width: cw, height: ch }).png().toBuffer() : buf;
    return { input, left: Math.max(0, x), top: Math.max(0, y) };
  };
  return sharp(gradientSvg(W, H, GRADIENTS[preset] ?? GRADIENTS[DEFAULT_PRESET]))
    .composite([
      await place(sh1, left - pad, top - pad + 22),
      await place(sh2, left - pad, top - pad + 6),
      { input: win, left, top },
    ])
    .png();
}

const save = async (img, name) => {
  const buf = await img.toBuffer();
  const { width, height } = await sharp(buf).metadata();
  await sharp(buf).png({ compressionLevel: 9 }).toFile(join(outDir, `${name}@2x.png`));
  await sharp(buf).resize(Math.round(width / 2), Math.round(height / 2), { kernel: "lanczos3" }).png({ compressionLevel: 9 }).toFile(join(outDir, `${name}.png`));
  console.log(`${name}: ${width}x${height} @2x, ${Math.round(width / 2)}x${Math.round(height / 2)} @1x`);
};

for (const f of readdirSync(rawDir).filter((f) => extname(f) === ".png").sort()) {
  const name = basename(f, ".png");
  const raw = join(rawDir, f);
  await save(await frame(raw, PRESET[name] ?? DEFAULT_PRESET), name);
  if (name === "popover" && args.includes("--hero")) await save(await frame(raw, "sunset", { w: 2400, h: 1800, fill: 0.86 }), "hero-poster");
}
