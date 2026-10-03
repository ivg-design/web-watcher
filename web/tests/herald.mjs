import puppeteer from "puppeteer-core";
import { T, sleep, ok } from "./_h.mjs";
const BASE = process.env.BASE || "http://localhost:3101";
const SEL = "#herald *";
const browser = await puppeteer.launch({ executablePath: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome", headless: "new" });
const has = async (p, id) => !!(await p.$(T(id)));
const click = async (p, id) => { await p.$eval(T(id), (e) => e.scrollIntoView({ block: "center" })); await p.$eval(T(id), (e) => e.click()); };

async function run(w, h) {
  console.log(`--- ${w}x${h}`);
  const page = await browser.newPage();
  await page.evaluateOnNewDocument(() => {
    window.__spoken = [];
    window.SpeechSynthesisUtterance = function (t) { this.text = t; };
    Object.defineProperty(window, "speechSynthesis", { configurable: true, value: { speak: (u) => window.__spoken.push(u.text), cancel() {} } });
  });
  await page.setViewport({ width: w, height: h });
  await page.goto(BASE + "/", { waitUntil: "networkidle2", timeout: 90000 });
  ok(!(await has(page, "hb-banner")), "no banner before the stage is in view");
  await page.$eval("#herald .hx", (e) => e.scrollIntoView({ block: "center" }));
  await page.waitForSelector(T("hb-banner"), { timeout: 5000 });
  ok(true, "banner enters on view");
  await sleep(500);
  const t = await page.$eval(T("hb-banner"), (e) => e.textContent);
  ok(t.includes("3 new from Rive team") && t.includes("WebWatcher · Email") && t.includes("now") && t.includes("Scripting update · Office hours · Release notes"), "banner content");
  const g = await page.evaluate(() => {
    const b = document.querySelector('[data-testid="hb-banner"]').getBoundingClientRect();
    const s = document.querySelector(".hx").getBoundingClientRect();
    return { bl: b.left, br: b.right, bb: b.bottom, sl: s.left, sr: s.right, sb: s.bottom, sw: document.documentElement.scrollWidth, iw: innerWidth, ratio: s.width / s.height };
  });
  ok(g.br <= g.sr + 1 && g.bl >= g.sl - 1 && g.bb <= g.sb + 1, "banner inside stage");
  ok(await page.evaluate((s) => [...document.querySelectorAll(s)].every((e) => e.getBoundingClientRect().right <= innerWidth + 1), SEL), "no overflow in section");
  if (w > 900) ok(Math.abs(g.ratio - 1.6) < 0.02, "stage 16:10");
  if (w > 900) ok(g.bl > g.sl + 100, "banner at the right side"); else ok(g.br - g.bl > g.sr - g.sl - 24, "banner full width of stage");
  await sleep(1500);
  ok(await has(page, "hb-banner"), "banner stays");
  // tooltip
  if (w > 900) {
    await page.hover(T("hb-snooze")); await sleep(300);
    ok(await page.$eval(".hx__tip", (e) => getComputedStyle(e).opacity === "1" && e.textContent === "returns at 9:00"), "snooze tooltip");
  }
  // speak
  await click(page, "hb-speak");
  ok(await page.$eval(T("hb-speak"), (e) => e.dataset.speaking === "1" && e.textContent.includes("reading aloud")), "speak -> reading aloud");
  ok((await page.evaluate(() => window.__spoken[0])) === "3 new from Rive team. Scripting update, office hours, release notes.", "utterance text");
  await click(page, "hb-speak");
  ok(await page.$eval(T("hb-speak"), (e) => e.dataset.speaking === "0"), "speak toggles off");
  // snooze
  await click(page, "hb-snooze"); await sleep(500);
  ok(!(await has(page, "hb-banner")) && (await page.$eval(T("hb-returns"), (e) => e.textContent)).includes("returns at 9:00"), "snooze hides banner + label");
  await sleep(3200);
  ok((await has(page, "hb-banner")) && !(await has(page, "hb-returns")), "banner returns after 3s");
  for (const b of ["hb-open", "hb-read", "hb-archive", "hb-close"]) {
    await click(page, b); await sleep(500);
    ok(!(await has(page, "hb-banner")) && (await has(page, "hb-show")), `${b} dismisses`);
    if (b !== "hb-close") ok((await page.$eval(".hx__note", (e) => e.textContent)).includes("Done — Herald told WebWatcher, which told Gmail"), "done line");
    await click(page, "hb-show"); await sleep(400);
    ok(await has(page, "hb-banner"), "show again");
  }
  if (w <= 900) {
    const hts = await page.$$eval(".hx__pill, .hx__x, .hx__speak", (b) => b.map((x) => x.getBoundingClientRect().height));
    ok(hts.every((x) => x >= 43.5), "targets >= 44px");
  }
  await page.close();
}
await run(1280, 900);
await run(390, 844);
await browser.close();
process.exit(0);
