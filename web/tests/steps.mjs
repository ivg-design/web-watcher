import { open, T, txt, click, sleep, ok, done } from "./_h.mjs";
const { browser, page } = await open();
await page.$eval("#how-it-works", (e) => e.scrollIntoView({ block: "center" }));
await sleep(500);
const rect = (id) => page.$eval(T(id), (e) => { const r = e.getBoundingClientRect(); return [r.x, r.y, r.width, r.height].map(Math.round); });
const cur = (i) => page.$eval(T(`hw-step-${i}`), (e) => e.getAttribute("aria-current") === "step");

ok(await cur(1), "step 1 active on entry");
ok((await txt(page, "hw-sheet")).includes("Found in Safari: Inbox · Contra"), "sheet: Found in Safari");
ok((await page.$eval(T("hw-stage"), (e) => e.textContent)).includes("contra.com/inbox"), "URL field text");

// auto-advance
await sleep(4200);
ok(await cur(2), "auto-advance 1 -> 2 within ~4 s");

// step 2
await click(page, "hw-step-2");
await sleep(300);
const a = await rect("hw-outline");
const tb = await page.$eval(T("hw-toolbar"), (e) => ({ t: e.textContent, o: getComputedStyle(e).opacity, bg: getComputedStyle(e).backgroundColor }));
await sleep(1300);
const b = await rect("hw-outline");
ok(tb.t.includes("← → siblings · ↑ parent · ↓ child · ⏎ use · ⎋ cancel"), "toolbar exact text");
ok(tb.bg === "rgb(30, 31, 39)", "toolbar #1e1f27");
ok(+tb.o > 0.9, "toolbar visible");
ok(JSON.stringify(a) !== JSON.stringify(b), `outline moved ${a} -> ${b}`);
await sleep(1500);
ok((await txt(page, "hw-sheet")).includes("Watching: badge count · 2"), "sheet: Watching badge count");
ok(await page.$eval(T("hw-outline"), (e) => getComputedStyle(e).outlineColor) === "rgb(34, 197, 94)", "outline locked green");

// step 3
await click(page, "hw-step-3");
await sleep(1800);
ok((await txt(page, "hw-notif")).includes("Contra — 3 new") && (await txt(page, "hw-notif")).includes("Inbox badge went 2 → 3"), "notification text");
ok((await txt(page, "hw-badge")) === "3", "badge 3");
ok((await txt(page, "hw-sheet")).includes("Contra · Inbox badge"), "popover row");

for (const w of [1440, 390]) {
  await page.setViewport({ width: w, height: 900 });
  await sleep(500);
  const ov = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth);
  ok(ov <= 0, `no horizontal overflow at ${w} (${ov})`);
  await page.$eval("#how-it-works", (e) => e.scrollIntoView({ block: "start" }));
  await sleep(300);
  if (w === 390) {
    const [sx, sy] = [await rect("hw-stage"), await rect("hw-step-1")];
    ok(sx[1] < sy[1], "mobile: stage above steps");
    ok(sx[2] <= 390, "mobile: stage fits");
  }
  await page.screenshot({ path: `/private/tmp/claude-501/-Users-ivg-github-web-watcher/1b5c3420-5ad4-4c49-88f4-04aad1e374ed/scratchpad/steps-${w}.png` });
}
await done(browser);
