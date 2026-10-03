import puppeteer from "puppeteer-core";
import { BASE, T, sleep, ok } from "./_h.mjs";
const browser = await puppeteer.launch({ executablePath: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome", headless: "new" });
let fails = 0;
const chk = (c, m) => { ok(c, m); if (!c) fails++; };
for (const w of [1440, 390]) {
  console.log(`--- ${w}`);
  const page = await browser.newPage();
  await page.setViewport({ width: w, height: 900, hasTouch: w < 500 });
  await page.goto(BASE + "/", { waitUntil: "networkidle2", timeout: 90000 });
  await page.waitForSelector(T("watch-mark"), { timeout: 30000 });
  const hh = await page.$eval("header.site-header", (e) => e.getBoundingClientRect().height);
  chk(Math.round(hh) === 64, `header ${hh}px`);
  const ic = await page.$eval(".site-header .brand img", (e) => { const r = e.getBoundingClientRect(); return [r.width, r.height]; });
  chk(ic[0] === 54 && ic[1] === 54, `brand icon ${ic}`);
  const bg = await page.$eval("header.site-header", (e) => getComputedStyle(e).backgroundColor);
  chk(bg !== "rgba(0, 0, 0, 0)" && !/^rgb\(2[0-9]{2}/.test(bg), `header graphite ${bg}`);
  const clk = await page.$eval(T("menubar-clock"), (e) => [e.textContent.trim(), getComputedStyle(e).display, e.title]);
  if (w > 480) {
    chk(/^[A-Z][a-z]{2} \d{1,2}:\d{2} [AP]M$/.test(clk[0]), `clock "${clk[0]}"`);
    chk(/Local time/.test(clk[2]), "clock title");
  } else chk(clk[1] === "none", "clock hidden at <= 480");
  {
    // chip: fresh page, first record
    const p2 = await browser.newPage();
    await p2.setViewport({ width: w, height: 900, hasTouch: w < 500 });
    await p2.goto(BASE + "/", { waitUntil: "networkidle2", timeout: 90000 });
    await p2.waitForSelector(T("watch-mark"), { timeout: 30000 });
    await p2.evaluate(() => window.__ww_record({ source: "types", name: "Chip", title: "Chip", body: "b" }));
    await p2.waitForSelector(T("watch-notice"), { timeout: 5000 });
    const g = await p2.evaluate(() => { const n = document.querySelector('[data-testid="watch-notice"]').getBoundingClientRect(); const h = document.querySelector("header.site-header").getBoundingClientRect(); const m = document.querySelector('[data-testid="watch-mark"]').getBoundingClientRect(); return { nt: n.top, hb: h.bottom, nr: n.right, mr: m.right, nl: n.left, w: innerWidth }; });
    chk(g.nt >= g.hb, `chip below header (top ${g.nt} >= ${g.hb})`);
    chk(g.nl >= 0 && g.nr <= g.w, "chip inside viewport");
    if (w > 480) chk(Math.abs(g.nr - g.mr) < 24, `chip right-aligned to mark (${g.nr} vs ${g.mr})`);
    await p2.screenshot({ path: `/private/tmp/claude-501/-Users-ivg-github-web-watcher/1b5c3420-5ad4-4c49-88f4-04aad1e374ed/scratchpad/W1/chip-${w}.png`, clip: { x: 0, y: 0, width: w, height: 260 } });
    await p2.close();
  }
  if (w > 480) {
    await page.evaluate(() => window.__ww_setInterval(15));
    await sleep(300);
    const per = await page.$eval(T("watch-mark"), (e) => e.style.getPropertyValue("--ww-period"));
    chk(per === "15s", `--ww-period ${per}`);
    await page.click(T("watch-mark"));
    await page.waitForSelector(T("watch-popover"));
    chk((await page.$eval(T("watch-interval"), (e) => e.textContent)) === "Checks every 15 seconds", "popover says Checks every 15 seconds");
    const last = () => page.$eval(T("watch-last"), (e) => e.textContent);
    let seen = [];
    let sawAged = false, flipped = false;
    for (let i = 0; i < 40 && !flipped; i++) {
      await sleep(500);
      const t = await last();
      if (seen[seen.length - 1] !== t) seen.push(t);
      const m = /(\d+) seconds ago/.exec(t);
      if (m && +m[1] >= 4) sawAged = true;
      if (sawAged && /just now/.test(t)) flipped = true;
    }
    chk(flipped, `periodic check within 16 s, live counter: ${seen.join(" | ")}`);
    const anims = await page.evaluate(() => document.getAnimations().length);
    chk(anims > 0, `animations running ${anims}`);
    await page.evaluate(() => window.__ww_record({ source: "hero", name: "T", title: "T", body: "b" }));
    await sleep(600);
    chk(/just now/.test(await page.$eval(T("watch-last"), (e) => e.textContent)), "record() triggers an immediate check");
  }
  await page.close();
}
await browser.close();
process.exit(fails ? 1 : 0);
