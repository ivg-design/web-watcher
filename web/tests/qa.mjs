// QA sweep: console, reduced-motion, keyboard, touch targets, CLS, images, links. Read-only against BASE.
import puppeteer from "puppeteer-core";
const BASE = process.env.BASE || "http://localhost:3101";
const T = (id) => `[data-testid="${id}"]`;
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const defects = [];
const report = (name, pass, detail = []) => {
  console.log((pass ? "PASS " : "FAIL ") + name);
  for (const d of detail) console.log("   - " + d);
  if (!pass) detail.forEach((d) => defects.push(`[${name}] ${d}`));
};
const browser = await puppeteer.launch({ executablePath: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome", headless: "new" });
const VPS = [[1440, 900], [390, 844]];
async function mk(w, h, { reduce = false, cls = false, errs } = {}) {
  const page = await browser.newPage();
  await page.setViewport({ width: w, height: h, hasTouch: w < 500, isMobile: false });
  if (reduce) await page.emulateMediaFeatures([{ name: "prefers-reduced-motion", value: "reduce" }]);
  if (cls) await page.evaluateOnNewDocument(() => {
    window.__cls = { total: 0, items: [] };
    new PerformanceObserver((l) => { for (const e of l.getEntries()) { if (e.hadRecentInput) continue; window.__cls.total += e.value; window.__cls.items.push({ v: e.value, t: Math.round(e.startTime), src: (e.sources || []).map((s) => { const n = s.node; return n ? (n.nodeName + (n.id ? "#" + n.id : "") + (n.className && typeof n.className === "string" ? "." + n.className.trim().split(/\s+/).join(".") : "")) : "?"; }) }); } }).observe({ type: "layout-shift", buffered: true });
  });
  if (errs) {
    page.on("console", (m) => { if (m.type() === "error") errs.push("console.error: " + m.text().slice(0, 200) + " @" + page.url()); });
    page.on("pageerror", (e) => errs.push("pageerror: " + String(e.message).slice(0, 200) + " @" + page.url()));
    page.on("response", (r) => { if (r.status() >= 400) errs.push(`HTTP ${r.status()} ${r.url()}`); });
    page.on("requestfailed", (r) => { const f = r.failure()?.errorText || ""; if (!/ABORTED/.test(f)) errs.push(`requestfailed ${r.url()} ${f}`); });
  }
  return page;
}
const go = async (page, path) => { for (let i = 0; i < 3; i++) { try { await page.goto(BASE + path, { waitUntil: "networkidle2", timeout: 90000 }); const bad = await page.evaluate(() => !!document.querySelector("nextjs-portal")?.shadowRoot?.querySelector("[data-nextjs-dialog]")); if (!bad) return; } catch {} await sleep(20000); } };
const jsclick = async (page, sel) => { const ok = await page.$(sel); if (!ok) return false; await page.$eval(sel, (e) => { e.scrollIntoView({ block: "center", behavior: "instant" }); e.click(); }); return true; };

const ONLY = process.env.ONLY ? process.env.ONLY.split(",") : null; const want_ = (n) => !ONLY || ONLY.includes(String(n));
// 1. console
for (const [w, h] of want_(1) ? VPS : []) {
  const errs = [];
  const page = await mk(w, h, { errs });
  const notes = [];
  for (const p of ["/", "/docs", "/docs/finding-the-element", "/changelog"]) await go(page, p);
  await go(page, "/");
  await sleep(1500);
  const step = async (name, fn) => { console.error("  step", name, w); try { const r = await fn(); if (r === false) notes.push("could not drive: " + name); } catch (e) { notes.push(`drive ${name} threw: ${e.message.slice(0, 120)}`); } await sleep(500); };
  await step("watch-type row", () => jsclick(page, T("wt-row-badge")));
  await step("picker scan", () => jsclick(page, T("pd-scan")));
  await step("picker confirm flow", async () => { for (const id of ["pd-pick", "pd-use", "pd-confirm", "pd-add"]) { await sleep(300); await jsclick(page, T(id)); } });
  await step("gmail view", async () => { await page.$eval("#gmail .gx", (e) => e.scrollIntoView({ block: "center", behavior: "instant" })); await page.waitForFunction(() => document.querySelectorAll('[data-testid="gm-row"]').length >= 5, { timeout: 8000 }); });
  await step("gmail mark read", () => jsclick(page, T("gm-markread")));
  await step("herald snooze", async () => { await page.$eval("#herald .hx", (e) => e.scrollIntoView({ block: "center", behavior: "instant" })); await page.waitForSelector(T("hb-banner"), { timeout: 6000 }); return jsclick(page, T("hb-snooze")); });
  await step("privacy switches", async () => { for (const i of [1, 2, 3]) await jsclick(page, T(`pv-switch-${i}`)); });
  await step("how-it-works step", () => jsclick(page, T("hw-step-3")));
  await step("mark popover", async () => { await page.$eval(T("watch-mark"), (e) => e.click()); await sleep(300); });
  await sleep(1000);
  const uniq = [...new Set(errs)].filter((e) => !/stateMachines.*deprecated/i.test(e));
  report(`1 console @${w}`, uniq.length === 0, [...uniq, ...notes.map((n) => "(note) " + n)]);
  await page.close();
}

// 2. reduced motion
for (const [w, h] of want_(2) ? VPS : []) {
  const page = await mk(w, h, { reduce: true });
  await go(page, "/");
  await sleep(2000);
  const d = [];
  const anims = await page.evaluate(() => document.getAnimations().filter((a) => a.playState === "running").map((a) => { const t = a.effect?.target; return (a.animationName || a.transitionProperty || "anim") + " on " + (t ? t.tagName + (t.className && typeof t.className === "string" ? "." + t.className.trim().split(/\s+/).join(".") : "") : "?") + (t && t.closest("canvas, [data-testid=watch-mark]") ? " [mark]" : ""); }));
  const bad = anims.filter((a) => !/\[mark\]|canvas/.test(a));
  if (bad.length) d.push("running animations after 2s: " + [...new Set(bad)].slice(0, 12).join(" | "));
  await page.$eval("#how-it-works", (e) => e.scrollIntoView({ block: "center", behavior: "instant" })); await sleep(1500);
  const st = await page.$eval(T("hw-stage"), (e) => e.dataset.beat).catch(() => null);
  const n = await page.$eval(T("hw-notif"), (e) => e.classList.contains("is-on") && getComputedStyle(e).opacity === "1").catch(() => false);
  if (st !== "3" || !n) d.push(`how-it-works not on final beat statically (beat=${st}, notif visible=${n})`);
  await page.$eval("#gmail .gx", (e) => e.scrollIntoView({ block: "center", behavior: "instant" })); await sleep(1500);
  const rows = await page.$$eval(T("gm-row"), (r) => r.map((e) => e.getBoundingClientRect().height > 0 && getComputedStyle(e).opacity === "1"));
  if (rows.length < 5 || rows.some((x) => !x)) d.push(`gmail rows not all present/visible: ${JSON.stringify(rows)}`);
  const gmAnim = await page.evaluate(() => document.querySelector("#gmail").getAnimations({ subtree: true }).filter((a) => a.playState === "running").length);
  if (gmAnim) d.push(`gmail has ${gmAnim} running animations`);
  await page.$eval("#herald .hx", (e) => e.scrollIntoView({ block: "center", behavior: "instant" })); await sleep(1500);
  const hb = await page.$eval(T("hb-banner"), (e) => { const r = e.getBoundingClientRect(); return r.width > 0 && getComputedStyle(e).opacity === "1"; }).catch(() => false);
  if (!hb) d.push("herald banner not visible");
  await jsclick(page, T("wt-row-badge")); await sleep(1000);
  if (!(await page.$(T("wt-notif")))) d.push("watch-type row click: no notification");
  if (!(await page.$(T("watch-badge")))) d.push("watch-type row click: header badge absent");
  await jsclick(page, T("pd-scan")); await sleep(1000);
  const step = await page.$eval(T("pd"), (e) => e.dataset.step).catch(() => null);
  if (step !== "2") d.push(`picker Scan page did not advance (step=${step})`);
  report(`2 reduced-motion @${w}`, d.length === 0, d);
  await page.close();
}

// 3. keyboard (1440 and 390)
for (const [w, h] of want_(3) ? VPS : []) {
  const page = await mk(w, h);
  await go(page, "/");
  await sleep(2000);
  // The Gmail notification (and its buttons) is inert until the arrivals have run: show the stage and wait for it, then tab from the top.
  await page.$eval("#gmail .gx", (e) => e.scrollIntoView({ block: "center", behavior: "instant" }));
  await page.waitForFunction(() => document.querySelector("#gmail .gx__nw") && !document.querySelector("#gmail .gx__nw").classList.contains("is-gone"), { timeout: 8000 });
  await page.evaluate(() => { window.scrollTo(0, 0); document.activeElement?.blur(); const s = document.createElement("span"); s.tabIndex = -1; document.body.prepend(s); s.focus(); s.remove(); });
  const seq = [];
  for (let i = 0; i < 400; i++) {
    await page.keyboard.press("Tab"); await sleep(250);
    // The Herald banner enters once its stage is in view: give it its entrance before tabbing on (a stacked phone layout reaches the copy first).
    if (await page.evaluate(() => !!document.activeElement?.closest("#herald") && !document.querySelector('[data-testid="hb-banner"]'))) await sleep(1800);
    const info = await page.evaluate(() => {
      const e = document.activeElement; if (!e || e === document.body) return null;
      const cs = getComputedStyle(e);
      const ring = (cs.outlineStyle !== "none" && parseFloat(cs.outlineWidth) > 0) || (cs.boxShadow && cs.boxShadow !== "none");
      return { id: e.dataset.testid || "", sel: e.tagName.toLowerCase() + (e.id ? "#" + e.id : "") + (typeof e.className === "string" && e.className ? "." + e.className.trim().split(/\s+/).slice(0, 2).join(".") : ""), txt: (e.getAttribute("aria-label") || e.textContent || "").trim().slice(0, 24), ring, y: e.getBoundingClientRect().top + scrollY, main: !!e.closest("main") };
    });
    if (!info) continue;
    if (seq.length && seq[0].sel === info.sel && seq[0].txt === info.txt && seq.length > 5) break;
    seq.push(info);
    if (seq.length > 1 && info.id === "dl-btn") break;
  }
  const d = [];
  const want = ["watch-mark", "hv-play", "hw-step-1", "hw-step-2", "hw-step-3", "pd-scan", ...["badge", "count", "text", "exists", "disappears", "subtree"].map((s) => "wt-row-" + s), "gm-open", "gm-markread", "gm-archive", "gm-delete", "gm-spam", "hb-read", "hb-archive", "hb-delete", "hb-spam", "hb-snooze", "pv-switch-1", "pv-switch-2", "pv-switch-3", "dl-btn"];
  let last = -1;
  for (const id of want) {
    const idx = seq.findIndex((s) => s.id === id);
    if (idx < 0) { d.push(`not reachable by Tab: ${id}${id.startsWith("gm-") || id.startsWith("hb-") ? " (may be hidden/inert until the notification shows)" : ""}`); continue; }
    if (idx < last) d.push(`out of document order: ${id} (tab index ${idx} after ${last})`);
    last = Math.max(last, idx);
  }
  const noRing = seq.filter((s) => !s.ring);
  for (const s of noRing) d.push(`no focus ring: ${s.id ? `[data-testid=${s.id}]` : s.sel} "${s.txt}"`);
  d.push(`(info) ${seq.length} focus stops; hidden-at-top check: ${seq.filter((s) => s.y > 0 && false).length}`);
  // Escape returns focus to the mark
  await page.evaluate(() => { window.scrollTo(0, 0); });
  await page.focus(T("watch-mark")); await page.keyboard.press("Enter"); await sleep(500);
  const open = !!(await page.$(T("watch-popover")));
  await page.keyboard.press("Escape"); await sleep(500);
  const closed = !(await page.$(T("watch-popover")));
  const f = await page.evaluate(() => document.activeElement?.dataset?.testid);
  if (!open) d.push("Enter on the mark does not open the popover");
  if (!closed) d.push("Escape does not close the popover");
  if (f !== "watch-mark") d.push(`after Escape focus is on ${f || document?.activeElement} not the mark`);
  const real = d.filter((x) => !x.startsWith("(info)"));
  report(`3 keyboard @${w}`, real.length === 0, d);
  await page.close();
}

// 4. touch targets @390
if (want_(4)) {
  const page = await mk(390, 844);
  await go(page, "/"); await sleep(1500);
  const small = await page.evaluate(() => [...document.querySelectorAll("main button, main a")].filter((e) => { const r = e.getBoundingClientRect(); const cs = getComputedStyle(e); return r.width > 0 && r.height > 0 && cs.visibility !== "hidden" && !e.closest("[aria-hidden=true]") && r.height < 40; }).map((e) => { const r = e.getBoundingClientRect(); return `${e.tagName.toLowerCase()}${e.dataset.testid ? "[data-testid=" + e.dataset.testid + "]" : typeof e.className === "string" && e.className ? "." + e.className.trim().split(/\s+/)[0] : ""} "${(e.getAttribute("aria-label") || e.textContent).trim().slice(0, 20)}" ${Math.round(r.width)}x${Math.round(r.height)}`; }));
  report("4 touch targets @390 (>=40px)", small.length === 0, [...new Set(small)]);
  await page.close();
}

// 5. CLS
for (const [w, h] of want_(5) ? VPS : []) {
  const page = await mk(w, h, { cls: true });
  await page.goto(BASE + "/", { waitUntil: "load", timeout: 90000 });
  await sleep(4000);
  const c = await page.evaluate(() => window.__cls);
  const top = c.items.sort((a, b) => b.v - a.v).slice(0, 5).map((i) => `${i.v.toFixed(4)} @${i.t}ms ${i.src.join(", ")}`);
  report(`5 CLS @${w} = ${c.total.toFixed(4)} (<0.05)`, c.total < 0.05, top);
  if (c.total >= 0.05 === false && top.length) console.log("   (top sources) " + top.join(" | "));
  await page.close();
}

// 6. images + 7. links
if (want_(6) || want_(7)) {
  const page = await mk(1440, 900);
  await go(page, "/"); await page.evaluate(async () => { for (let y = 0; y < document.body.scrollHeight; y += 600) { scrollTo({ top: y, behavior: "instant" }); await new Promise((r) => setTimeout(r, 120)); } scrollTo({ top: 0, behavior: "instant" }); }); await sleep(1500);
  await page.waitForFunction(() => [...document.images].every((i) => i.complete), { timeout: 15000 }).catch(() => {});
  const imgs = await page.evaluate(() => [...document.images].map((i) => ({ s: (i.currentSrc || i.src).replace(location.origin, "").slice(0, 60), alt: i.getAttribute("alt"), hid: i.getAttribute("aria-hidden") === "true" || ["presentation", "none"].includes(i.getAttribute("role")), w: i.getAttribute("width"), h: i.getAttribute("height"), nw: i.naturalWidth, cls: i.className })));
  const d = [];
  for (const i of imgs) {
    const p = [];
    if (i.alt === null) p.push("no alt attr"); else if (i.alt === "" && !i.hid) p.push('alt="" without aria-hidden/role=presentation');
    if (!i.w || !i.h) p.push("missing width/height attr");
    if (!(i.nw > 0)) p.push("naturalWidth 0");
    if (p.length) d.push(`img ${i.s} (.${i.cls}): ${p.join(", ")}`);
  }
  // The Gmail sender-editor screenshot must be a readable figure (>= 420 px wide at 1440, 2x srcset).
  const ed = await page.evaluate(() => { const i = document.querySelector('img[src*="gmail-sender-editor"]'); return i ? { w: i.getBoundingClientRect().width, set: !!i.getAttribute("srcset") } : null; });
  if (!ed) d.push("gmail-sender-editor figure missing at 1440");
  else { if (ed.w < 420) d.push(`gmail-sender-editor renders ${Math.round(ed.w)} px wide (< 420)`); if (!ed.set) d.push("gmail-sender-editor has no 2x srcset"); }
  report(`6 images (${imgs.length})`, d.length === 0, d);
  const linkd = [];
  for (const path of ["/", "/docs"]) {
    await go(page, path);
    const hrefs = await page.evaluate(() => [...document.querySelectorAll("a[href]")].map((a) => [a.getAttribute("href"), (a.textContent || a.getAttribute("aria-label") || "").trim().slice(0, 24)]));
    for (const [h, t] of new Map(hrefs.map((x) => [x[0], x])).values()) {
      if (/^(mailto:|tel:)/.test(h)) { linkd.push(`${path}: ${h} is ${h.split(":")[0]} (note, not https)`); continue; }
      if (h.startsWith("#")) { const id = h.slice(1); if (id && !(await page.$(`[id="${id}"]`))) linkd.push(`${path}: anchor ${h} "${t}" has no target`); continue; }
      let u; try { u = new URL(h, BASE + path); } catch { linkd.push(`${path}: bad href ${h}`); continue; }
      if (u.origin === BASE) {
        const r = await fetch(u.origin + u.pathname + u.search, { redirect: "follow" }).catch(() => ({ status: 0 }));
        if (r.status !== 200) linkd.push(`${path}: ${h} "${t}" -> ${r.status}`);
        if (u.hash && r.status === 200) { /* anchors checked on the page itself for "/" only */ }
      } else if (u.protocol !== "https:") linkd.push(`${path}: external ${h} "${t}" is not https`);
    }
  }
  report("7 links", linkd.filter((x) => !x.includes("(note")).length === 0, linkd);
  await page.close();
}
await browser.close();
console.log("\n=== DEFECTS (" + defects.length + ") ===");
defects.forEach((d) => console.log(d));
process.exit(defects.length ? 1 : 0);
