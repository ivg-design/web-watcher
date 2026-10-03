import puppeteer from "puppeteer-core";
export const BASE = process.env.BASE || "http://localhost:3201";
export async function open(sel, reduce = false) {
  const browser = await puppeteer.launch({ executablePath: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome", headless: "new" });
  const page = await browser.newPage();
  await page.setViewport({ width: 1280, height: 900 });
  if (reduce) await page.emulateMediaFeatures([{ name: "prefers-reduced-motion", value: "reduce" }]);
  await page.goto(BASE + "/", { waitUntil: "networkidle2", timeout: 90000 });
  return { browser, page };
}
export const T = (id) => `[data-testid="${id}"]`;
export const txt = (page, id) => page.$eval(T(id), (e) => e.textContent.trim());
export const has = async (page, id) => !!(await page.$(T(id)));
export const click = async (page, id) => { await page.$eval(T(id), (e) => e.scrollIntoView({ block: "center" })); await page.click(T(id)); };
export const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
let fails = 0;
export const ok = (c, m) => { console.log((c ? "PASS " : "FAIL ") + m); if (!c) fails++; };
export const done = async (browser) => { await browser.close(); process.exit(fails ? 1 : 0); };
