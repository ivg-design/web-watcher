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
} finally { await done(browser); }
