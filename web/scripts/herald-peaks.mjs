// Decodes the Herald voice samples and writes their amplitude envelope (one peak per 40 ms) to
// src/components/landing/herald/peaks.json. Needs ffmpeg on PATH; the site build does not.
import { execFileSync } from "node:child_process";
import { writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const RATE = 8000;
const WIN = Math.round(RATE * 0.04);
const FILES = ["herald-email-3", "herald-email-4", "herald-contra"];
const out = {};
for (const name of FILES) {
  const pcm = execFileSync(
    "ffmpeg",
    ["-v", "error", "-i", path.join(root, "public/audio", name + ".mp3"), "-f", "s16le", "-ac", "1", "-ar", String(RATE), "pipe:1"],
    { maxBuffer: 1 << 28 },
  );
  const n = Math.floor(pcm.length / 2);
  const raw = [];
  for (let s = 0; s < n; s += WIN) {
    let m = 0;
    for (let i = s; i < Math.min(n, s + WIN); i++) m = Math.max(m, Math.abs(pcm.readInt16LE(i * 2)));
    raw.push(m);
  }
  const top = Math.max(...raw, 1);
  out[name] = { dur: Math.round((n / RATE) * 100) / 100, peaks: raw.map((v) => Math.round((v / top) * 100) / 100) };
}
writeFileSync(path.join(root, "src/components/landing/herald/peaks.json"), JSON.stringify(out) + "\n");
for (const k of FILES) console.log(k, out[k].dur + " s", out[k].peaks.length + " windows");
