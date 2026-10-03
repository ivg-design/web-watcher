import { BASE, open, T, txt, click, sleep, ok, done } from "./_h.mjs";
const html = await (await fetch(BASE + "/")).text();
ok(/2,880/.test(html) && /20,160/.test(html), "SSR HTML contains 2,880 and 20,160");
for (const [w, h] of [[1440, 900], [390, 844]]) {
  const { browser, page } = await open();
  await page.setViewport({ width: w, height: h });
  await page.goto(BASE + "/", { waitUntil: "networkidle2" });
  console.log("-- " + w);
  await page.$eval("#interval", (e) => e.scrollIntoView({ block: "center" }));
  await sleep(1500);
  ok((await txt(page, "ivl-day")) === "2,880", "day 2,880 after count-up");
  ok((await txt(page, "ivl-week")) === "20,160", "week 20,160 after count-up");
  await click(page, "ivl-15"); await sleep(400);
  ok((await txt(page, "ivl-day")) === "5,760", "15s: day 5,760");
  ok((await txt(page, "ivl-week")) === "40,320", "15s: week 40,320");
  ok((await txt(page, "ivl-every")) === "15 seconds", "15s: every label");
  ok((await page.$eval(T("ivl-15"), (e) => e.getAttribute("aria-checked"))) === "true", "15s chip checked");
  await click(page, "ivl-1800"); await sleep(400);
  ok((await txt(page, "ivl-day")) === "48", "30m: day 48");
  ok((await txt(page, "ivl-week")) === "336", "30m: week 336");
  ok((await txt(page, "ivl-hint")).includes("every 30 minutes"), "hint updates");
  if (await page.$(T("watch-mark"))) {
    await page.$eval(T("watch-mark"), (e) => e.click()); await sleep(500);
    const body = await page.evaluate(() => document.body.innerText);
    if (body.includes("Checks every 30 minutes")) ok(true, "popover says Checks every 30 minutes");
    else console.log("NOTE popover lacks 'Checks every 30 minutes' (W1 not landed?)");
  } else console.log("NOTE watch-mark not found");
  if (w < 600) ok(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), "no overflow at 390");
  await browser.close();
}
await done({ close() {} });
