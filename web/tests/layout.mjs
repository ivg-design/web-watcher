import puppeteer from "puppeteer-core";
const BASE = process.env.BASE || "http://localhost:3101";
const CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
const b = await puppeteer.launch({ executablePath: CHROME, headless: "new", args: ["--disable-features=OverlayScrollbar,OverlayScrollbars,FluentOverlayScrollbar"], ignoreDefaultArgs: ["--hide-scrollbars"] });
let fail = 0;
const ok = (c, m) => { if (!c) { fail++; console.log("FAIL", m); } else console.log("ok  ", m); };
const page = await b.newPage();
// macOS Chrome uses overlay scrollbars; force a classic 15px scrollbar so the gutter is real.
await page.evaluateOnNewDocument(() => {
  const add = () => { const st = document.createElement("style"); st.textContent = "::-webkit-scrollbar{width:15px;height:15px}::-webkit-scrollbar-thumb{background:#999}"; document.head.appendChild(st); };
  if (document.head) add(); else document.addEventListener("DOMContentLoaded", add);
});
const go = async (path, w, h = 1300) => { await page.setViewport({ width: w, height: h }); await page.goto(BASE + path, { waitUntil: "networkidle0" }); };
const xs = (sels) => page.evaluate((s) => s.map((q) => { const e = document.querySelector(q); return e ? e.getBoundingClientRect().x : null; }), sels);

// A. scrollbar independence
const docsSel = [".docs-header .brand", ".docs-side", ".docs-article", ".toc"];
const states = [];
await go("/docs/gmail-limitations", 1440); states.push(["short", await xs(docsSel)]);
await go("/docs/finding-the-element", 1440);
const sbw = await page.evaluate(() => innerWidth - document.documentElement.clientWidth);
await go("/docs/gmail-limitations", 1440);
const sbs = await page.evaluate(() => innerWidth - document.documentElement.clientWidth);
ok(sbw === 15, `classic scrollbar active on long page (${sbw}px; short page reports ${sbs})`);
await go("/docs/finding-the-element", 1440); states.push(["long", await xs(docsSel)]);
await go("/docs", 1440); states.push(["index", await xs(docsSel)]);
await page.keyboard.down("Meta"); await page.keyboard.press("k"); await page.keyboard.up("Meta");
await new Promise((r) => setTimeout(r, 400));
const open = await page.evaluate(() => document.body.style.overflow === "hidden");
ok(open, "search overlay open (body overflow hidden)");
states.push(["index+search", await xs(docsSel)]);
for (let i = 0; i < docsSel.length; i++) {
  // /docs index has its own layout (no TOC); compare like with like: article pages together, index open vs closed.
  const same = (names) => { const v = states.filter(([n]) => names.includes(n)).map(([, x]) => x[i]); return v.every((q) => q === v[0]); };
  ok(same(["short", "long"]) && same(["index", "index+search"]), `docs ${docsSel[i]} x identical: ${states.map(([n, v]) => `${n}=${v[i]}`).join(" ")}`);
}
const landSel = [".site-header .brand", "#hero .container"];
await go("/", 1440); const l1 = await xs(landSel);
await go("/changelog", 1440); const l2 = await xs(landSel);
ok(l1[0] === l2[0], `site-header .brand x: ${l1[0]} vs ${l2[0]}`);
ok(l1[1] === null || l2[1] === null || l1[1] === l2[1], `#hero .container x: ${l1[1]} (changelog has none: ${l2[1]})`);
const hdr = async (p) => { await go(p, 1440); return page.evaluate(() => { const c = document.querySelector(".site-header .container"); return c ? c.getBoundingClientRect().x : null; }); };
const c1 = await hdr("/"), c2 = await hdr("/changelog");
ok(c1 === c2, `site-header .container x: ${c1} vs ${c2}`);

// control: without the gutter the same pages must shift, proving the test is sensitive
{
  const x = async (path) => { await go(path, 1440); await page.addStyleTag({ content: "html{scrollbar-gutter:auto!important}" }); return (await xs([".toc"]))[0]; };
  const a = await x("/docs/gmail-limitations"), c = await x("/docs/finding-the-element");
  ok(a !== c, `control: gutter off shifts .toc (${a} vs ${c})`);
}

// B. nowrap phrases
const PH = ["IVG Design", "WebWatcher", "Web Watcher", "Claude Code", "Apple Silicon", "Apple Events", "Notification Center", "System Settings", "macOS 13+", "macOS 13", "SHA-256", "Developer ID", "Google OAuth", "Sign in with Google", "⌘ + K", "⌘K", "Ctrl+K", "Build \\d+", "v?\\d+\\.\\d+\\.\\d+ \\((?:Build )?\\d+\\)"];
const offenders = []; let checked = 0;
for (const w of [1440, 834, 390]) for (const p of ["/", "/docs", "/docs/install", "/docs/settings", "/changelog"]) {
  await go(p, w);
  const res = await page.evaluate((PH) => {
    const re = new RegExp(PH.sort((a, b) => b.length - a.length).join("|"), "g");
    const out = [];
    const sel = (n) => { let e = n.parentElement; return e ? e.tagName.toLowerCase() + (e.className && typeof e.className === "string" ? "." + e.className.trim().split(/\s+/).join(".") : "") : ""; };
    const tw = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
    for (let n; (n = tw.nextNode()); ) {
      const pe = n.parentElement; if (!pe || /^(SCRIPT|STYLE|NOSCRIPT)$/.test(pe.tagName) || pe.closest("code,pre")) continue;
      const cs = getComputedStyle(pe); if (cs.display === "none" || cs.visibility === "hidden" || !pe.getClientRects().length) continue;
      re.lastIndex = 0; let m;
      while ((m = re.exec(n.data))) {
        const r = document.createRange(); r.setStart(n, m.index); r.setEnd(n, m.index + m[0].length);
        const rects = [...r.getClientRects()].filter((q) => q.width > 0);
        const lines = new Set(rects.map((q) => Math.round(q.top)));
        out.push({ checked: 1 });
        if (lines.size > 1) out.push({ phrase: m[0], sel: sel(n) });
      }
    }
    return out;
  }, PH);
  checked += res.filter((r) => r.checked).length;
  for (const r of res.filter((r) => !r.checked)) offenders.push({ ...r, page: p, width: w });
}
ok(checked > 30, `phrase instances checked: ${checked}`);
ok(offenders.length === 0, `no wrapped phrases (${offenders.length} offenders)`);
for (const o of offenders) console.log("  OFFENDER", JSON.stringify(o));
await b.close();
process.exit(fail ? 1 : 0);
