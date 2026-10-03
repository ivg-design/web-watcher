import { open, T, txt, has, click, sleep, ok, done } from "./_h.mjs";
const { browser, page } = await open();
await page.$eval("#how-it-works", (e) => e.scrollIntoView({ block: "center" }));
await sleep(500);
const rect = (id) => page.$eval(T(id), (e) => { const r = e.getBoundingClientRect(); return [r.x, r.y, r.width, r.height].map(Math.round); });
const cur = (i) => page.$eval(T(`hw-step-${i}`), (e) => e.getAttribute("aria-current") === "step");

ok(await cur(1), "step 1 active on entry");
ok((await txt(page, "hw-sheet")).includes("Found in Safari: Inbox · Contra"), "sheet: Found in Safari");
ok((await page.$eval(T("hw-stage"), (e) => e.textContent)).includes("contra.com/inbox"), "URL field text");

// timecode, chapters, stage width
const clk = () => txt(page, "hw-clock");
const c1 = await clk(); await sleep(600); const c2 = await clk();
ok(/^\d\d\.\d$/.test(c1) && /^\d\d\.\d$/.test(c2) && c1 !== c2, `timecode advances ${c1} -> ${c2}`);
const [r1, r2, r3] = [await rect("hw-step-1"), await rect("hw-step-2"), await rect("hw-step-3")];
ok(r2[2] > r1[2] && r2[2] > r3[2] && r3[2] > r1[2], `chapter widths proportional ${r1[2]} ${r2[2]} ${r3[2]}`);
ok(Math.abs(r1[1] - r2[1]) < 2 && Math.abs(r2[1] - r3[1]) < 2, "chapters share one row");
ok((await rect("hw-stage"))[2] >= 1000, "stage at least 1000 px wide at 1280");
ok(!(await has(page, "hw-notified")), "no red tick before the notification");

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
const nt = await txt(page, "hw-notif");
ok(nt.includes("Contra") && nt.includes("You have 3 new messages") && !nt.includes("went"), "notification: title Contra, real body");
ok(await page.$eval(T("hw-newmail"), (e) => e.classList.contains("unread")), "beat 3: the new mail row turns bold");
ok((await page.$$eval(".hw-thread", (e) => e.length)) === 4, "four mails in the inbox");
ok((await txt(page, "hw-badge")) === "3", "badge 3");
ok(await has(page, "hw-notified"), "red tick label appears after the notification");
const nc = await page.$eval(T("hw-notified"), (e) => { const c = document.createElement("canvas"); c.width = c.height = 1; const g = c.getContext("2d"); g.fillStyle = getComputedStyle(e).color; g.fillRect(0, 0, 1, 1); return "rgb(" + [...g.getImageData(0, 0, 1, 1).data].slice(0, 3).join(",") + ")"; });
const [nr, ng, nb] = nc.match(/[\d.]+/g).map(Number);
ok(nr > 150 && ng < 140 && nb < 140, "notified label is red " + nc);
ok((await txt(page, "hw-notified")) === "t+8.5 s notified", "notified label text");
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
    const strip = await page.$$eval(".hw-steps li", (els) => els.map((e) => Math.round(e.getBoundingClientRect().y)));
    ok(strip[0] < strip[1] && strip[1] < strip[2], "mobile: ruler is three stacked rows");
    const ts = await page.$$eval('[data-testid^="hw-time-"]', (e) => e.map((x) => x.textContent.trim()));
    ok(ts.join("|") === "t+0.0 s|t+3.2 s|t+7.6 s", "ruler timestamps " + ts.join(" "));
    ok((await rect("hw-step-1"))[3] >= 44, "mobile: step targets >= 44px");
  }
  await page.screenshot({ path: `/private/tmp/claude-501/-Users-ivg-github-web-watcher/1b5c3420-5ad4-4c49-88f4-04aad1e374ed/scratchpad/steps-${w}.png` });
}
// reduced motion: final state
await browser.close().catch(() => {});
{
  const o = await open(null, true);
  await o.page.$eval("#how-it-works", (e) => e.scrollIntoView({ block: "center" }));
  await sleep(800);
  ok((await o.page.$eval(T("hw-clock"), (e) => e.textContent.trim())) === "11.2", "reduced motion: clock shows 11.2");
  ok(await has(o.page, "hw-notified"), "reduced motion: red tick present");
  await done(o.browser);
}
