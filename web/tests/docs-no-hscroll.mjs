// No horizontal scrolling anywhere in the docs or the changelog (owner rule).
// Usage: BASE=http://localhost:3286 node tests/docs-no-hscroll.mjs [--landing]   (--landing only reports, never fails)
import puppeteer from "puppeteer-core";
const BASE = process.env.BASE || "http://localhost:3286";
const CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
const landing = process.argv.includes("--landing");
const WIDTHS = landing ? [1440, 1280, 834, 390] : [1440, 1280, 1024, 834, 390];
const b = await puppeteer.launch({ executablePath: CHROME, headless: "new" });
let bad = 0, checked = 0;
try {
  const page = await b.newPage();
  const go = async (p, w) => { await page.setViewport({ width: w, height: 900 }); await page.goto(BASE + p, { waitUntil: "networkidle0", timeout: 90000 }); };
  let urls = ["/"];
  if (!landing) {
    await go("/docs", 1440);
    const slugs = await page.$$eval(".docs-side a", (as) => as.map((a) => new URL(a.href).pathname));
    urls = ["/docs", ...slugs, "/changelog"];
    if (slugs.length < 15) { console.log("FAIL found only", slugs.length, "docs pages"); bad++; }
  }
  for (const w of WIDTHS) for (const u of urls) {
    await go(u, w);
    const r = await page.evaluate(() => {
      const de = document.documentElement, out = [];
      const doc = de.scrollWidth > innerWidth + 1 || document.body.scrollWidth > innerWidth + 1 ? `${de.scrollWidth}>${innerWidth}` : "";
      const d = (e) => e.tagName.toLowerCase() + (e.id ? "#" + e.id : "") + (typeof e.className === "string" && e.className ? "." + e.className.trim().split(/\s+/).slice(0, 2).join(".") : "");
      for (const e of document.querySelectorAll("body *")) {
        if (!e.clientWidth) continue;
        if (e.scrollWidth > e.clientWidth + 1) {
          const ox = getComputedStyle(e).overflowX;
          out.push(`${d(e)} ${e.scrollWidth}>${e.clientWidth} overflow-x:${ox}`);
        }
      }
      return { doc, out };
    });
    checked++;
    if (r.doc || r.out.length) {
      bad++;
      console.log(`FAIL ${w} ${u}${r.doc ? " DOCUMENT " + r.doc : ""}`);
      for (const o of r.out.slice(0, 12)) console.log("     ", o);
    }
  }
  console.log(`${bad ? "FAIL" : "ok  "} ${checked} page/width checks, ${bad} with horizontal overflow`);
} finally { await b.close(); }
process.exit(bad && !landing ? 1 : 0);
