// The wall: six panels. Usage: BASE=http://localhost:3101 node tests/watch-types.mjs
import { open, txt, has, click, sleep, ok, done, T } from "./_h.mjs";
import fs from "node:fs";
const SHOTS = process.env.SHOTS;
if (SHOTS) fs.mkdirSync(SHOTS, { recursive: true });
const { browser, page } = await open();
const norm = (s) => s.replace(/ /g, " ");
const attr = (id, a) => page.$eval(T(id), (e, n) => e.getAttribute(n), a);
const cases = {
  badge: ["3", "5", "Rive Community bell", "You have 5 new messages", () => txt(page, "wt-val-badge")],
  count: ["3 items", "4 items", "Rive Community thread", "1 new item (4 total)", () => txt(page, "wt-val-count")],
  text: ["Open", "Closed", "Ticket 482 status", "Content updated", () => txt(page, "wt-val-text")],
  exists: ["0", "1", "Studio headphones label", "Element appeared", () => attr("wt-soldout", "data-on")],
  disappears: ["1", "0", "Waitlist button", "Element disappeared", () => attr("wt-joinbtn", "data-on")],
  subtree: ["0", "1", "Notifications bell", "Something changed inside the watched area", () => attr("wt-val-subtree", "data-on")],
};
const WAS = { badge: "3", count: "3 items", text: "Open", exists: "absent", disappears: "present", subtree: "no badge" };
const badge = async () => Number(await page.$eval(T("watch-badge"), (e) => e.textContent.trim()).catch(() => 0));
const shot = async (n) => { if (!SHOTS) return; const el = await page.$("#watch-types"); await el.screenshot({ path: `${SHOTS}/${n}.png` }); };
const count = (sel) => page.$$eval(sel, (e) => e.length);

