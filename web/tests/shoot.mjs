// Headless screenshots of the landing page at the review widths. BASE env, default http://localhost:3201
import puppeteer from "puppeteer-core";
import { mkdirSync } from "node:fs";
const BASE = process.env.BASE || "http://localhost:3201";
const widths = (process.env.WIDTHS || "1440,1280,834,390").split(",").map(Number);
const out = new URL("../.screenshots/", import.meta.url).pathname;
mkdirSync(out, { recursive: true });
const browser = await puppeteer.launch({ executablePath: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome", headless: "new", args: ["--autoplay-policy=no-user-gesture-required"] });
for (const w of widths) {
  const page = await browser.newPage();
  await page.setViewport({ width: w, height: 900, deviceScaleFactor: 1 });
  await page.goto(BASE + (process.env.PATHNAME || "/"), { waitUntil: "networkidle2" });
  await new Promise((r) => setTimeout(r, 1500));
  const ids = (process.env.SECTIONS || "hero,how-it-works,picker,watch-types,gmail,herald,download").split(",");
  for (const id of ids) {
    const el = await page.$("#" + id);
    if (!el) continue;
    await el.scrollIntoView?.();
    await new Promise((r) => setTimeout(r, 250));
    await el.screenshot({ path: `${out}${process.env.PREFIX || "land"}-${id}-${w}.png` });
  }
  await page.close();
}
await browser.close();
