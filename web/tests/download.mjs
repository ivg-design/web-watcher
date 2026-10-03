import { BASE, T, txt, sleep, ok, done } from "./_h.mjs";
import puppeteer from "puppeteer-core";

const browser = await puppeteer.launch({ executablePath: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome", headless: "new" });
const page = await browser.newPage();
await page.setViewport({ width: 1280, height: 900 });
await page.setRequestInterception(true);
page.on("request", (r) => (/\.dmg(\?|$)/.test(r.url()) ? r.respond({ status: 200, headers: { "content-disposition": "attachment; filename=x.dmg" }, body: "x" }) : r.continue()));
await page.goto(BASE + "/", { waitUntil: "networkidle2", timeout: 90000 });
await page.evaluate(() => window.scrollTo(0, 0));

// diagram order
await page.$eval(T("pv-diagram"), (e) => e.scrollIntoView({ block: "center" }));
const order = await page.$$eval('[data-testid^="pv-node-"]', (els) => els.map((e) => e.getAttribute("data-testid")));
ok(order.slice(0, 3).join() === "pv-node-1,pv-node-2,pv-node-3", "diagram nodes in order " + order.join());
const xs = await page.$$eval('[data-testid="pv-node-1"],[data-testid="pv-node-2"],[data-testid="pv-node-3"]', (els) => els.map((e) => e.getBoundingClientRect().left));
ok(xs[0] < xs[1] && xs[1] < xs[2], "nodes laid out left to right");

// switches
ok(!(await page.$(T("pv-ready"))), "ready hidden initially");
for (let i = 1; i <= 3; i++) {
  await page.$eval(T("pv-switch-" + i), (e) => e.scrollIntoView({ block: "center" }));
  await page.click(T("pv-switch-" + i));
  const c = await page.$eval(T("pv-switch-" + i), (e) => e.getAttribute("aria-checked"));
  ok(c === "true", "switch " + i + " on");
  if (i < 3) ok(!(await page.$(T("pv-ready"))), "ready not yet after " + i);
}
await page.waitForSelector(T("pv-ready"), { timeout: 3000 });
ok(/Ready/.test(await txt(page, "pv-ready")), "ready line shown");
ok(!!(await page.$('[data-testid="pv-ready"] a[href$="/docs/first-watcher"]')), "ready links to first-watcher");

// download button
await page.$eval(T("dl-btn"), (e) => e.scrollIntoView({ block: "center" }));
const before = await txt(page, "dl-btn");
ok(/^Download for Mac · DMG · \d+ MB$/.test(before), "button label: " + before);
await page.click(T("dl-btn")).catch(() => {});
await sleep(250);
ok((await txt(page, "dl-btn")) === "Starting download…", "label Starting download…");
await sleep(1300);
ok((await txt(page, "dl-btn")) === before, "label returns");

// sha
await page.browserContext().overridePermissions(BASE, ["clipboard-read", "clipboard-write"]);
if (await page.$(T("dl-sha"))) {
  await page.click(T("dl-sha"));
  await sleep(200);
  ok(/Copied/.test(await txt(page, "dl-sha")), "SHA shows Copied: " + (await txt(page, "dl-sha")));
  await sleep(1800);
  ok(/Copy SHA/.test(await txt(page, "dl-sha")), "SHA copy label returns");
} else ok(false, "dl-sha present");

// mobile
await page.setViewport({ width: 390, height: 844, isMobile: true, deviceScaleFactor: 2 });
await page.reload({ waitUntil: "networkidle2" });
const over = await page.evaluate(() => [...document.querySelectorAll("#privacy *, #download *, #changelog *, footer *")].filter((e) => e.getBoundingClientRect().right > 390.5 && getComputedStyle(e).position !== "fixed").map((e) => e.className).slice(0, 5));
ok(over.length === 0, "390 no overflow in privacy/download/changelog/footer " + over.join());
const small = await page.$$eval('[data-testid^="pv-switch-"],[data-testid="dl-btn"],[data-testid="dl-sha"],.footer li a', (els) => els.filter((e) => e.getBoundingClientRect().height < 43).length);
ok(small === 0, "mobile targets >= 44px (" + small + " small)");
const ys = await page.$$eval('[data-testid="pv-node-1"],[data-testid="pv-node-2"],[data-testid="pv-node-3"]', (els) => els.map((e) => e.getBoundingClientRect().top));
ok(ys[0] < ys[1] && ys[1] < ys[2], "diagram stacks vertically");
await done(browser);
