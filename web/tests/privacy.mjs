import { T, txt, sleep, ok, done } from "./_h.mjs";
import puppeteer from "puppeteer-core";
const BASE = process.env.BASE || "http://localhost:3101";
const browser = await puppeteer.launch({ executablePath: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome", headless: "new" });
try {
  for (const [w, h] of [[1440, 900], [390, 844]]) {
    const page = await browser.newPage();
    await page.setViewport({ width: w, height: h, isMobile: w < 500, deviceScaleFactor: 1 });
    await page.goto(BASE + "/", { waitUntil: "networkidle2", timeout: 90000 });
    const tag = w + "px ";
    ok(!!(await page.$(T("pv-diagram"))), tag + "diagram present");
    ok(!!(await page.$("#privacy h2.h2-v3")), tag + "title uses h2-v3");
    for (const n of ["1", "2", "3", "gmail", "net"]) ok(!!(await page.$(T("pv-node-" + n))), tag + "node " + n);
    ok(!(await page.$(T("pv-ready"))), tag + "ready hidden");
    ok(!!(await page.$(T("pv-zeros"))), tag + "zeros row present");
    await page.$eval(T("pv-zeros"), (e) => e.scrollIntoView({ block: "center" }));
    await sleep(3000);
    const zs = await page.$$eval('[data-testid^="pv-zero-"]', (els) => els.map((e) => [e.querySelector(".pvz__n").textContent, e.querySelector(".pvz__l").textContent]));
    ok(zs.length === 3 && zs.every((z) => z[0] === "(0)"), tag + "three numerals end at (0): " + JSON.stringify(zs.map((z) => z[0])));
    ok(zs.map((z) => z[1]).join("|") === "servers|analytics|data collected", tag + "zero labels exact");
    ok(!(await page.$eval(T("pv-zero-1"), (e) => getComputedStyle(e.querySelector(".pvz__n")).color === getComputedStyle(document.documentElement).getPropertyValue("--n-signal"))), tag + "zeros not red");
    for (let i = 1; i <= 3; i++) {
      await page.$eval(T("pv-switch-" + i), (e) => e.scrollIntoView({ block: "center" }));
      await page.click(T("pv-switch-" + i));
      ok((await page.$eval(T("pv-switch-" + i), (e) => e.getAttribute("aria-checked"))) === "true", tag + "switch " + i + " on");
    }
    await page.waitForSelector(T("pv-ready"), { timeout: 3000 });
    ok(/^Ready\. Add your first watcher/.test(await txt(page, "pv-ready")), tag + "ready text");
    await page.click(T("pv-switch-2"));
    await sleep(100);
    ok(!(await page.$(T("pv-ready"))), tag + "ready hides when a switch goes off");
    await page.click(T("pv-switch-2"));
    const over = await page.evaluate((W) => [...document.querySelectorAll("#privacy *")].filter((e) => e.getBoundingClientRect().right > W + 0.5).map((e) => e.className).slice(0, 5), w);
    ok(over.length === 0, tag + "no overflow " + over.join());
    await page.close();
  }
  const rp = await browser.newPage();
  await rp.setViewport({ width: 390, height: 844, isMobile: true });
  await rp.emulateMediaFeatures([{ name: "prefers-reduced-motion", value: "reduce" }]);
  await rp.goto(BASE + "/", { waitUntil: "networkidle2", timeout: 90000 });
  await rp.$eval(T("pv-zeros"), (e) => e.scrollIntoView({ block: "center" }));
  await sleep(300);
  const rz = await rp.$$eval(".pvz__n", (els) => els.map((e) => e.textContent));
  ok(rz.length === 3 && rz.every((z) => z === "(0)"), "reduced motion: numerals read (0) at 300 ms");
  await rp.close();
} finally { await done(browser); }
