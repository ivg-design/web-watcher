// Headless web-runtime check: serves the .riv on :3219, loads it with @rive-app/canvas,
// drives the view model and screenshots the canvas to build/web-check.png.
import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import puppeteer from "puppeteer-core";

const here = path.dirname(fileURLToPath(import.meta.url));
const riv = path.resolve(here, "../../public/rive/watcher-mark.riv");
const out = path.join(here, "build/web-check.png");
fs.mkdirSync(path.dirname(out), { recursive: true });

const html = `<!doctype html><meta charset="utf-8">
<body style="margin:0;background:#f5f5f7">
<canvas id="c" width="192" height="192" style="width:192px;height:192px;display:block"></canvas>
<script src="https://unpkg.com/@rive-app/canvas@latest"></script>
<script>
window.result = null;
const r = new rive.Rive({
  src: "/mark.riv", canvas: document.getElementById("c"),
  autoplay: true, autoBind: true, stateMachines: "Mark",
  onLoad() {
    r.resizeDrawingSurfaceToCanvas();
    const vmi = r.viewModelInstance;
    window.result = {
      props: vmi.properties.map(p => p.name + ":" + p.type),
      stateMachines: r.stateMachineNames,
    };
    vmi.number("badge").value = 3;
    vmi.number("lookX").value = 0.8;
    vmi.number("lookY").value = -0.5;
    vmi.trigger("tick").trigger();
    window.loaded = true;
  },
  onLoadError(e) { window.err = String(e && e.data || e); },
});
</script>`;

const server = http.createServer((req, res) => {
  if (req.url === "/mark.riv") { res.setHeader("content-type", "application/octet-stream"); res.end(fs.readFileSync(riv)); }
  else { res.setHeader("content-type", "text/html"); res.end(html); }
}).listen(3219);

const browser = await puppeteer.launch({
  executablePath: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
  headless: "new",
});
try {
  const page = await browser.newPage();
  page.on("console", m => console.log("[page]", m.text()));
  await page.setViewport({ width: 192, height: 192, deviceScaleFactor: 1 });
  await page.goto("http://localhost:3219/");
  await page.waitForFunction("window.loaded || window.err", { timeout: 30000 });
  console.log("err:", await page.evaluate("window.err"));
  console.log(JSON.stringify(await page.evaluate("window.result"), null, 1));
  await new Promise(r => setTimeout(r, 1500));
  const el = await page.$("#c");
  await el.screenshot({ path: out });
  console.log("wrote", out);
} finally {
  await browser.close();
  server.close();
}
