// Whole-section clips with the fixed header hidden. usage: node tests/v3clips.mjs <base> <outdir> <widths csv> [ids csv]
import puppeteer from "puppeteer-core";
const [base, out, ws, ids] = process.argv.slice(2);
const IDS = (ids || "how-it-works,picker,watch-types,gmail,herald").split(",");
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const b = await puppeteer.launch({ executablePath: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome", headless: "new" });
try {
  for (const w of ws.split(",").map(Number)) {
    const p = await b.newPage();
    await p.setViewport({ width: w, height: w < 500 ? 844 : 900, deviceScaleFactor: 1 });
    await p.goto(base + "/", { waitUntil: "networkidle2", timeout: 90000 });
    await sleep(11000); // the first-change chip has gone
    for (const id of IDS) {
      await p.evaluate((id) => { const e = document.getElementById(id); window.scrollTo({ top: e.getBoundingClientRect().top + scrollY - 64, behavior: "instant" }); }, id);
      await sleep(4500);
      await p.addStyleTag({ content: "header.site-header, .ww-notices { visibility: hidden !important; }" });
      const r = await p.evaluate((id) => { const q = document.getElementById(id).getBoundingClientRect(); return { x: 0, y: q.top + scrollY, width: innerWidth, height: q.height }; }, id);
      await p.screenshot({ path: `${out}/clip-${w}-${id}.png`, clip: r, captureBeyondViewport: true });
    }
    await p.close();
  }
} finally { await b.close(); }
