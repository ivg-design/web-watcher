import puppeteer from "puppeteer-core";
import { BASE, T, sleep, ok } from "./_h.mjs";
const browser = await puppeteer.launch({ executablePath: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome", headless: "new" });
let fails = 0;
const chk = (c, m) => { ok(c, m); if (!c) fails++; };
const riveReqs = (reqs) => reqs.filter((u) => /rive/i.test(u) && !/WatchMarkRive/.test(u));
const extHosts = (reqs) => reqs.filter((u) => /unpkg\.com|jsdelivr/.test(u));
// gated Rive: nothing loads until the first interaction; wasm is self-hosted (desktop, 1280)
{
  console.log("--- gated rive (1280)");
  const page = await browser.newPage();
  await page.setViewport({ width: 1280, height: 900 });
  const reqs = [];
  page.on("request", (r) => reqs.push(r.url()));
  await page.goto(BASE + "/", { waitUntil: "load", timeout: 90000 });
  await page.waitForSelector(T("watch-mark"), { timeout: 30000 });
  await sleep(3000);
  chk((await page.$eval(T("watch-mark"), (e) => e.dataset.renderer)) === "svg", "renderer stays svg with no interaction");
  chk(riveReqs(reqs).length === 0, `no rive/wasm request before first interaction (${riveReqs(reqs).length})`);
  const mark0 = reqs.length;
  await page.mouse.move(300, 300);
  await page.waitForFunction(() => document.querySelector('[data-testid="watch-mark"]')?.dataset.renderer === "rive", { timeout: 8000 }).catch(() => {});
  chk((await page.$eval(T("watch-mark"), (e) => e.dataset.renderer)) === "rive", "renderer reaches rive after first pointermove");
  const after = reqs.slice(mark0);
  chk(riveReqs(after).some((u) => /\/rive\/rive\.wasm/.test(u)), "wasm is self-hosted at /rive/rive.wasm");
  chk(extHosts(reqs).length === 0, `no unpkg/jsdelivr request (${extHosts(reqs).join(",")})`);
  await page.close();
}
// reduced motion: Rive never loads
{
  console.log("--- reduced motion: no rive");
  const page = await browser.newPage();
  await page.emulateMediaFeatures([{ name: "prefers-reduced-motion", value: "reduce" }]);
  await page.setViewport({ width: 1280, height: 900 });
  const reqs = [];
  page.on("request", (r) => reqs.push(r.url()));
  await page.goto(BASE + "/", { waitUntil: "load", timeout: 90000 });
  await page.waitForSelector(T("watch-mark"), { timeout: 30000 });
  await page.mouse.move(300, 300); await page.keyboard.press("Shift");
  await sleep(3000);
  chk((await page.$eval(T("watch-mark"), (e) => e.dataset.renderer)) === "svg", "reduced motion keeps the svg renderer");
  chk(riveReqs(reqs).length === 0, `no rive request under reduced motion (${riveReqs(reqs).length})`);
  await page.close();
}
// touch viewport: coarse pointer under 640 never loads Rive; scroll glance still works on the svg
{
  console.log("--- touch 390: scroll glance");
  const page = await browser.newPage();
  await page.setViewport({ width: 390, height: 900, hasTouch: true });
  const reqs = [];
  page.on("request", (r) => reqs.push(r.url()));
  await page.goto(BASE + "/", { waitUntil: "load", timeout: 90000 });
  await page.waitForSelector(T("watch-mark"), { timeout: 30000 });
  const coarse = await page.evaluate(() => matchMedia("(pointer: coarse)").matches);
  await page.waitForFunction(() => document.documentElement.scrollHeight > innerHeight + 700);
  await sleep(800);
  const ly = () => page.$eval(T("watch-mark"), (e) => parseFloat(e.dataset.lookY));
  const y0 = await ly();
  await page.evaluate(() => { window.__ly = []; const m = document.querySelector('[data-testid="watch-mark"]'); const t = performance.now(); const iv = setInterval(() => { window.__ly.push([Math.round(performance.now() - t), parseFloat(m.dataset.lookY), Math.round(scrollY)]); if (performance.now() - t > 1000) clearInterval(iv); }, 16); scrollTo(0, 600); });
  await sleep(300);
  const y1 = await page.evaluate(() => Math.max(...window.__ly.filter((s) => s[0] <= 300).map((s) => s[1])));
  chk(y1 > 0.3, `scroll down glances down within 300 ms (look-y ${y0} -> ${y1})`);
  await sleep(1200);
  const y2 = await ly();
  chk(Math.abs(y2) < 0.1, `look-y back under 0.1 after 1.2 s (${y2})`);
  if (coarse) {
    await sleep(1500);
    chk((await page.$eval(T("watch-mark"), (e) => e.dataset.renderer)) === "svg", "coarse pointer under 640 keeps svg");
    chk(riveReqs(reqs).length === 0, `no rive request on coarse 390 (${riveReqs(reqs).length})`);
    const hit = await page.$eval(T("watch-mark"), (e) => { const r = e.getBoundingClientRect(); const cs = getComputedStyle(e, "::after"); return [r.width, parseFloat(cs.width) || 0, cs.position]; });
    chk(hit[1] >= 44 && hit[2] === "absolute", `touch hit area >= 44 (${hit[1]})`);
  } else console.log("SKIP coarse-pointer checks: emulation reports pointer: fine");
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
  const gated = await page.evaluate(() => matchMedia("(pointer: coarse)").matches && innerWidth < 640);
  if (riveUp && !gated) {
    await page.mouse.move(40, 300);
    await page.waitForFunction(() => document.querySelector('[data-testid="watch-mark"]')?.dataset.renderer === "rive", { timeout: 8000 }).catch(() => {});
    const rr = await page.$eval(T("watch-mark"), (e) => e.dataset.renderer);
    chk(rr === "rive", `renderer is rive (${rr})`);
    const cv = await page.$eval(`${T("watch-mark")} canvas`, (c) => [c.offsetWidth, c.offsetHeight]).catch(() => null);
    chk(!!cv && cv[0] === 36 && cv[1] === 36, `rive canvas 36x36 (${cv})`);
  } else console.log("SKIP rive checks: .riv unreachable or Rive gated off for touch");
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
  const ntxt = await page.$eval(T("watch-notice"), (e) => e.textContent);
  chk(ntxt.includes("Rive Community — 5 new"), "callout appears with the change title");
  chk(ntxt.includes("Logged in your menu bar — click it."), "callout carries the menu-bar line");
  const hs = await page.$eval(".ww-notice__hint--l", (e) => getComputedStyle(e).fontSize);
  chk(hs === "12px", `hint is 12px (${hs})`);
  const g = await page.evaluate(() => {
    const n = document.querySelector('[data-testid="watch-notice"]').getBoundingClientRect();
    const m = document.querySelector('[data-testid="watch-mark"]').getBoundingClientRect();
    const h = document.querySelector("header")?.getBoundingClientRect() ?? { top: 0, bottom: 76 };
    const b = document.querySelector(".site-header .brand img")?.getBoundingClientRect() ?? { right: 0 };
    return { nt: n.top, nb: n.bottom, nr: n.right, nl: n.left, nw: n.width, mt: m.top, mb: m.bottom, ml: m.left, ht: h.top, hb: h.bottom, br: b.right, sw: document.documentElement.scrollWidth, cw: document.documentElement.clientWidth };
  });
  chk(g.nt >= g.ht - 0.5 && g.nb <= g.hb + 0.5, `chip stays inside the header (${Math.round(g.nt)}..${Math.round(g.nb)} in ${Math.round(g.ht)}..${Math.round(g.hb)})`);
  chk(Math.abs((g.nt + g.nb) / 2 - (g.mt + g.mb) / 2) <= 2, "chip is vertically centred on the mark");
  chk(g.nr <= g.ml && g.ml - g.nr <= 14, `chip ends just left of the mark (gap ${Math.round(g.ml - g.nr)})`);
  chk(g.nl >= g.br + 4, `chip never covers the app icon (${Math.round(g.nl)} > ${Math.round(g.br)})`);
  chk(g.sw <= g.cw, `no horizontal overflow with chip visible (${g.sw}/${g.cw})`);
  const t1 = Date.now();
  await page.waitForFunction(() => !document.querySelector('[data-testid="watch-notice"]'), { timeout: 9000 }).catch(() => {});
  chk(!(await page.$(T("watch-notice"))) && Date.now() - t1 < 8000, "callout auto-dismissed (~6 s)");
  await page.evaluate(() => window.__ww_record({ source: "types", name: "Second", title: "Second change", body: "x", value: "2" }));
  await sleep(700);
  chk(!(await page.$(T("watch-notice"))), "second record() shows NO callout");
  chk((await page.$eval(T("watch-badge"), (e) => e.textContent.trim())) === "2", "badge still ticks to 2");
  await page.click(T("watch-mark")); await page.waitForSelector(T("watch-popover")); await sleep(500);
  chk(!(await page.$(T("watch-notice"))), "no callout over the open popover");
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
  await page.evaluate(() => window.__ww_record({ source: "gmail", name: "Beta receipts", title: "Beta — 4 unread", body: "latest Today", value: "4" }));
  await sleep(700);
  chk(!(await page.$(T("watch-notice"))), "later records never show a callout");

  await page.click(T("watch-mark"));
  await page.waitForSelector(T("watch-popover"));
  await sleep(400);
  const rows = await page.$$eval(T("watch-row"), (r) => r.map((x) => x.textContent));
  chk(rows.length === 3 && rows.some((t) => t.includes("Rive Community · bell")) && rows.some((t) => t.includes("Second")), `coalesced rows: ${rows.length}`);
  chk(rows.filter((t) => t.includes("Gmail · @rive.app")).length === 1, "Gmail collapses into one sender row");
  chk(!(await page.$(T("watch-badge"))), "badge cleared on open");
  await page.evaluate(() => window.__ww_record({ source: "gmail", name: "Gamma alerts", title: "Gamma — 7 unread", body: "latest Today", value: "7" }));
  await sleep(400);
  const rows7 = await page.$$eval(T("watch-row"), (es) => es.map((e) => e.textContent));
  const gm = rows7.find((t) => t.includes("Gmail · @rive.app")) || "";
  chk(gm.includes("Last: 7") && gm.includes("just now"), `Gmail row shows the latest value, "Last: 7 · just now" (${gm})`);
  chk(/7/.test(await page.$eval(`${T("watch-row")} .ww-pop__count, ${T("watch-row")}:last-child .ww-pop__count`, (e) => e.textContent)), "Gmail count is the latest value (7)");
  const pb = await page.$eval(T("watch-popover"), (e) => { const r = e.getBoundingClientRect(); return [r.left, r.right, r.bottom]; });
  chk(pb[0] >= 0 && pb[1] <= w + 1 && pb[2] <= 900, "popover within viewport");
  await page.evaluate(() => window.__ww_record({ source: "types", name: "Rive Community · bell", title: "Rive Community — 7 new", body: "Badge went 5 → 7", value: "7" }));
  await sleep(500);
  const live = await page.$$eval(T("watch-row"), (r) => r.map((x) => x.textContent));
  chk(live.length === 3 && live[0].includes("Rive Community · bell") && live[0].includes("Last: 7"), `same watcher updates in place and moves first (${live.length}: ${live[0]})`);
  chk(await page.$eval(`${T("watch-row")} .ww-pop__val`, (e) => e.classList.contains("is-roll")) || (await page.$eval(T("watch-mark"), (e) => e.dataset.reduced)) === "1", "changed value rolls");
  await page.click(T("watch-check")); await sleep(300);
  chk(!!(await page.$(T("watch-popover"))), "Check All Now keeps popover and records nothing");
  chk((await page.$$(T("watch-row"))).length === 3, "no new rows from check");
  await page.keyboard.press("Escape"); await sleep(500);
  chk(!(await page.$(T("watch-popover"))), "Escape closes popover");
  chk(await page.$eval(T("watch-mark"), (e) => document.activeElement === e), "focus returned to mark");

  // one-time callout interactions on a fresh page load
  {
    const p2 = await browser.newPage();
    await p2.setViewport({ width: w, height: 900, hasTouch: w < 500 });
    await p2.goto(BASE + "/", { waitUntil: "networkidle2", timeout: 90000 });
    await p2.waitForSelector(T("watch-mark"), { timeout: 30000 });
    await p2.evaluate(() => window.__ww_record({ source: "steps", name: "Contra · inbox", title: "Contra — noticed", body: "Inbox (1)", value: "1" }));
    await p2.waitForSelector(T("watch-notice"), { timeout: 3000 });
    await sleep(300);
    // hover pauses the auto-dismiss
    if (w >= 500) {
      await p2.hover(T("watch-notice"));
      await sleep(7000);
      chk(!!(await p2.$(T("watch-notice"))), "callout pauses while hovered");
      await p2.mouse.move(5, 500);
      await p2.waitForFunction(() => !document.querySelector('[data-testid="watch-notice"]'), { timeout: 9000 }).catch(() => {});
      chk(!(await p2.$(T("watch-notice"))), "callout dismisses after hover ends");
      await p2.reload({ waitUntil: "networkidle2" });
      await p2.waitForSelector(T("watch-mark"));
      await p2.evaluate(() => window.__ww_record({ source: "steps", name: "Contra · inbox", title: "Contra — noticed", body: "Inbox (1)", value: "1" }));
      await p2.waitForSelector(T("watch-notice"), { timeout: 3000 });
      await sleep(300);
    }
    await p2.click(T("watch-notice"));
    await p2.waitForSelector(T("watch-popover"), { timeout: 3000 });
    await sleep(400);
    chk(!(await p2.$(T("watch-notice"))), "click callout dismisses it and opens popover");
    await p2.keyboard.press("Escape"); await sleep(400);
    await p2.evaluate(() => window.__ww_record({ source: "steps", name: "x", title: "x", body: "x" }));
    await sleep(600);
    chk(!(await p2.$(T("watch-notice"))), "no second callout after the first was used");
    await p2.reload({ waitUntil: "networkidle2" });
    await p2.waitForSelector(T("watch-mark"));
    await p2.evaluate(() => window.__ww_record({ source: "steps", name: "y", title: "y", body: "y" }));
    await p2.waitForSelector(T("watch-notice"), { timeout: 3000 });
    await p2.click(T("watch-mark")); await p2.waitForSelector(T("watch-popover")); await sleep(400);
    chk(!(await p2.$(T("watch-notice"))), "opening the popover dismisses a visible callout");
    await p2.close();
  }

  // outside click closes
  await page.click(T("watch-mark")); await page.waitForSelector(T("watch-popover"));
  await page.mouse.click(w / 2, 400); await sleep(500);
  chk(!(await page.$(T("watch-popover"))), "outside click closes");
  await page.close();
}
await browser.close();
process.exit(fails ? 1 : 0);
