import puppeteer from "puppeteer-core";
import { BASE, T, sleep, ok } from "./_h.mjs";
const browser = await puppeteer.launch({ executablePath: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome", headless: "new" });
let fails = 0;
const chk = (c, m) => { ok(c, m); if (!c) fails++; };
// deferred Rive + scroll glance (fresh page, no mouse moves, touch viewport)
{
  console.log("--- deferred rive + scroll glance (390)");
  const page = await browser.newPage();
  await page.setViewport({ width: 390, height: 900, hasTouch: true });
  const t0 = [];
  page.on("request", (r) => { if (/rive/i.test(r.url())) t0.push([r.url(), Date.now()]); });
  await page.goto(BASE + "/", { waitUntil: "load", timeout: 90000 });
  await page.waitForSelector(T("watch-mark"), { timeout: 30000 });
  await page.waitForFunction(() => document.querySelector('[data-testid="watch-mark"]')?.dataset.renderer === "rive", { timeout: 5000 }).catch(() => {});
  chk((await page.$eval(T("watch-mark"), (e) => e.dataset.renderer)) === "rive", "renderer reaches rive within 5 s");
  // In-page clock (same timeline for both): resource startTime vs the navigation's loadEventStart.
  const tl = await page.evaluate(() => { const n = performance.getEntriesByType("navigation")[0]; return { load: n.loadEventStart, rive: performance.getEntriesByType("resource").filter((r) => /rive/i.test(r.name) && !/WatchMarkRive/.test(r.name)).map((r) => [r.name, r.startTime]) }; });
  const early = tl.rive.filter(([, t]) => t < tl.load);
  chk(t0.length > 0 && tl.rive.length > 0 && early.length === 0, `rive runtime/wasm/.riv requests start after load (load at ${Math.round(tl.load)} ms; ${tl.rive.map(([u, t]) => u.split("/").pop().slice(0, 28) + "@" + Math.round(t)).join(", ")})`);
  await page.waitForFunction(() => document.documentElement.scrollHeight > innerHeight + 700);
  await sleep(800);
  const ly = () => page.$eval(T("watch-mark"), (e) => parseFloat(e.dataset.lookY));
  const y0 = await ly();
  await page.evaluate(() => { window.__ly = []; const m = document.querySelector('[data-testid="watch-mark"]'); const t = performance.now(); const iv = setInterval(() => { window.__ly.push([Math.round(performance.now() - t), parseFloat(m.dataset.lookY), Math.round(scrollY)]); if (performance.now() - t > 1000) clearInterval(iv); }, 16); scrollTo(0, 600); });
  await sleep(300);
  const y1 = await page.evaluate(() => Math.max(...window.__ly.filter((s) => s[0] <= 300).map((s) => s[1])));
  console.log("  samples", JSON.stringify(await page.evaluate(() => window.__ly.filter((_, i) => i % 6 === 0).slice(0, 12))));
  chk(y1 > 0.3, `scroll down glances down within 300 ms (look-y ${y0} -> ${y1})`);
  await sleep(1200);
  const y2 = await ly();
  chk(Math.abs(y2) < 0.1, `look-y back under 0.1 after 1.2 s (${y2})`);
  await page.close();
}
for (const w of [1280, 390]) {
  console.log(`--- ${w}px`);
  const page = await browser.newPage();
  await page.setViewport({ width: w, height: 900, hasTouch: w < 500 });
  await page.goto(BASE + "/", { waitUntil: "networkidle2", timeout: 90000 });
  await page.waitForSelector(T("watch-mark"), { timeout: 30000 });
  chk(true, "mark exists");
  const label = await page.$eval(T("watch-mark"), (e) => e.getAttribute("aria-label"));
  chk(/WebWatcher is watching this page · 0 changes/.test(label), `aria-label: ${label}`);
  const box = await page.$eval(T("watch-mark"), (e) => { const r = e.getBoundingClientRect(); return [r.width, r.height, r.right <= innerWidth]; });
  chk(box[0] === 36 && box[1] === 36 && box[2], "36px and inside viewport");
  const hh = await page.$eval("header.site-header", (e) => e.getBoundingClientRect().height);
  chk(hh <= 77, `header height ${hh}`);
  const riveUp = await page.evaluate(async () => { try { const r = await fetch("/rive/watcher-mark.riv", { method: "HEAD" }); return r.ok && !(r.headers.get("content-type") || "").includes("text/html"); } catch { return false; } });
  if (riveUp) {
    await page.waitForFunction(() => document.querySelector('[data-testid="watch-mark"]')?.dataset.renderer === "rive", { timeout: 4000 }).catch(() => {});
    const rr = await page.$eval(T("watch-mark"), (e) => e.dataset.renderer);
    chk(rr === "rive", `renderer is rive (${rr})`);
    const cv = await page.$eval(`${T("watch-mark")} canvas`, (c) => [c.offsetWidth, c.offsetHeight]).catch(() => null);
    chk(!!cv && cv[0] === 36 && cv[1] === 36, `rive canvas 36x36 (${cv})`);
  } else console.log("SKIP rive checks: /rive/watcher-mark.riv unreachable");
  chk(!(await page.$(T("watch-badge"))), "no badge at 0");

  // iris follows the cursor
  const look = () => page.$eval(T("watch-mark"), (e) => [e.dataset.lookX, e.dataset.lookY].join(","));
  const irisT = () => page.$eval(T("watch-iris"), (e) => getComputedStyle(e).transform);
  await page.mouse.move(10, 600); await sleep(600);
  const a = await look(), ta = await irisT();
  await page.mouse.move(w - 10, 20); await sleep(600);
  const b = await look(), tb = await irisT();
  chk(Math.sign(parseFloat(a)) !== Math.sign(parseFloat(b)), `look-x changed sign ${a} -> ${b}`);
  chk(a !== b && ta !== tb, `iris moved ${a} (${ta}) -> ${b} (${tb})`);

  await page.evaluate(() => window.__ww_record({ source: "types", name: "Rive Community · bell", title: "Rive Community — 5 new", body: "Badge went 3 → 5", value: "5" }));
  await sleep(500);
  chk((await page.$eval(T("watch-badge"), (e) => e.textContent.trim())) === "1", "badge shows 1");
  chk((await page.$eval(T("watch-notice"), (e) => e.textContent)).includes("Rive Community — 5 new"), "notice appears with title");
  const nb = await page.$eval(T("watch-notice"), (e) => { const r = e.getBoundingClientRect(); return [r.top, r.right, r.left]; });
  chk(nb[0] >= 76 && nb[1] <= w, `notice below header, inside viewport (top ${nb[0]})`);
  chk((await page.$eval(T("watch-notice"), (e) => e.textContent)).includes("Your watcher in the menu bar noticed. Click it."), "first notice has the hint");
  const hs = await page.$eval(".ww-notice__hint", (e) => getComputedStyle(e).fontSize);
  chk(hs === "12px", `hint is 12px (${hs})`);
  if (w < 500) {
    const m = await page.evaluate(() => { const n = document.querySelector('[data-testid="watch-notice"]').getBoundingClientRect(); return [n.top, n.width, document.documentElement.scrollWidth, document.documentElement.clientWidth]; });
    chk(m[0] >= 83.5 && m[0] <= 90, `mobile notice top ${m[0]} (76 header + 8 gap)`);
    chk(m[1] <= w - 32 + 0.5, `mobile notice width ${m[1]} <= ${w - 32}`);
    chk(m[2] <= m[3], `no horizontal overflow with notice visible (${m[2]}/${m[3]})`);
  }
  await sleep(5300);
  chk(!(await page.$(T("watch-notice"))), "notice auto-dismissed");
  await page.evaluate(() => window.__ww_record({ source: "types", name: "Second", title: "Second change", body: "x", value: "2" }));
  await sleep(700);
  chk(!(await page.$eval(T("watch-notice"), (e) => e.textContent)).includes("menu bar noticed"), "later notice has no hint");
  await page.click(T("watch-mark")); await page.waitForSelector(T("watch-popover")); await sleep(500);
  chk(!(await page.$(T("watch-notice"))), "opening popover dismisses visible notice");
  const rowsH = await page.$$eval(".ww-pop__item", (r) => r.map((x) => x.getBoundingClientRect().height));
  chk(rowsH.every((h) => h >= 36), `popover rows >= 36px (${rowsH})`);
  chk((await page.$eval(T("watch-settings"), (e) => e.getAttribute("href"))).endsWith("/docs/settings"), "Settings links to /docs/settings");
  await page.click(T("watch-quit")); await sleep(500);
  chk(!(await page.$(T("watch-popover"))), "Quit closes popover");
  await page.click(T("watch-mark")); await page.waitForSelector(T("watch-popover")); await sleep(400);
  await page.click(T("watch-add")); await sleep(1200);
  chk(!(await page.$(T("watch-popover"))), "Add Watcher closes popover");
  const pt = await page.$eval("#picker", (e) => e.getBoundingClientRect().top);
  chk(Math.abs(pt) < 400, `scrolled to #picker (top ${Math.round(pt)})`);
  await page.evaluate(() => scrollTo(0, 0)); await sleep(500);

  await page.evaluate(() => window.__ww_record({ source: "gmail", name: "Acme invoices", title: "Acme — 3 unread", body: "latest Today", value: "3" }));
  await sleep(700);
  await page.click(T("watch-notice"));
  await page.waitForSelector(T("watch-popover"));
  await sleep(400);
  chk(!(await page.$(T("watch-notice"))), "click notice dismisses it and opens popover");
  await page.keyboard.press("Escape"); await sleep(400);
  chk(!(await page.$(T("watch-popover"))), "Escape closes (from notice-open)");

  await page.click(T("watch-mark"));
  await page.waitForSelector(T("watch-popover"));
  await sleep(400);
  const rows = await page.$$eval(T("watch-row"), (r) => r.map((x) => x.textContent));
  chk(rows.length === 3 && rows.some((t) => t.includes("Rive Community · bell")) && rows.some((t) => t.includes("Acme invoices")), `popover rows: ${rows.length}`);
  chk(!(await page.$(T("watch-badge"))), "badge cleared on open");
  const pb = await page.$eval(T("watch-popover"), (e) => { const r = e.getBoundingClientRect(); return [r.left, r.right, r.bottom]; });
  chk(pb[0] >= 0 && pb[1] <= w + 1 && pb[2] <= 900, "popover within viewport");
  await page.click(T("watch-check")); await sleep(300);
  chk(!!(await page.$(T("watch-popover"))), "Check All Now keeps popover and records nothing");
  chk((await page.$$(T("watch-row"))).length === 3, "no new rows from check");
  await page.keyboard.press("Escape"); await sleep(500);
  chk(!(await page.$(T("watch-popover"))), "Escape closes popover");
  chk(await page.$eval(T("watch-mark"), (e) => document.activeElement === e), "focus returned to mark");

  // outside click closes
  await page.click(T("watch-mark")); await page.waitForSelector(T("watch-popover"));
  await page.mouse.click(w / 2, 400); await sleep(500);
  chk(!(await page.$(T("watch-popover"))), "outside click closes");
  await page.close();
}
await browser.close();
process.exit(fails ? 1 : 0);
