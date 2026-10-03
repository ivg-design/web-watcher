import { open, txt, has, click, sleep, ok, done } from "./_h.mjs";
const { browser, page } = await open();
ok(await has(page, "hb-banner"), "banner visible");
await click(page, "hb-snooze"); await sleep(600);
ok(!(await has(page, "hb-banner")), "snooze hides banner");
ok((await txt(page, "hb-returns")).includes("returns at 9:00"), "returns label");
await sleep(3200);
ok(await has(page, "hb-banner"), "banner returns after ~3s");
ok(!(await has(page, "hb-returns")), "label gone");
for (const b of ["hb-open", "hb-read", "hb-archive"]) {
  await click(page, b); await sleep(600);
  ok(!(await has(page, "hb-banner")) && (await has(page, "hb-show")), `${b} dismisses`);
  await click(page, "hb-show"); await sleep(100);
  ok(await has(page, "hb-banner"), "show again");
}
await done(browser);