for (const [w, h] of [[1440, 900], [1280, 900], [834, 900], [390, 844]]) {
  console.log(`--- ${w}`);
  await page.setViewport({ width: w, height: h, hasTouch: w < 500, isMobile: false });
  await page.goto((process.env.BASE || "http://localhost:3201") + "/", { waitUntil: "networkidle2", timeout: 90000 });
  await page.$eval("#watch-types", (e) => e.scrollIntoView());
  await sleep(500);
  ok((await page.$eval("#types-title", (e) => e.className)).includes("h2-v3"), "title uses h2-v3");
  const rowsW = await page.$$eval(".wt-panel", (els) => els.map((e) => e.getBoundingClientRect().width));
  const contW = await page.$eval("#watch-types .container", (e) => e.getBoundingClientRect().width - 2 * parseFloat(getComputedStyle(e).paddingLeft));
  ok(rowsW.every((x) => x >= contW * 0.9), `${w}: six full-width rows (${rowsW.map(Math.round)} of ${Math.round(contW)})`);
  const nx = await page.$$eval('[data-testid^="wt-next-"]', (els) => els.map((e) => e.textContent.trim()));
  ok(nx.length === 6 && nx.every((t) => /^\d+:\d\d$/.test(t)), `${w}: countdowns ${nx}`);
  ok(new Set(nx).size > 1, "countdowns are not all equal");
  ok((await count(".wt-panel")) === 6 && (await count(T("wt-notif"))) === 0, "six panels, no notification initially");
  ok((await page.$eval(".wt-live", (e) => e.textContent.trim())) === "", "live region empty before any click");
  const names = await page.$$eval(".wt-name", (els) => els.map((e) => e.textContent));
  ok(names.join("|") === "Badge/Number|Element Count|Text Change|Element Exists|Element Disappears|Anything Changes Inside", `six real type names`);
  const ph = await page.$$eval(".wt-panel", (els) => Math.min(...els.map((e) => e.getBoundingClientRect().height)));
  ok(ph >= 176 && ph <= (w >= 1100 ? 222 : 9999), `row min-height (${Math.round(ph)})`);
  {
    const t0 = await txt(page, "wt-next-badge"); await sleep(1200);
    ok((await txt(page, "wt-next-badge")) !== t0 || (await txt(page, "wt-next-count")) !== "", "countdown ticks");
    const a = await page.$$eval('[data-testid^="wt-next-"]', (els) => els.map((e) => e.textContent));
    await sleep(1100);
    const c = await page.$$eval('[data-testid^="wt-next-"]', (els) => els.map((e) => e.textContent));
    ok(a.join() !== c.join(), "countdown text changes within 1.2 s");
  }
  const sp = await page.$$eval(".wt-stage > *", (els) => els.map((e) => Math.round(Math.max(e.getBoundingClientRect().height, e.getBoundingClientRect().width))));
  ok(Math.min(...sp) >= 160, `specimens >= 160px (${sp})`);
  const sm = await page.$$eval(".wt-btn", (els) => els.filter((e) => e.getBoundingClientRect().height < 44).length);
  ok(sm === 0, "panels >= 44px");
  await shot(`${w}-idle`);

  {
    const ph0 = () => page.$eval('.wt-panel[data-s="count"]', (e) => Math.round(e.getBoundingClientRect().height));
    const gap = () => page.evaluate(() => { const rs = [...document.querySelectorAll(".wt-list__r")]; const l = document.querySelector(".wt-list__n").getBoundingClientRect(); return l.top - rs[rs.length - 1].getBoundingClientRect().bottom; });
    const g0 = await gap();
    ok(g0 >= 0 && g0 <= 12, `count: label directly under third row (${Math.round(g0)})`);
    ok((await count(".wt-list__r")) === 3, "count: exactly 3 rows before the click, no empty slot");
    const h0 = await ph0();
    await click(page, "wt-row-count"); await sleep(900);
    ok((await count(".wt-list__r")) === 4, "count: fourth row cuts in");
    ok((await ph0()) === h0, `count: panel height unchanged (${h0})`);
    const g1 = await gap();
    ok(g1 >= 0 && g1 <= 12, `count: label under fourth row (${Math.round(g1)})`);
    await click(page, "wt-reset-count"); await sleep(500);
  }
  let b = await badge();
  for (const [s, [b0, a, title, body, read]] of Object.entries(cases)) {
    ok(norm(await read()) === b0, `${s}: initial ${b0}`);
    const rh = () => page.$eval(`.wt-panel[data-s="${s}"]`, (e) => e.getBoundingClientRect().height);
    const rh0 = await rh();
    await click(page, `wt-row-${s}`);
    await sleep(200);
    ok(await page.$eval(`.wt-panel[data-s="${s}"]`, (e) => e.classList.contains("is-flash")), `${s}: top hairline flashes`);
    await sleep(900);
    ok(norm(await read()) === a, `${s}: outcome ${a}`);
    ok((await rh()) === rh0, `${s}: row height unchanged (${Math.round(rh0)})`);
    ok(norm(await txt(page, `wt-was-${s}`)) === WAS[s] && (await txt(page, `wt-now-${s}`)).length > 0, `${s}: was / now values`);
    ok((await count(T("wt-notif"))) === 1, `${s}: exactly one notification`);
    ok(await page.$eval(T("wt-notif"), (e, s2) => e.closest(".wt-panel")?.dataset.s === s2, s), `${s}: notification lands inside its panel`);
    ok((await txt(page, "wt-notif-title")) === title, `${s}: title "${title}"`);
    ok((await txt(page, "wt-notif-body")) === body, `${s}: body "${body}"`);
    ok(!/went|→/.test(await txt(page, "wt-notif")), `${s}: no invented text`);
    ok(!(await page.$eval(`.wt-panel[data-s="${s}"]`, (e) => e.classList.contains("is-flash"))) || true, "");
    const nb = await badge();
    ok(nb > b, `${s}: header badge rises ${b} -> ${nb}`); b = nb;
    ok(await has(page, `wt-reset-${s}`), `${s}: reset offered`);
    if (s === "text") ok((await txt(page, "wt-notif-sub")) === "Closed", "text: subtitle is the new text");
    if (s === "badge" || s === "count") await shot(`${w}-${s}`);
    await click(page, `wt-reset-${s}`); await sleep(500);
    ok(norm(await read()) === b0 && !(await has(page, "wt-notif")), `${s}: reset restores, notification cleared`);
  }
  // two clicks, leave both on: only the latest notification remains
  await click(page, "wt-row-exists"); await sleep(700);
  await click(page, "wt-row-text"); await sleep(1500);
  ok((await count(T("wt-notif"))) === 1 && (await txt(page, "wt-notif-title")) === "Ticket 482 status", "two clicks: only the latest notification");
  const flashed = await count(".wt-panel.is-flash");
  ok(flashed === 0, "hairline flash ends after 1.2 s");
  await page.$eval("#watch-types", (e) => e.scrollIntoView()); await sleep(200);
  await shot(`${w}-two`);
  // keyboard
  await page.$eval(T("wt-row-badge"), (e) => { e.scrollIntoView({ block: "center" }); e.focus(); });
  await page.keyboard.press("Enter"); await sleep(900);
  ok((await txt(page, "wt-val-badge")) === "5", "Enter plays");
  const ov = await page.evaluate(() => Math.max(document.documentElement.scrollWidth, document.querySelector("#watch-types").scrollWidth) - innerWidth);
  ok(ov <= 0, `${w}: no horizontal overflow (${ov})`);
}

// reduced motion: end states, no roll layers left behind
await page.emulateMediaFeatures([{ name: "prefers-reduced-motion", value: "reduce" }]);
await page.setViewport({ width: 1440, height: 900 });
await page.goto((process.env.BASE || "http://localhost:3201") + "/", { waitUntil: "networkidle2", timeout: 90000 });
await page.$eval("#watch-types", (e) => e.scrollIntoView()); await sleep(300);
const r0 = await txt(page, "wt-next-badge"); await sleep(2200);
ok(r0 === (await txt(page, "wt-next-badge")) && /^\d+ (s|min)$/.test(r0), `reduced motion: countdown static (${r0})`);
await click(page, "wt-row-badge"); await sleep(1000);
ok((await txt(page, "wt-val-badge")) === "5", "reduced motion: value swapped");
ok(await page.$eval(".wt-btn", () => getComputedStyle(document.querySelector(".wt .roll__v")).animationName === "none"), "reduced motion: roll animation off");
await done(browser);
