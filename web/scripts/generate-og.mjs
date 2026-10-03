// Regenerates public/og.png (1200x630) from the live hero at the moment state. Not part of the build:
// `BASE=http://localhost:3283 npm run og` against a running production build.
import puppeteer from "puppeteer-core";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const out = join(dirname(fileURLToPath(import.meta.url)), "..", "public", "og.png");
const BASE = process.env.BASE || "http://localhost:3283";
const browser = await puppeteer.launch({ executablePath: process.env.CHROME_BIN ?? "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome", headless: "new" });
try {
  const page = await browser.newPage();
  await page.setViewport({ width: 1200, height: 630, deviceScaleFactor: 1 });
  await page.goto(BASE + "/", { waitUntil: "networkidle2", timeout: 90000 });
  await new Promise((r) => setTimeout(r, 3600));
  // The card shows the headline, the numeral and the tab: hide the one-time chip and the lede/CTA rows that would crop.
  await page.addStyleTag({ content: ".ww-notices{display:none!important}.nav,.gh-link,.site-header__end .btn{visibility:hidden}" });
  await page.screenshot({ path: out, clip: { x: 0, y: 0, width: 1200, height: 630 } });
  console.log("wrote", out);
} finally { await browser.close(); }
