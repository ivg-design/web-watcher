import { open, T, txt, has, click, sleep, ok, done } from "./_h.mjs";
const { browser, page } = await open();
const exp = { badge: ["3", "5", "Rive Community — 5 new"], text: ["“Open”", "“Closed”", "Status changed"], subtree: ["48 items", "51 items", "Notifications changed"], title: ["(0)", "(3)", "Inbox changed"], aria: ["1 new", "2 new", "Rive Community — 2 new"] };
for (const [s, [b, a, title]] of Object.entries(exp)) {
  ok((await txt(page, `wt-val-${s}`)) === b && !(await has(page, `wt-notif-${s}`)), `${s}: initial ${b}, no notif`);
  await click(page, `wt-play-${s}`); await sleep(900);
  ok((await txt(page, `wt-val-${s}`)) === a, `${s}: value -> ${a}`);
  ok((await txt(page, `wt-notif-${s}`)).includes(title), `${s}: notification`);
  ok(await has(page, `wt-replay-${s}`), `${s}: replay offered`);
}
await click(page, "wt-replay-badge"); await sleep(150);
ok((await txt(page, "wt-val-badge")) === "3", "replay resets");
await sleep(1000);
ok((await txt(page, "wt-val-badge")) === "5" && (await has(page, "wt-notif-badge")), "replay reruns");
ok(await has(page, "wt-notif-aria"), "rows independent");
await done(browser);
