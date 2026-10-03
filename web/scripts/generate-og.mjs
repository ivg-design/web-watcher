// Regenerates public/og.png (1200x630) with headless Chrome. Not part of the build: run `npm run og`.
import { execFileSync } from "node:child_process";
import { readFileSync, writeFileSync, mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const b64 = (p) => readFileSync(join(root, p)).toString("base64");
const CHROME = process.env.CHROME_BIN ?? "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";

const bricolage = b64("node_modules/@fontsource/bricolage-grotesque/files/bricolage-grotesque-latin-800-normal.woff2");
const albert = b64("node_modules/@fontsource/albert-sans/files/albert-sans-latin-600-normal.woff2");
const icon = b64("public/images/webwatcher-icon.png");

const html = `<!doctype html><meta charset="utf-8"><style>
@font-face{font-family:B;font-weight:800;src:url(data:font/woff2;base64,${bricolage}) format("woff2")}
@font-face{font-family:A;font-weight:600;src:url(data:font/woff2;base64,${albert}) format("woff2")}
*{margin:0;box-sizing:border-box}
html,body{width:1200px;height:630px;overflow:hidden}
body{background:#F4F5FA;position:relative;font-family:A,sans-serif}
.icon{position:absolute;left:96px;top:92px;width:112px;height:112px;border-radius:26px;box-shadow:0 18px 36px -14px rgba(20,22,28,.35)}
h1{position:absolute;left:92px;top:232px;font-family:B,sans-serif;font-weight:800;font-size:128px;line-height:1.02;letter-spacing:-0.045em;color:#14161C}
h1 span{display:block;color:#1F5EFF}
p{position:absolute;left:96px;bottom:72px;font-size:32px;font-weight:600;color:#5b6174;letter-spacing:-0.01em}
p b{color:#14161C;font-weight:600}
.bar{position:absolute;right:0;top:0;bottom:0;width:28px;background:#1F5EFF}
</style><img class="icon" src="data:image/png;base64,${icon}">
<h1>Stop refreshing.<span>Start knowing.</span></h1>
<p><b>WebWatcher</b> · Free macOS menu bar app</p><div class="bar"></div>`;

const dir = mkdtempSync(join(tmpdir(), "og-"));
const file = join(dir, "og.html");
writeFileSync(file, html);
const out = join(root, "public/og.png");
try {
  execFileSync(CHROME, [
    "--headless=new", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=1",
    "--window-size=1200,630", "--virtual-time-budget=2000",
    `--user-data-dir=${join(dir, "profile")}`, `--screenshot=${out}`, `file://${file}`,
  ], { stdio: "ignore", timeout: 25000, killSignal: "SIGKILL" });
} catch (e) {
  // Chrome may hang after writing the screenshot; the timeout kill is fine if the file exists.
  if (e?.code !== "ETIMEDOUT") throw e;
} finally {
  rmSync(dir, { recursive: true, force: true });
  console.log("wrote", out);
}
