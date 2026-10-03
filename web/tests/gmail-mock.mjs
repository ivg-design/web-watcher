import puppeteer from "puppeteer-core";
import { T, sleep } from "./_h.mjs";
const SHOT = "/private/tmp/claude-501/-Users-ivg-github-web-watcher/1b5c3420-5ad4-4c49-88f4-04aad1e374ed/scratchpad/r3/gmail/";
const BASE = process.env.BASE || "http://localhost:3101";
const SEL = "#gmail .gx__left, #gmail .gx__mail, #gmail .gx__notif, #gmail .gx__more, #gmail .gx__acts button";
let fails = 0;
const ok = (c, m) => { console.log((c ? "PASS " : "FAIL ") + m); if (!c) fails++; };
const browser = await puppeteer.launch({ executablePath: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome", headless: "new" });
const rows = (p) => p.$$eval(T("gm-row"), (r) => r.map((e) => ({ rive: e.dataset.rive === "1", unread: e.dataset.unread === "1" })));
const count = (p) => p.$eval(T("gm-count"), (e) => e.textContent.trim());
const notifOpen = (p) => p.$eval(".gx__nw", (e) => !e.classList.contains("is-gone"));
const click = async (p, id) => { await p.$eval(T(id), (e) => e.scrollIntoView({ block: "center" })); await p.$eval(T(id), (e) => e.click()); };

async function run(w, h) {
  console.log(`--- ${w}x${h}`);
  const page = await browser.newPage();
  await page.setViewport({ width: w, height: h });
  await page.goto(BASE + "/", { waitUntil: "networkidle2", timeout: 90000 });
  ok((await rows(page)).length === 6 && !(await notifOpen(page)), "before view: 6 seed mails, no notification");
  await page.$eval("#gmail .gx__mail", (e) => e.scrollIntoView({ block: "center" }));
  await page.waitForFunction(() => document.querySelector('[data-testid="gm-count"]').textContent.trim() === "3", { timeout: 8000 });
  await sleep(500);
  ok((await count(page)) === "3", "three arrivals -> count 3");
  const r = await rows(page);
  ok(r.slice(0, 3).every((x) => x.rive && x.unread), "rive rows on top, unread");
  const subj = await page.$eval(T("gm-subjects"), (e) => e.textContent.trim());
  ok(subj.startsWith("Release notes") && subj.includes("Office hours") && subj.includes("Scripting update") && subj.includes(" · "), "subjects joined with ·: " + subj);
  const title = await page.$eval(".gx__nt strong", (e) => e.textContent);
  ok(title === "3 new from Rive team", "title " + title);
  // geometry: lit notification left, dim inbox right, hairline between (two columns from 1100)
  const g = await page.evaluate(() => {
    const n = document.querySelector('[data-testid="gm-notif"]').getBoundingClientRect();
    const m = document.querySelector(".gx__mail").getBoundingClientRect();
    const bar = document.querySelector(".gx__bar").getBoundingClientRect();
    const lab = document.querySelector(".gx__label").getBoundingClientRect();
    const hit = document.elementFromPoint(lab.left + lab.width / 2, lab.top + lab.height / 2);
    const ha = document.querySelector(".gmail__h-a"), hb = document.querySelector(".gmail__h-b");
    const lum = (c) => { const m = c.match(/oklch\(([\d.]+)(?: ([\d.]+) ([\d.]+))?(?: \/ ([\d.]+%?))?\)/); return m; };
    const rr = (rive) => { const e = [...document.querySelectorAll('[data-testid="gm-row"]')].find((x) => (x.dataset.rive === "1") === rive); return e ? getComputedStyle(e).color : ""; };
    const mailBg = getComputedStyle(document.querySelector(".gx__mail")).backgroundColor;
    return { nt: n.top, nb: n.bottom, nl: n.left, nr: n.right, mt: m.top, ml: m.left, barOk: !!hit && !!hit.closest(".gx__bar"), sw: document.documentElement.scrollWidth, iw: innerWidth, hat: ha.getBoundingClientRect().top, hbt: hb.getBoundingClientRect().top, ca: getComputedStyle(ha).color, cb: getComputedStyle(hb).color, rv: rr(true), ot: rr(false), mailBg, bl: getComputedStyle(hb).borderLeftWidth, h2n: document.querySelectorAll("#gmail h2").length };
  });
  const parse = (c) => { const m = c.match(/[\d.]+/g).map(Number); return { l: m[0], a: m.length > 3 ? m[3] : 1, all: m }; };
  ok(g.sw <= g.iw, `no horizontal page overflow (${g.sw} <= ${g.iw})`);
  ok(g.h2n === 1, "exactly one h2 in #gmail");
  ok(g.barOk, "inbox header (Inbox · Watching @rive.app) is not covered");
  ok(g.mailBg === "rgba(0, 0, 0, 0)" || !/255, 255, 255/.test(g.mailBg), "inbox is not a white card (" + g.mailBg + ")");
  { const ca = parse(g.ca), cb = parse(g.cb); const lit = (c) => c.all.slice(0, 3).reduce((x, y) => x + y, 0) * c.a; ok(cb.a < ca.a || lit(cb) < lit(ca), `second headline half dimmer (${g.cb} vs ${g.ca})`); }
  { const rv = parse(g.rv), ot = parse(g.ot); const sum = (c) => c.all.slice(0, 3).reduce((x, y) => x + y, 0); ok(sum(rv) > sum(ot), `watched row lighter than other row (${g.rv} vs ${g.ot})`); }
  if (w >= 1100) {
    ok(Math.abs(g.hat - g.hbt) <= 4, `headline halves share a top (${Math.round(g.hat)} / ${Math.round(g.hbt)})`);
    ok(g.nr < g.ml, `notification right edge ${Math.round(g.nr)} is left of the inbox left edge ${Math.round(g.ml)}`);
    ok(g.bl === "1px", "hairline between the columns");
  } else ok(g.nt >= 0 && g.nl >= 0 && g.nr <= g.iw && g.nb <= g.mt + 1, "notification fully visible, above the inbox");
  ok((await page.$eval(".gx", (e) => e.getAttribute("aria-live"))) === "off", "stage aria-live=off");
  ok((await page.$$eval(".gx [role=status]", (e) => e.length)) === 1, "only one role=status inside the stage (the inbox header line)");
  ok((await page.$eval(T("gm-open"), (e) => e.getAttribute("aria-label"))) === "Open the newest message", "notification card is the Open control (aria-label)");
  ok((await page.$$eval(".gx__acts button", (b) => b.map((x) => x.textContent.trim()))).join("|") === "Mark as Read|Archive|Delete|Spam", "actions are exactly Mark as Read, Archive, Delete, Spam (no Open button)");
  ok(await page.evaluate((s) => [...document.querySelectorAll(s)].every((e) => e.getBoundingClientRect().right <= innerWidth + 1), SEL), "no overflow in section");
  const fig = await page.evaluate(() => {
    const i = document.querySelector('[data-testid="gm-figure"] img').getBoundingClientRect();
    const f = document.querySelector(".gmail__frame");
    const cs = getComputedStyle(f);
        const h2 = document.querySelector("#gmail h2");
    return { iw: i.width, pad: cs.paddingLeft, rad: cs.borderRadius, bg: cs.backgroundImage.includes("linear-gradient"), h2: h2.className, h2t: h2.textContent, eyebrow: !!document.querySelector("#gmail .eyebrow"), cap: document.querySelector('[data-testid="gm-figure"] figcaption').textContent, tab: getComputedStyle(document.querySelector('[data-testid="gm-count"]')).fontVariantNumeric };
  });
  ok(fig.h2.includes("h2-v3") && fig.h2t === "Watch a sender, not an inbox." && !fig.eyebrow, "h2-v3 title, no eyebrow");
  ok(fig.bg && fig.pad === (w > 700 ? "40px" : "20px") && fig.rad === "16px", `figure frame: gradient, padding ${fig.pad}, radius ${fig.rad}`);
  if (w >= 1440) ok(fig.iw >= 440, "figure image width >= 440 (" + Math.round(fig.iw) + ")");
  ok(fig.cap === "The sender watcher editor in WebWatcher 1.10.9.", "caption: " + fig.cap);
    ok(fig.tab.includes("tabular"), "unread count is tabular");
  await page.screenshot({ path: SHOT + `gmail-arrived-${w}.png` });
  // Mark as Read: rows un-bold in a stagger, count rolls to 0, the card folds away, header says so and then fades
  await click(page, "gm-markread"); await sleep(250);
  ok((await rows(page)).some((x) => !x.unread), "mark read starts un-bolding rows");
  await sleep(600);
  ok((await rows(page)).every((x) => !x.unread), "mark read un-bolds all");
  ok((await count(page)) === "0", "count rolls to 0");
  ok(!(await notifOpen(page)), "notification folds away at 0 unread");
  ok((await page.$eval(T("gm-status"), (e) => e.textContent.trim())) === "Nothing unread from @rive.app. Notification cleared.", "header status line: nothing unread, notification cleared");
  ok(!(await page.evaluate(() => document.body.innerText.includes("Nothing left to read") || document.body.innerText.includes("All read"))), "no invented All read notification");
  await sleep(3400);
  ok((await page.$eval(T("gm-status"), (e) => e.textContent.trim())) === "Watching @rive.app", "status line fades back to Watching @rive.app");
  // Deliver another after collapse
  const rh = () => page.$eval(T("gm-inbox"), (e) => e.getBoundingClientRect().height);
  const h0 = await rh();
  await click(page, "gm-newmail"); await sleep(500);
  ok((await count(page)) === "1" && (await rows(page)).length === 8, "deliver another: count 1, 8 rows (capped)");
  await click(page, "gm-newmail"); await sleep(400);
  ok((await count(page)) === "2", "count 2");
  // Archive
  await click(page, "gm-archive"); await sleep(700);
  ok((await rows(page)).length === 8 && !(await notifOpen(page)), "archive removes counted rows, notification dismissed");
  ok(Math.abs((await rh()) - h0) < 0.5, `inbox rows height unchanged after deliver and archive (${h0})`);
  await page.screenshot({ path: SHOT + `gmail-archived-${w}.png` });
  ok((await page.$eval(".gx__undo", (e) => e.textContent)).includes("Archived"), "Archived · Put it back (demo) line");
  ok((await page.$eval(T("gm-restore"), (e) => e.textContent.trim())) === "Put it back (demo)", "reset affordance is labelled as a demo, not Undo");
  await click(page, "gm-restore"); await sleep(500);
  ok((await rows(page)).length === 8 && (await notifOpen(page)) && (await count(page)) === "2", "put-it-back restores rows + notification");
  // Delete
  await click(page, "gm-delete"); await sleep(150);
  ok(await page.$eval(".gx__rw.is-struck", () => true).catch(() => false), "delete strikes rows");
  await sleep(800);
  ok((await rows(page)).length === 8 && (await page.$eval(".gx__undo", (e) => e.textContent)).includes("Moved to Trash"), "delete: rows gone, Moved to Trash");
  await click(page, "gm-restore"); await sleep(500);
  ok((await rows(page)).length === 8, "put it back after delete");
  // Spam
  await click(page, "gm-spam"); await sleep(700);
  ok((await rows(page)).length === 8 && (await page.$eval(".gx__undo", (e) => e.textContent)).includes("Reported as spam"), "spam");
  await click(page, "gm-restore"); await sleep(500);
  // Open
  await click(page, "gm-open"); await sleep(500);
  ok(await page.$eval(".gx__row.is-opened", (e) => e === document.querySelector('[data-testid="gm-row"]')).catch(() => false), "open highlights newest counted row");
  ok(!(await notifOpen(page)), "clicking the card opens the message and dismisses the notification");
  ok(await page.$eval('[data-testid="gm-row"]', (e) => e.dataset.unread === "0"), "open marks newest counted row read");
  await click(page, "gm-newmail"); await sleep(500);
  ok(await notifOpen(page), "deliver another brings notification back");
  // Touch targets on mobile
  if (w <= 700) {
    const hts = await page.$$eval(".gx__acts button, .gx__more", (b) => b.map((x) => x.getBoundingClientRect().height));
    ok(hts.every((x) => x >= 43.5), "targets >= 44px");
  }
  await page.close();
}
try {
  await run(1440, 900);
  await run(1280, 900);
  await run(834, 900);
  await run(390, 844);
  // +N more beyond 3
  const p2 = await browser.newPage();
  await p2.setViewport({ width: 1280, height: 900 });
  await p2.goto(BASE + "/", { waitUntil: "networkidle2", timeout: 90000 });
  await p2.$eval("#gmail .gx__mail", (e) => e.scrollIntoView({ block: "center" }));
  await p2.waitForFunction(() => document.querySelector('[data-testid="gm-count"]').textContent.trim() === "3", { timeout: 8000 });
  await click(p2, "gm-newmail"); await sleep(400);
  ok((await p2.$eval(T("gm-subjects"), (e) => e.textContent)).includes("+1 more"), "+1 more beyond 3");
} finally {
  await browser.close();
}
console.log(fails ? `${fails} FAILED` : "all passed");
process.exit(fails ? 1 : 0);
