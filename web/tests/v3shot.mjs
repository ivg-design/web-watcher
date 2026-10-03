// usage: node shot.mjs <base> <outdir> <widths csv> [waitMs]
import puppeteer from "puppeteer-core";
const [base, out, ws, wait = "3800"] = process.argv.slice(2);
const b = await puppeteer.launch({ executablePath: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome", headless: "new" });
try {
  for (const w of ws.split(",").map(Number)) {
    const p = await b.newPage();
    await p.setViewport({ width: w, height: w < 500 ? 844 : 900, deviceScaleFactor: 1 });
    await p.goto(base + "/", { waitUntil: "networkidle2", timeout: 90000 });
    await new Promise((r) => setTimeout(r, +wait));
    await p.screenshot({ path: `${out}/fold-${w}.png` });
    await p.screenshot({ path: `${out}/full-${w}.png`, fullPage: true });
    const ov = await p.evaluate(() => document.documentElement.scrollWidth - innerWidth);
    console.log(w, "overflow", ov);
    await p.close();
  }
} finally { await b.close(); }
