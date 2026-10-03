import { open, txt, has, click, sleep, ok, done, T } from "./_h.mjs";
const { browser, page } = await open();
const norm = (s) => s.replace(/\u00a0/g, " ");
const attr = (id, a) => page.$eval(T(id), (e, n) => e.getAttribute(n), a);
const cases = {
  badge: ["3", "5", "Rive Community — 5 new", () => txt(page, "wt-val-badge")],
  text: ["Open", "Closed", "Ticket 482 — status changed", () => txt(page, "wt-val-text")],
  count: ["3 items", "4 items", "Rive Community — new reply", () => txt(page, "wt-val-count")],
  appears: ["0", "1", "Studio headphones — Sold out", () => attr("wt-soldout", "data-on")],
  title: ["(0) Inbox", "(3) Inbox", "Inbox — 3 new", () => txt(page, "wt-val-title")],
  subtree: ["0", "1", "Notifications changed", () => attr("wt-val-subtree", "data-on")],
};
ok(!(await has(page, "wt-notif")), "no notification initially");
for (const [s, [b, a, title, read]] of Object.entries(cases)) {
  ok(norm(await read()) === b, `${s}: initial ${b}`);
  await click(page, `wt-row-${s}`); await sleep(1000);
  ok(norm(await read()) === a, `${s}: outcome ${a}`);
  ok((await txt(page, "wt-notif-title")) === title, `${s}: notification "${title}"`);
  ok(await has(page, `wt-reset-${s}`), `${s}: reset offered`);
  await click(page, `wt-reset-${s}`); await sleep(1000);
  ok(norm(await read()) === b && !(await has(page, "wt-notif")), `${s}: reset restores, notification cleared`);
}
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
