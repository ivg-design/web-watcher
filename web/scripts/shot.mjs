// usage: node shot.mjs <out> <width> [selector] [scrollY]
import puppeteer from "puppeteer-core";
const [out, w, sel, sy] = process.argv.slice(2);
const b = await puppeteer.launch({ executablePath: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome", headless: "new" });
const p = await b.newPage(); await p.setViewport({ width: +w, height: 900, deviceScaleFactor: 1 });
await p.goto((process.env.BASE || "http://localhost:3101") + (process.env.PATHNAME || "/"), { waitUntil: "networkidle2", timeout: 90000 });
await new Promise(r => setTimeout(r, 1200));
if (sel) { const el = await p.$(sel); await el.evaluate(e => e.scrollIntoView({block: "start"})); await new Promise(r => setTimeout(r, +(sy || 1500))); await el.screenshot({ path: out }); }
else await p.screenshot({ path: out, fullPage: true });
await b.close();
