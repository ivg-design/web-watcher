import puppeteer from "puppeteer-core";
import { T, sleep } from "./_h.mjs";
const SHOT = "/private/tmp/claude-501/-Users-ivg-github-web-watcher/1b5c3420-5ad4-4c49-88f4-04aad1e374ed/scratchpad/w6/";
let fails = 0;
const ok = (c, m) => { console.log((c ? "PASS " : "FAIL ") + m); if (!c) fails++; };
const BASE = process.env.BASE || "http://localhost:3101";
const SEL = "#herald *";
const browser = await puppeteer.launch({ executablePath: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome", headless: "new" });
const has = async (p, id) => !!(await p.$(T(id)));
const click = async (p, id) => { await p.$eval(T(id), (e) => e.scrollIntoView({ block: "center" })); await p.$eval(T(id), (e) => e.click()); };

async function run(w, h) {
  console.log(`--- ${w}x${h}`);
  const page = await browser.newPage();
  await page.evaluateOnNewDocument(() => {
    window.__played = [];
    window.__ctor = 0;
    const A = window.Audio;
    window.Audio = function () { window.__ctor++; return new A(); };
    HTMLMediaElement.prototype.play = function () { window.__played.push(this.src); return Promise.resolve(); };
    HTMLMediaElement.prototype.pause = function () {};
  });
  await page.setViewport({ width: w, height: h });
  await page.goto(BASE + "/", { waitUntil: "networkidle2", timeout: 90000 });
  ok(!(await has(page, "hb-banner")), "no banner before the stage is in view");
  await page.$eval("#herald .hx", (e) => e.scrollIntoView({ block: "center" }));
  await page.waitForSelector(T("hb-banner"), { timeout: 5000 });
  ok(true, "banner enters on view");
  ok((await page.evaluate(() => window.__ctor)) === 0 && (await page.evaluate(() => window.__played.length)) === 0, "no Audio created and nothing played on load");
  ok(await page.evaluate(() => !document.querySelector("#herald").innerHTML.includes("speechSynthesis")), "no speech synthesis in the section");
  ok(await page.evaluate(() => [...document.querySelectorAll("audio")].every((a) => a.paused) && window.__played.length === 0), "audio paused after load");
  await page.hover(T("hb-speak")); await sleep(300);
  ok(await page.evaluate(() => window.__ctor === 0 && window.__played.length === 0), "audio still paused after hovering the speaker");
  ok(await page.evaluate(() => { const n = document.querySelector("#herald"); const cs = getComputedStyle(n); return cs.borderTopWidth === "1px" && n.getBoundingClientRect().width >= innerWidth - 20 && document.querySelector("#herald h2").className.includes("h2-v3") && !n.querySelector(".eyebrow") && !!n.querySelector(".herald__head img"); }), "full-bleed hairline band, h2-v3 with inline logo, no eyebrow");
  ok(await page.evaluate(() => { const a = document.querySelector('[data-testid="herald-get"]'); return a.textContent.trim() === "Get Herald" && !!document.querySelector(".herald__free") && getComputedStyle(a).whiteSpace === "nowrap"; }), "CTA 'Get Herald' + mono free tag");
  await sleep(500);
  const t = await page.$eval(T("hb-banner"), (e) => e.textContent);
  ok(t.includes("3 new from Rive team") && t.includes("WebWatcher · Email") && t.includes("now") && t.includes("Scripting update · Office hours · Release notes"), "banner content");
  const g = await page.evaluate(() => {
    const b = document.querySelector('[data-testid="hb-banner"]').getBoundingClientRect();
    const s = document.querySelector(".hx").getBoundingClientRect();
    return { bl: b.left, br: b.right, bb: b.bottom, sl: s.left, sr: s.right, sb: s.bottom, sw: document.documentElement.scrollWidth, iw: innerWidth, ratio: s.width / s.height };
  });
  ok(g.br <= g.sr + 1 && g.bl >= g.sl - 1 && g.bb <= g.sb + 1, "banner inside stage");
  ok(await page.evaluate((s) => [...document.querySelectorAll(s)].every((e) => e.getBoundingClientRect().right <= innerWidth + 1), SEL), "no overflow in section");
  const appFull = () => page.$$eval(".hx__app", (a) => a.every((e) => e.scrollWidth <= e.clientWidth + 0.5 && getComputedStyle(e).textOverflow !== "ellipsis"));
  ok(await appFull(), ".hx__app not truncated (idle)");
  await page.screenshot({ path: SHOT + `herald-shown-${w}.png` });
  if (w >= 700) ok(Math.abs(g.br - g.sr) < 1.5 && g.br - g.bl > 380 && g.br - g.bl < 402, "banner at its natural width, right-aligned in its column"); else ok(g.br - g.bl > g.sr - g.sl - 24, "banner full width of stage");
  await sleep(1500);
  ok(await has(page, "hb-banner"), "banner stays");
  const r = () => page.evaluate(() => {
    const a = document.querySelector('[data-testid="hb-banner"]')?.getBoundingClientRect();
    const b = document.querySelector('[data-testid="hb-banner-2"]')?.getBoundingClientRect();
    const s = document.querySelector(".hx").getBoundingClientRect();
    const f = (x) => x && { top: x.top, bottom: x.bottom, left: x.left, right: x.right, width: x.width };
    return { a: f(a), b: f(b), s: f(s) };
  });
  // second banner: stacked beneath, same width, 10px gap
  ok(await has(page, "hb-banner-2"), "second banner entered");
  const t2 = await page.$eval(T("hb-banner-2"), (e) => e.textContent);
  ok(t2.includes("WebWatcher · Contra") && t2.includes("You have 1 new message") && !t2.includes("went 0") && !t2.includes("Dismiss") && t2.includes("2 min ago"), "banner 2 content");
  const q0 = await r();
  ok(Math.abs(q0.b.top - q0.a.bottom - 10) < 1.5 && Math.abs(q0.b.width - q0.a.width) < 1 && Math.abs(q0.b.left - q0.a.left) < 1, "banner 2 stacked under, same width, 10px gap");
  ok(q0.b.bottom <= q0.s.bottom + 1 && q0.b.right <= q0.s.right + 1, "banner 2 inside stage");
  ok(await page.evaluate((s) => [...document.querySelectorAll(s)].every((e) => e.getBoundingClientRect().right <= innerWidth + 1), SEL), "no overflow with two banners");
  // tooltip: beside the Snooze pill, never over another pill
  if (w >= 700) {
    await page.hover(T("hb-snooze")); await sleep(200);
    ok(await page.$eval(".hx__tip", (e) => getComputedStyle(e).visibility === "visible" && e.textContent === "returns at 9:00"), "snooze tooltip");
    ok(await page.evaluate(() => {
      const t = document.querySelector(".hx__tip").getBoundingClientRect(), p = document.querySelector(".hx__snooze").getBoundingClientRect();
      const ban = document.querySelector('[data-testid="hb-banner"]').getBoundingClientRect();
      const hit = [...document.querySelectorAll(".hx__pill")].some((q) => { if (q.classList.contains("hx__snooze") && q.closest('[data-testid="hb-banner"]')) return false; const r = q.getBoundingClientRect(); return !(t.right <= r.left || t.left >= r.right || t.bottom <= r.top || t.top >= r.bottom); });
      return t.left >= p.right && !hit && t.right <= ban.right;
    }), "tooltip right of the pill, overlapping no pill, inside its banner");
    await page.screenshot({ path: SHOT + `herald-tooltip-${w}.png` });
  }
  ok(await page.evaluate(() => { const x = document.querySelector('[data-testid="hb-speak"]'); const r = x.getBoundingClientRect(); const cx = r.left + r.width / 2, cy = r.top + r.height / 2; return [[0, -20], [0, 20]].every(([dx, dy]) => document.elementFromPoint(cx + dx, cy + dy)?.closest('[data-testid="hb-speak"]')); }), "speaker hit area >= 44 px tall");
  ok(await page.evaluate(() => { const x = document.querySelector('[data-testid="hb-close"]'); const r = x.getBoundingClientRect(); const cx = r.left + r.width / 2, cy = r.top + r.height / 2; return [[0, -20], [0, 20], [-20, 0], [20, 0]].every(([dx, dy]) => document.elementFromPoint(cx + dx, cy + dy)?.closest('[data-testid="hb-close"]')); }), "dismiss hit area >= 44 px");
  // speak: pre-rendered sample, click only
  ok(["hb-read", "hb-archive", "hb-delete", "hb-spam", "hb-snooze"].length === (await page.$$eval("[data-testid=hb-banner] .hx__pill", (b) => b.map((x) => x.textContent.replace("returns at 9:00", "")).filter((x) => ["Mark as Read", "Archive", "Delete", "Spam", "Snooze"].includes(x)).length)) && !(await has(page, "hb-open")), "email buttons: Mark as Read, Archive, Delete, Spam, Snooze (no Open)");
  ok(await page.$eval(T("hb-speak"), (e) => e.dataset.speaking === "0" && e.getAttribute("aria-pressed") === "false"), "speaker idle, always rendered");
  await click(page, "hb-speak");
  ok(await page.$eval(T("hb-speak"), (e) => e.dataset.speaking === "1" && e.getAttribute("aria-pressed") === "true" && e.classList.contains("is-on") && e.textContent.includes("reading") && e.querySelectorAll(".hx__meter i").length === 5), "speak -> reading + 5-bar meter");
  ok(await page.$eval("[data-testid=hb-banner] .hx__tw", (e) => e.classList.contains("is-reading")), "title underline sweep while reading");
  ok(await appFull(), ".hx__app not truncated while the reading chip is shown");
  await page.screenshot({ path: SHOT + `herald-reading-${w}.png` });
  ok((await page.evaluate(() => window.__played[0] || "")).endsWith("/audio/herald-email-3.mp3"), "plays the email-3 sample");
  ok((await page.evaluate(() => window.__ctor)) === 1, "one Audio, created on first click");
  await click(page, "hb2-speak");
  ok(await page.$eval(T("hb-speak"), (e) => e.dataset.speaking === "0") && await page.$eval(T("hb2-speak"), (e) => e.dataset.speaking === "1"), "switching banners stops the other");
  ok((await page.evaluate(() => window.__played[1] || "")).endsWith("/audio/herald-contra.mp3") && (await page.evaluate(() => window.__ctor)) === 1, "plays the Contra sample on the same Audio");
  await click(page, "hb2-speak");
  ok(await page.$eval(T("hb2-speak"), (e) => e.dataset.speaking === "0" && e.getAttribute("aria-pressed") === "false"), "second click stops");
  ok((await page.$eval(".hx__stack", (e) => e.getAttribute("aria-live"))) === "off", "stage not live");
  // snooze
  await click(page, "hb-snooze"); await sleep(500);
  ok(!(await has(page, "hb-banner")) && (await page.$eval(T("hb-returns"), (e) => e.textContent)).includes("returns at 9:00"), "snooze hides banner + label");
  await sleep(3200);
  ok((await has(page, "hb-banner")) && !(await has(page, "hb-returns")), "banner returns after 3s");
  for (const b of ["hb-read", "hb-archive", "hb-delete", "hb-spam", "hb-close"]) {
    await click(page, b); await sleep(500);
    ok(!(await has(page, "hb-banner")) && (await has(page, "hb-show")), `${b} dismisses`);
    if (b !== "hb-close") ok((await page.$eval(".hx__note", (e) => e.textContent)).includes("Done. Herald told WebWatcher, which told Gmail"), "done line");
    await click(page, "hb-show"); await sleep(400);
    ok(await has(page, "hb-banner"), "show again");
  }
  // --- stacking: move-up, deliver another, banner 2 buttons
  let q = await r();
  // dismiss the first -> second moves up smoothly
  await sleep(800);
  q = await r();
  const top2 = q.b.top - q.s.top, top1 = q.a.top - q.s.top;
  await click(page, "hb-close"); await sleep(380);
  const mq = await r();
  const mid = mq.b.top - mq.s.top;
  ok(mid < top2 - 2 && mid > top1 + 0.5, "banner 2 mid-move (smooth)");
  await sleep(500);
  q = await r();
  ok(!(await has(page, "hb-banner")) && Math.abs(q.b.top - q.s.top - top1) < 1.5, "banner 2 moved up into first slot");
  // deliver another: email re-enters with 4 + Beta invite
  ok(await page.$eval(T("hb-more"), (e) => e.textContent.includes("Deliver another from Rive team") && !e.disabled), "deliver control");
  ok((await page.$$eval(".hx__caption", (e) => e.map((x) => x.textContent))).join("|") === "Banners stay until you act on them, stacked per sender or site." && (await page.$eval(".vr__cap", (e) => e.textContent)) === "Herald can read a banner aloud. Press the speaker on a banner. This is the real sample.", "captions");
  await click(page, "hb-more"); await sleep(1000);
  ok(await has(page, "hb-banner"), "email banner re-enters");
  const t4 = await page.$eval(T("hb-banner"), (e) => e.textContent);
  ok(t4.includes("4 new from Rive team") && t4.includes("Beta invite · Scripting update"), "count 4 + Beta invite at front");
  q = await r();
  ok(q.a.top < q.b.top && Math.abs(q.b.top - q.a.bottom - 10) < 1.5, "stack restored: email above web");
  ok(await page.$eval(T("hb-more"), (e) => e.disabled), "no more than 3 banners (control done)");
  // banner 2 buttons
  await click(page, "hb2-snooze"); await sleep(600);
  ok(!(await has(page, "hb-banner-2")), "hb2-snooze hides");
  await sleep(3000);
  ok(await has(page, "hb-banner-2"), "banner 2 returns after 3s");
  for (const b of ["hb2-open", "hb2-close"]) {
    await click(page, b); await sleep(600);
    ok(!(await has(page, "hb-banner-2")), `${b} dismisses banner 2`);
    await click(page, "hb-close"); await sleep(600);
    await page.$eval(T("hb-show"), (e) => e.click()); await sleep(1300);
    ok((await has(page, "hb-banner")) && (await has(page, "hb-banner-2")), "show again restores both");
  }

  if (w < 700) {
    const hts = await page.$$eval(".hx__pill, .hx__more", (b) => b.map((x) => x.getBoundingClientRect().height));
    ok(hts.every((x) => x >= 43.5), "targets >= 44px");
  }
  await page.close();
}
// real audio, real clock: the voice ruler
async function ruler(w, h) {
  console.log(`--- ruler ${w}x${h}`);
  const page = await browser.newPage();
  await page.setViewport({ width: w, height: h });
  await page.goto(BASE + "/", { waitUntil: "networkidle2", timeout: 90000 });
  await page.$eval("#herald .hx", (e) => e.scrollIntoView({ block: "center" }));
  await page.waitForSelector(T("hb-banner-2"), { timeout: 6000 });
  await sleep(600);
  const R = () => page.$eval(T("hv-ruler"), (e) => ({ lit: +e.dataset.lit, sample: e.dataset.sample, w: e.getBoundingClientRect().width }));
  const time = () => page.$eval(T("hv-time"), (e) => e.textContent);
  const geo = () => page.evaluate(() => {
    const c = document.querySelector("#herald .container"), cs = getComputedStyle(c);
    const inner = c.getBoundingClientRect().right - parseFloat(cs.paddingRight);
    const st = document.querySelector("#herald .hx__stack").getBoundingClientRect();
    const b = (document.querySelector('[data-testid="hb-banner"]') || document.querySelector('[data-testid="hb-banner-2"]')).getBoundingClientRect();
    const title = document.querySelector("#herald h2");
    return { inner, sr: st.right, br: b.right, bt: b.top, tt: title.getBoundingClientRect().top, fs: parseFloat(getComputedStyle(title).fontSize), cw: c.getBoundingClientRect().width - 2 * parseFloat(cs.paddingRight), sh: document.querySelector("#herald").offsetHeight };
  });
  let r = await R();
  ok(r.lit === 0 && r.sample === "herald-email-3", "ruler at rest: 0 lit, top banner's sample");
  ok((await time()) === "0:00.0 / 0:04.2", "time readout at rest " + (await time()));
  if (w >= 1100) {
    const g = await geo();
    ok(r.w >= g.cw * 0.9, `ruler >= 90 % of container width (${Math.round(r.w)} / ${Math.round(g.cw)})`);
    ok(Math.abs(g.br - g.inner) <= 4 && Math.abs(g.sr - g.inner) <= 4, "banner stack right edge on the container edge");
    ok(g.bt < g.tt, "banner stack top above the title top");
    if (w >= 1440) ok(g.fs >= 96, "title >= 96 px at " + w + " (" + g.fs + ")");
  }
  ok(await page.evaluate(() => !!document.querySelector('[data-testid="hv-ruler"] canvas[role="img"][aria-label]')), "canvas role img with label");
  const h0 = (await geo()).sh;
  await page.$eval(T("hb-speak"), (e) => e.click());
  await sleep(500);
  const l1 = (await R()).lit, t1 = await time();
  await sleep(500);
  const l2 = (await R()).lit, t2 = await time();
  ok(l1 > 0 && l2 > l1 && t1 !== t2, `playing: lit grows ${l1} -> ${l2}, time ${t1} -> ${t2}`);
  await page.$eval(T("hb-speak"), (e) => e.click());
  await sleep(250);
  r = await R();
  ok(r.lit === 0 && (await time()).startsWith("0:00.0"), "second click stops: lit 0, time 0:00.0");
  await page.$eval(T("hb2-speak"), (e) => e.click());
  await sleep(300);
  ok((await R()).sample === "herald-contra", "contra speaker switches the ruler to the contra sample");
  await page.$eval(T("hb2-speak"), (e) => e.click());
  await sleep(200);
  // dismiss: ruler follows the top visible banner, section does not move
  await page.$eval(T("hb-close"), (e) => e.click());
  await sleep(300);
  const mid = (await geo()).sh;
  await sleep(500);
  ok((await R()).sample === "herald-contra", "email gone: ruler shows the contra sample");
  const h1 = (await geo()).sh;
  ok(h0 === h1 && h0 === mid, `section height unchanged by dismissing (${h0} / ${mid} / ${h1})`);
  await page.$eval(T("hb-show"), (e) => e.click());
  await sleep(1200);
  ok((await geo()).sh === h0 && (await R()).sample === "herald-email-3", "show again: same height, email sample back");
  await page.$eval(T("hb-more"), (e) => e.click());
  await sleep(900);
  ok((await R()).sample === "herald-email-4" && (await time()).endsWith("/ 0:05.2"), "deliver another: ruler follows to email-4");
  // ruler plays to the end by itself
  await page.$eval(T("hb-speak"), (e) => e.click());
  await sleep(5900);
  r = await R();
  ok(r.lit === 0 && (await page.$eval(T("hb-speak"), (e) => e.dataset.speaking)) === "0", "sample ends: ticks dim again");
  ok(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), "no horizontal overflow");
  await page.close();
}
try {
  const { readFileSync, readdirSync, statSync } = await import("node:fs");
  const walk = (d) => readdirSync(d).flatMap((f) => { const q = d + "/" + f; return statSync(q).isDirectory() ? walk(q) : [q]; });
  ok(!walk("src").some((f) => /\.(tsx?|css)$/.test(f) && readFileSync(f, "utf8").includes("speechSynthesis")), "no speechSynthesis anywhere in src");
  await ruler(1280, 900);
  await ruler(1440, 900);
  await ruler(834, 900);
  await ruler(390, 844);
  await run(1280, 900);
  await run(1440, 900);
  await run(390, 844);
} finally {
  await browser.close();
}
console.log(fails ? `${fails} FAILED` : "all passed");
process.exit(fails ? 1 : 0);
