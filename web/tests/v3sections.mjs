// Section-by-section viewport screenshots. usage: node tests/v3sections.mjs <base> <outdir> <widths csv>
import puppeteer from "puppeteer-core";
const [base, out, ws] = process.argv.slice(2);
const IDS = ["hero", "interval", "how-it-works", "picker", "watch-types", "gmail", "herald", "privacy", "download", "changelog"];
const b = await puppeteer.launch({ executablePath: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome", headless: "new" });
try {
  for (const w of ws.split(",").map(Number)) {
    const p = await b.newPage();
    await p.setViewport({ width: w, height: w < 500 ? 844 : 900, deviceScaleFactor: 1 });
    await p.goto(base + "/", { waitUntil: "networkidle2", timeout: 90000 });
    await new Promise((r) => setTimeout(r, 3600));
    for (const id of IDS) {
      const ok = await p.evaluate((id) => { const e = document.getElementById(id); if (!e) return false; window.scrollTo({ top: e.getBoundingClientRect().top + scrollY - 64, behavior: "instant" }); return true; }, id);
      if (!ok) { console.log("missing", id); continue; }
      await new Promise((r) => setTimeout(r, 900));
      await p.screenshot({ path: `${out}/${w}-${id}.png` });
    }
    console.log(w, "overflow", await p.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth));
    await p.close();
  }
} finally { await b.close(); }
