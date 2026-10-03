// Interactive-state screenshots for review. usage: node tests/v3states.mjs <base> <outdir>
import puppeteer from "puppeteer-core";
const [base, out] = process.argv.slice(2);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const T = (id) => `[data-testid="${id}"]`;
const b = await puppeteer.launch({ executablePath: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome", headless: "new" });
try {
  for (const w of [1280, 1100, 834]) {
    const p = await b.newPage(); await p.setViewport({ width: w, height: 900 });
    await p.goto(base + "/", { waitUntil: "networkidle2" }); await sleep(3400);
    await p.screenshot({ path: `${out}/st-fold-${w}.png` }); await p.close();
  }
  const p = await b.newPage(); await p.setViewport({ width: 1440, height: 900 });
  await p.goto(base + "/", { waitUntil: "domcontentloaded" }); await sleep(700);
  await p.screenshot({ path: `${out}/st-hero-pre.png` });
  await sleep(9000); // chip gone
  const badge = () => p.$eval(T("watch-badge"), (e) => e.textContent.trim()).catch(() => "0");
  const go = async (sel) => { await p.$eval(sel, (e) => window.scrollTo({ top: e.getBoundingClientRect().top + scrollY - 64, behavior: "instant" })); await sleep(700); };
  await go("#watch-types");
  const b0 = await badge(); await p.click(T("wt-row-badge")); await sleep(1200); const b1 = await badge();
  await p.click(T("wt-row-text")); await sleep(1200); const b2 = await badge();
  console.log("badge per click:", b0, b1, b2);
  await p.screenshot({ path: `${out}/st-wall.png` });
  await p.evaluate(() => scrollBy(0, 420)); await sleep(400); await p.screenshot({ path: `${out}/st-wall2.png` });
  await p.click(T("watch-mark")); await sleep(500); await p.screenshot({ path: `${out}/st-popover.png` }); await p.keyboard.press("Escape");
  await go("#privacy"); await p.evaluate(() => scrollBy(0, 520)); for (const i of [1, 2, 3]) await p.click(T(`pv-switch-${i}`)); await sleep(500);
  await p.screenshot({ path: `${out}/st-privacy.png` });
  await go("#gmail"); await p.evaluate(() => scrollBy(0, 640)); await sleep(2500); await p.screenshot({ path: `${out}/st-gmailfig.png` });
  await go("#hero"); await p.evaluate(() => scrollBy(0, 700)); await sleep(500); await p.screenshot({ path: `${out}/st-video.png` });
  await p.close();
} finally { await b.close(); }
