import { open, txt, has, click, sleep, ok, done, T } from "./_h.mjs";
const { browser, page } = await open();
const norm = (s) => s.replace(/\u00a0/g, " ");
const attr = (id, a) => page.$eval(T(id), (e, n) => e.getAttribute(n), a);
const cases = {
  badge: ["3", "5", "Rive Community bell", "You have 5 new messages", () => txt(page, "wt-val-badge")],
  count: ["3 items", "4 items", "Rive Community thread", "1 new item (4 total)", () => txt(page, "wt-val-count")],
  text: ["Open", "Closed", "Ticket 482 status", "Content updated", () => txt(page, "wt-val-text")],
  exists: ["0", "1", "Studio headphones label", "Element appeared", () => attr("wt-soldout", "data-on")],
  disappears: ["1", "0", "Waitlist button", "Element disappeared", () => attr("wt-joinbtn", "data-on")],
  subtree: ["0", "1", "Notifications bell", "Something changed inside the watched area", () => attr("wt-val-subtree", "data-on")],
};
ok(!(await has(page, "wt-notif")), "no notification initially");
for (const [s, [b, a, title, body, read]] of Object.entries(cases)) {
  ok(norm(await read()) === b, `${s}: initial ${b}`);
  await click(page, `wt-row-${s}`); await sleep(1000);
  ok(norm(await read()) === a, `${s}: outcome ${a}`);
  ok((await txt(page, "wt-notif-title")) === title, `${s}: notification "${title}"`);
  ok((await txt(page, "wt-notif-body")) === body, `${s}: body "${body}"`);
  ok(!/went|→/.test(await txt(page, "wt-notif")), `${s}: no invented "went/→" text`);
  ok(await has(page, `wt-reset-${s}`), `${s}: reset offered`);
  await click(page, `wt-reset-${s}`); await sleep(1000);
  ok(norm(await read()) === b && !(await has(page, "wt-notif")), `${s}: reset restores, notification cleared`);
}
// text change shows the new text as a subtitle
await click(page, "wt-row-text"); await sleep(900);
ok((await txt(page, "wt-notif-sub")) === "Closed", "text: subtitle is the new text");
await click(page, "wt-reset-text"); await sleep(600);
// no "Document title" row; six real types, named as in the app
const names = await page.$$eval(".wt-row__name", (els) => els.map((e) => e.textContent));
ok(names.join("|") === "Badge/Number|Element Count|Text Change|Element Exists|Element Disappears|Anything Changes Inside", `six real type names (${names})`);
ok(!(await has(page, "wt-row-title")), "no Document title row");
ok((await page.$eval(".wt-slot [aria-live]", (e) => e.textContent.trim())) === "", "live region empty before any click");
// 1440: example is the hero (stage >= 96px)
await page.setViewport({ width: 1440, height: 900 }); await sleep(300);
const sh = await page.$$eval(".wt-stage", (els) => Math.min(...els.map((e) => e.getBoundingClientRect().height)));
ok(sh >= 96, `1440: stage >= 96px (${Math.round(sh)})`);
// keyboard
await page.$eval(T("wt-row-badge"), (e) => { e.scrollIntoView({ block: "center" }); e.focus(); });
await page.keyboard.press("Enter"); await sleep(1000);
ok((await txt(page, "wt-val-badge")) === "5", "Enter plays");
// 390 overflow
await page.setViewport({ width: 390, height: 800 }); await sleep(300);
const ov = await page.evaluate(() => document.querySelector("#watch-types").scrollWidth - innerWidth);
ok(ov <= 0, `390: no horizontal overflow (${ov})`);
const small = await page.$$eval(".wt-row__btn", (els) => els.filter((e) => e.getBoundingClientRect().height < 44).length);
ok(small === 0, "390: rows >= 44px");
await done(browser);
