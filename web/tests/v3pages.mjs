// Other pages for review. usage: node tests/v3pages.mjs <base> <outdir>
import puppeteer from "puppeteer-core";
const [base, out] = process.argv.slice(2);
const b = await puppeteer.launch({ executablePath: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome", headless: "new" });
try {
  for (const [name, path, w] of [["docs", "/docs", 1440], ["doc", "/docs/finding-the-element", 1440], ["doc390", "/docs/finding-the-element", 390], ["changelog", "/changelog", 1440], ["404", "/nope", 1440]]) {
    const p = await b.newPage(); await p.setViewport({ width: w, height: 900 });
    await p.goto(base + path, { waitUntil: "networkidle2" }); await new Promise((r) => setTimeout(r, 800));
    await p.screenshot({ path: `${out}/pg-${name}.png` }); await p.close();
  }
} finally { await b.close(); }
