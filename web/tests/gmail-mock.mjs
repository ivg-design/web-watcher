import puppeteer from "puppeteer-core";
import { T, sleep } from "./_h.mjs";
const SHOT = "/private/tmp/claude-501/-Users-ivg-github-web-watcher/1b5c3420-5ad4-4c49-88f4-04aad1e374ed/scratchpad/w6/";
const BASE = process.env.BASE || "http://localhost:3101";
const SEL = "#gmail .gx, #gmail .gx__mail, #gmail .gx__notif, #gmail .gx__more, #gmail .gx__acts button";
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
  ok((await rows(page)).length === 2 && !(await notifOpen(page)), "before view: 2 seed mails, no notification");
  await page.$eval("#gmail .gx", (e) => e.scrollIntoView({ block: "center" }));
  await page.waitForFunction(() => document.querySelectorAll('[data-testid="gm-row"]').length === 5, { timeout: 8000 });
  await sleep(500);
  ok((await count(page)) === "3", "three arrivals -> count 3");
  const r = await rows(page);
  ok(r.slice(0, 3).every((x) => x.rive && x.unread), "rive rows on top, unread");
  const subj = await page.$eval(T("gm-subjects"), (e) => e.textContent.trim());
  ok(subj.startsWith("Release notes") && subj.includes("Office hours") && subj.includes("Scripting update") && subj.includes(" · "), "subjects joined with ·: " + subj);
  const title = await page.$eval(".gx__nt strong", (e) => e.textContent);
  ok(title === "3 new from Rive team", "title " + title);
  // geometry: the notification sits above the inbox with a 12 px gap (offset right on desktop) and never covers the header
  const g = await page.evaluate(() => {
    const n = document.querySelector('[data-testid="gm-notif"]').getBoundingClientRect();
    const m = document.querySelector(".gx__mail").getBoundingClientRect();
    const bar = document.querySelector(".gx__bar").getBoundingClientRect();
    const lab = document.querySelector(".gx__label").getBoundingClientRect();
    const hit = document.elementFromPoint(lab.left + lab.width / 2, lab.top + lab.height / 2);
    return { nt: n.top, nb: n.bottom, nl: n.left, nr: n.right, mt: m.top, ml: m.left, gap: m.top - n.bottom, barOk: !!hit && !!hit.closest(".gx__bar"), barTop: bar.top, sw: document.documentElement.scrollWidth, iw: innerWidth };
  });
  ok(g.sw <= g.iw, `no horizontal page overflow (${g.sw} <= ${g.iw})`);
  ok(g.gap >= 10 && g.gap <= 14, `notification sits above the inbox with a 12px gap (${Math.round(g.gap)})`);
  ok(g.barOk, "inbox header (Inbox · Watching @rive.app) is not covered by the notification");
  if (w > 960) ok(g.nl > g.ml, "notification is offset to the right of the inbox");
  else ok(g.nt >= 0 && g.nl >= 0 && g.nr <= g.iw, "notification fully visible");
  ok((await page.$eval(".gx", (e) => e.getAttribute("aria-live"))) === "off", "stage aria-live=off");
  ok((await page.$$eval(".gx [role=status]", (e) => e.length)) === 1, "only one role=status inside the stage (the inbox header line)");
  ok((await page.$eval(T("gm-open"), (e) => e.getAttribute("aria-label"))) === "Open the newest message", "notification card is the Open control (aria-label)");
  ok((await page.$$eval(".gx__acts button", (b) => b.map((x) => x.textContent.trim()))).join("|") === "Mark as Read|Archive|Delete|Spam", "actions are exactly Mark as Read, Archive, Delete, Spam (no Open button)");
  ok(await page.evaluate((s) => [...document.querySelectorAll(s)].every((e) => e.getBoundingClientRect().right <= innerWidth + 1), SEL), "no overflow in section");
  const fig = await page.evaluate(() => {
    const i = document.querySelector('[data-testid="gm-figure"] img').getBoundingClientRect();
    const f = document.querySelector(".gmail__frame");
    const cs = getComputedStyle(f);
    const demo = getComputedStyle(document.querySelector(".gx"));
    const h2 = document.querySelector("#gmail h2");
    return { iw: i.width, pad: cs.paddingLeft, rad: cs.borderRadius, bg: cs.backgroundImage.includes("linear-gradient"), panelBorder: demo.borderTopWidth, panelRad: demo.borderRadius, h2: h2.className, h2t: h2.textContent, eyebrow: !!document.querySelector("#gmail .eyebrow"), cap: document.querySelector('[data-testid="gm-figure"] figcaption').textContent, tab: getComputedStyle(document.querySelector('[data-testid="gm-count"]')).fontVariantNumeric };
  });
  ok(fig.h2.includes("h2-v3") && fig.h2t === "Watch a sender, not an inbox." && !fig.eyebrow, "h2-v3 title, no eyebrow");
  ok(fig.bg && fig.pad === (w > 700 ? "40px" : "20px") && fig.rad === "16px", `figure frame: gradient, padding ${fig.pad}, radius ${fig.rad}`);
  if (w >= 1440) ok(fig.iw >= 440, "figure image width >= 440 (" + Math.round(fig.iw) + ")");
  ok(fig.cap === "The sender watcher editor in WebWatcher 1.10.9.", "caption: " + fig.cap);
  ok(fig.panelBorder === "1px" && fig.panelRad === "16px", "demo on a hairline panel, radius 16");
  ok(fig.tab.includes("tabular"), "unread count is tabular");
  await page.screenshot({ path: SHOT + `gmail-arrived-${w}.png` });
  // Mark as Read: rows un-bold in a stagger, count rolls to 0, the card folds away, header says so and then fades
  await click(page, "gm-markread"); await sleep(250);
  ok((await rows(page)).some((x) => !x.unread), "mark read starts un-bolding rows");
  await sleep(600);
  ok((await rows(page)).every((x) => !x.unread), "mark read un-bolds all");
  ok((await count(page)) === "0", "count rolls to 0");
  ok(!(await notifOpen(page)), "notification folds away at 0 unread");
  ok((await page.$eval(T("gm-status"), (e) => e.textContent.trim())) === "Nothing unread from @rive.app — notification cleared", "header status line: nothing unread, notification cleared");
  ok(!(await page.evaluate(() => document.body.innerText.includes("Nothing left to read") || document.body.innerText.includes("All read"))), "no invented All read notification");
  await sleep(3400);
  ok((await page.$eval(T("gm-status"), (e) => e.textContent.trim())) === "Watching @rive.app", "status line fades back to Watching @rive.app");
  // Deliver another after collapse
  await click(page, "gm-newmail"); await sleep(500);
  ok((await count(page)) === "1" && (await rows(page)).length === 6, "deliver another: count 1, 6 rows");
  await click(page, "gm-newmail"); await sleep(400);
  ok((await count(page)) === "2", "count 2");
  // Archive
  await click(page, "gm-archive"); await sleep(700);
  ok((await rows(page)).length === 5 && !(await notifOpen(page)), "archive removes counted rows, notification dismissed");
  await page.screenshot({ path: SHOT + `gmail-archived-${w}.png` });
  ok((await page.$eval(".gx__undo", (e) => e.textContent)).includes("Archived"), "Archived · Put it back (demo) line");
  ok((await page.$eval(T("gm-restore"), (e) => e.textContent.trim())) === "Put it back (demo)", "reset affordance is labelled as a demo, not Undo");
  await click(page, "gm-restore"); await sleep(500);
  ok((await rows(page)).length === 7 && (await notifOpen(page)) && (await count(page)) === "2", "put-it-back restores rows + notification");
  // Delete
  await click(page, "gm-delete"); await sleep(150);
  ok(await page.$eval(".gx__rw.is-struck", () => true).catch(() => false), "delete strikes rows");
  await sleep(800);
  ok((await rows(page)).length === 5 && (await page.$eval(".gx__undo", (e) => e.textContent)).includes("Moved to Trash"), "delete: rows gone, Moved to Trash");
  await click(page, "gm-restore"); await sleep(500);
  ok((await rows(page)).length === 7, "put it back after delete");
  // Spam
  await click(page, "gm-spam"); await sleep(700);
  ok((await rows(page)).length === 5 && (await page.$eval(".gx__undo", (e) => e.textContent)).includes("Reported as spam"), "spam");
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
  await run(390, 844);
  // +N more beyond 3
  const p2 = await browser.newPage();
  await p2.setViewport({ width: 1280, height: 900 });
  await p2.goto(BASE + "/", { waitUntil: "networkidle2", timeout: 90000 });
  await p2.$eval("#gmail .gx", (e) => e.scrollIntoView({ block: "center" }));
  await p2.waitForFunction(() => document.querySelectorAll('[data-testid="gm-row"]').length === 5, { timeout: 8000 });
  await click(p2, "gm-newmail"); await sleep(400);
  ok((await p2.$eval(T("gm-subjects"), (e) => e.textContent)).includes("+1 more"), "+1 more beyond 3");
} finally {
  await browser.close();
}
console.log(fails ? `${fails} FAILED` : "all passed");
process.exit(fails ? 1 : 0);
