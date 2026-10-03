import puppeteer from "puppeteer-core";
import { BASE, T, sleep, ok, done } from "./_h.mjs";
const SHOTS = process.env.HERO_SHOT_DIR;
const browser = await puppeteer.launch({ executablePath: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome", headless: "new" });
const bail = async (e) => { console.error(e); await browser.close(); process.exit(1); };
process.on("uncaughtException", bail); process.on("unhandledRejection", bail);
const txt = (page, id) => page.$eval(T(id), (e) => e.textContent.trim());
const count = async (page) => Number((await txt(page, "mo-count")).replace(/\D/g, "").slice(1) || (await txt(page, "mo-count")).split("×")[1]);
const badge = async (page) => { try { return (await page.$eval(T("watch-badge"), (e) => e.textContent.trim())); } catch { return ""; } };
const red = (page) => page.$eval(T("mo-num"), (e) => { const c = getComputedStyle(e).color; return c; });
const open = async (w, h, reduce) => {
  const page = await browser.newPage();
  await page.setViewport({ width: w, height: h });
  if (reduce) await page.emulateMediaFeatures([{ name: "prefers-reduced-motion", value: "reduce" }]);
  await page.goto(BASE + "/", { waitUntil: "domcontentloaded", timeout: 90000 });
  await page.waitForSelector(T("mo"));
  return page;
};
try {
  for (const [w, h] of [[1440, 900], [390, 844]]) {
    console.log("-- " + w);
    const page = await open(w, h, false);
    await sleep(300);
    ok((await txt(page, "mo-num")) === "(0)" && (await txt(page, "mo-tab")).startsWith("(0)"), `${w}: before the moment the numeral and the tab read (0)`);
    ok(await page.$eval(T("hero-line2"), (e) => e.dataset.lit === "0"), `${w}: line 2 is muted before the moment`);
    ok((await page.$eval(T("hero-download"), (e) => e.getBoundingClientRect().bottom)) <= h, `${w}: the Download button is on the first screen`);
    if (SHOTS) await page.screenshot({ path: `${SHOTS}/moment-${w}-t300.png` });
    await sleep(3200);
    ok((await count(page)) === 5, `${w}: ⌘R counter reached ×5 within 3.5 s`);
    ok((await txt(page, "mo-tab")).startsWith("(1)"), `${w}: tab title is (1)`);
    ok((await txt(page, "mo-num")) === "(1)", `${w}: giant numeral is 1`);
    const col = await red(page), sig = await page.evaluate(() => { const d = document.createElement("i"); d.style.color = "var(--n-signal)"; document.body.append(d); const c = getComputedStyle(d).color; d.remove(); return c; });
    ok(col === sig, `${w}: numeral is --n-signal (${col})`);
    ok(await page.$eval(T("hero-line2"), (e) => e.dataset.lit === "1"), `${w}: headline line 2 is lit`);
    ok((await badge(page)) === "1", `${w}: header badge is 1`);
    ok(await page.$eval(T("mo-cap"), (e) => e.offsetParent !== null && getComputedStyle(e.parentElement).visibility === "visible"), `${w}: caption and Replay visible`);
    const cnt = await page.$eval(T("mo-count"), (e) => { const r = e.getBoundingClientRect(), t = document.querySelector('[data-testid="mo-tab"]').getBoundingClientRect(), s = document.querySelector(".mo__strip").getBoundingClientRect(), cs = getComputedStyle(e); return { fs: cs.fontSize, ff: cs.fontFamily, sameRow: Math.abs((r.top + r.bottom) / 2 - (t.top + t.bottom) / 2) < 14, right: s.right - r.right }; });
    ok(cnt.fs === "15px" && /mono/i.test(cnt.ff) && cnt.sameRow && cnt.right < 24, `${w}: ⌘R counter is 15px mono on the tab row, right side (${cnt.fs}, right gap ${Math.round(cnt.right)})`);
    await page.click(T("mo-reload")); await sleep(300);
    ok((await count(page)) === 6 && (await txt(page, "mo-tab")).startsWith("(1)"), `${w}: reload is live: ×6, tab still (1)`);
    await page.click(T("mo-replay"));
    await sleep(300);
    ok((await txt(page, "mo-num")) === "(0)" && (await badge(page)) === "1", `${w}: replay resets the numeral to (0)`);
    await sleep(3200);
    ok((await badge(page)) === "2" && (await txt(page, "mo-num")) === "(1)", `${w}: replay fires again, badge 2`);
    if (w === 1440) {
      const g = await page.evaluate(() => {
        const n = document.querySelector('[data-testid="mo-num"]').getBoundingClientRect(), s = document.querySelector(".mo__strip").getBoundingClientRect(), c = document.querySelector(".hero .container"), cr = c.getBoundingClientRect(), pad = parseFloat(getComputedStyle(c).paddingRight);
        return { numRight: n.right, strip: s.right, edge: cr.right - pad };
      });
      ok(Math.abs(g.strip - g.edge) < 2 && Math.abs(g.numRight - g.edge) < 16, `1440: numeral and strip right edges meet the container edge (num ${Math.round(g.numRight)}, strip ${Math.round(g.strip)}, edge ${Math.round(g.edge)})`);
    }
    if (w < 600) {
      const order = await page.evaluate(() => ["#hero-title", ".hero__lede", ".hero__cta", ".mo", ".hero__facts"].map((q) => document.querySelector(q).getBoundingClientRect().top));
      ok(order.every((v, i) => i === 0 || v > order[i - 1]), `390: order is headline, lede, CTAs, numeral+strip, facts (${order.map(Math.round)})`);
      ok(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), "390: no horizontal overflow");
    }
    if (SHOTS) await page.screenshot({ path: `${SHOTS}/moment-${w}-end.png` });
    await page.close();
  }
  console.log("-- reduced motion");
  const page = await open(1440, 900, true);
  await sleep(300);
  ok((await txt(page, "mo-num")) === "(1)" && (await txt(page, "mo-tab")).startsWith("(1)"), "reduced: end state at 300 ms (1)");
  ok(await page.$eval(T("hero-line2"), (e) => e.dataset.lit === "1"), "reduced: line 2 lit");
  ok((await badge(page)) === "1", "reduced: header badge 1");
  ok((await page.$$eval(".mo .roll__v.is-out", (e) => e.length)) === 0, "reduced: no rolling layers");
  await page.close();
} finally { await browser.close(); }
await done({ close() {} });
