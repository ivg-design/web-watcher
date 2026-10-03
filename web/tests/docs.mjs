import puppeteer from "puppeteer-core";
const BASE = process.env.BASE || "http://localhost:3214";
const CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
const b = await puppeteer.launch({ executablePath: CHROME, headless: "new" });
let fail = 0;
const ok = (c, m) => { if (!c) { fail++; console.log("FAIL", m); } else console.log("ok  ", m); };
const page = await b.newPage();
const go = async (path, w, h = 900) => { await page.setViewport({ width: w, height: h }); await page.goto(BASE + path, { waitUntil: "networkidle0" }); };

await go("/docs", 1440);
const slugs = await page.$$eval(".docs-side a", (as) => as.map((a) => new URL(a.href).pathname));
ok(slugs.length > 10, `found ${slugs.length} doc pages`);
const m = await page.evaluate(() => {
  const a = document.querySelector(".docs-header .brand"); const i = a.querySelector("img").getBoundingClientRect();
  return { href: a.getAttribute("href"), ih: i.height, iw: i.width, hh: document.querySelector(".docs-header").getBoundingClientRect().height,
    crumb: document.querySelector(".docs-crumb").getAttribute("href") };
});
ok(m.href === "/", `docs brand href "/" (${m.href})`);
ok(/\/docs\/?$/.test(m.crumb), `docs crumb -> ${m.crumb}`);
ok(m.hh === 64 && m.ih === 54 && m.iw === 54, `docs icon ${m.iw}x${m.ih} in header ${m.hh}`);

await go("/", 1440);
const l = await page.evaluate(() => {
  const i = document.querySelector(".site-header .brand img").getBoundingClientRect();
  return { h: i.height, w: i.width, row: document.querySelector(".site-header__row").getBoundingClientRect().height };
});
ok(l.h === 66 && l.w === 66 && l.row === 76, `landing icon ${l.w}x${l.h} row ${l.row}`);

const ent = /&(#x?[0-9a-f]+|[a-z]+);/i;
for (const p of slugs) {
  await go(p, 1440);
  const t = await page.evaluate(() => ({
    toc: [...document.querySelectorAll(".toc a, .toc-inline a")].map((a) => a.textContent),
    aria: [...document.querySelectorAll("a.anchor")].map((a) => a.getAttribute("aria-label")),
  }));
  const bad = [...t.toc, ...t.aria].filter((x) => ent.test(x));
  ok(bad.length === 0, `no entities in toc/aria ${p} (${t.toc.length} items)${bad.length ? " " + JSON.stringify(bad) : ""}`);
}
// search index RSC payload
const html = await (await fetch(BASE + slugs[0])).text();
const idx = [...html.matchAll(/\\"heading\\":\\"((?:[^"\\]|\\.)*?)\\"/g)].map((x) => x[1]);
ok(idx.length > 0 && !idx.some((x) => ent.test(x)), `search index headings clean (${idx.length})`);

for (const w of [1920, 1440]) {
  await go("/docs/install", w);
  const g = await page.evaluate(() => {
    const r = document.querySelector(".docs-shell__in").getBoundingClientRect();
    const hr = document.querySelector(".docs-header__in").getBoundingClientRect();
    const a = document.querySelector(".docs-article").getBoundingClientRect();
    const mn = document.querySelector(".docs-main").getBoundingClientRect();
    return { l: r.left, r: innerWidth - r.right, hl: hr.left, hw: hr.width, w: r.width, al: a.left - mn.left, ar: mn.right - a.right, cw: document.documentElement.clientWidth };
  });
  ok(Math.abs(g.l - (g.cw - (g.l + g.w))) <= 1, `shell centred @${w} (left ${g.l}, width ${g.w}, cw ${g.cw})`);
  ok(Math.abs(g.hl - g.l) <= 1 && Math.abs(g.hw - g.w) <= 1, `header aligns with shell @${w}`);
  ok(Math.abs(g.al - g.ar) <= 1, `article centred in column @${w} (${g.al}/${g.ar})`);
  await page.screenshot({ path: `.screenshots/docs-${w}.png` });
}
for (const w of [834, 390]) {
  for (const p of ["/docs/install", "/docs", "/"]) {
    await go(p, w, 844);
    const o = await page.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth);
    ok(o <= 0, `no h-overflow @${w} ${p} (${o})`);
  }
  await go("/docs/install", w, 844);
  await page.screenshot({ path: `.screenshots/docs-${w}.png` });
}
await b.close();
process.exit(fail ? 1 : 0);
