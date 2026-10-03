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

const dh = await page.evaluate(() => {
  const bgOf = (q) => getComputedStyle(document.querySelector(q)).backgroundColor;
  const shell = document.querySelector(".docs-shell");
  const bad = [];
  for (const e of shell.querySelectorAll("*")) { const c = getComputedStyle(e); if (c.color === "rgb(31, 94, 255)" || c.backgroundColor === "rgb(31, 94, 255)") bad.push(e.className || e.tagName); }
  const rgb = (v) => { const c = document.createElement("canvas").getContext("2d"); c.fillStyle = v; c.fillRect(0, 0, 1, 1); return [...c.getImageData(0, 0, 1, 1).data].slice(0, 3).join(","); };
  return { hbg: bgOf(".docs-header"), shellBg: rgb(bgOf(".docs-shell")), bodyBg: rgb(getComputedStyle(document.body).backgroundColor), bad, brandHref: document.querySelector(".docs-header .brand").getAttribute("href") };
});
await go("/docs/notification-templates", 1440);
const tk = await page.evaluate(() => { const c = document.querySelector(".prose table code"); return c ? getComputedStyle(c).whiteSpace : null; });
ok(tk === "nowrap", `table code token white-space nowrap (${tk})`);
const dbg2 = await page.evaluate(() => { const e = document.querySelector(".docs-header"); const c = getComputedStyle(e); return { bg: c.backgroundColor, bb: c.borderBottomColor }; });
await go("/", 1440);
const lh = await page.evaluate(() => { const c = getComputedStyle(document.querySelector(".site-header")); return { bg: c.backgroundColor, bb: c.borderBottomColor }; });
ok(dh.hbg === lh.bg && dbg2.bb === lh.bb, `docs header bg/border equal landing header (${dh.hbg} vs ${lh.bg})`);
ok(dh.shellBg !== "244,245,250" && dh.bodyBg !== "244,245,250", `docs body not old #f4f5fa (${dh.shellBg})`);
ok(dh.bad.length === 0, `no element in docs shell uses the old accent rgb(31, 94, 255) ${JSON.stringify(dh.bad)}`);
ok(dh.brandHref === "/", `docs brand links to landing root (${dh.brandHref})`);
const ups = await page.$$eval("#changelog .clx__t", (e) => e.map((x) => x.textContent.trim()));
ok(ups.length > 0 && ups.every((t) => /[.!?\u2026]$/.test(t) && !t.includes("...") && !/\u2026\s+\S/.test(t)), `Recent updates summaries end cleanly, no glued ellipsis (${ups.length})`);

await go("/", 1440);
const l = await page.evaluate(() => {
  const i = document.querySelector(".site-header .brand img").getBoundingClientRect();
  return { h: i.height, w: i.width, row: document.querySelector(".site-header__row").getBoundingClientRect().height };
});
ok(l.h === 54 && l.w === 54 && l.row === 63, `landing icon ${l.w}x${l.h} row ${l.row}`);

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
    return { l: r.left, r: innerWidth - r.right, hl: hr.left, hw: hr.width, w: r.width, al: a.left - mn.left, ar: mn.right - a.right, cw: document.documentElement.getBoundingClientRect().width };
  });
  ok(Math.abs(g.l - (g.cw - (g.l + g.w))) <= 1, `shell centred @${w} (left ${g.l}, width ${g.w}, cw ${g.cw})`);
  ok(Math.abs(g.hl - g.l) <= 1 && Math.abs(g.hw - g.w) <= 1, `header aligns with shell @${w}`);
  ok(Math.abs(g.al - g.ar) <= 1, `article centred in column @${w} (${g.al}/${g.ar})`);
  await page.screenshot({ path: `.screenshots/docs-${w}.png` });
}
for (const w of [834, 390]) {
  for (const p of ["/docs/install", "/docs", "/changelog"]) {
    await go(p, w, 844);
    const o = await page.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth);
    ok(o <= 0, `no h-overflow @${w} ${p} (${o})`);
  }
  await go("/docs/install", w, 844);
  await page.screenshot({ path: `.screenshots/docs-${w}.png` });
}

// entities in <title>, breadcrumbs, prev/next, lede; shots; details TOC; rail highlight
let shots = 0;
for (const p of slugs) {
  await go(p, 1440);
  const t = await page.evaluate(() => ({
    title: document.title,
    txt: [...document.querySelectorAll(".crumbs, .docs-pager a, .doc-title, .doc-lede, .docs-article h2, .docs-article h3")].map((e) => e.textContent),
    imgs: [...document.querySelectorAll('.docs-article img[src*="/shots/"]')].map((i) => ({ w: i.naturalWidth, ss: i.getAttribute("srcset"), wa: i.getAttribute("width"), ha: i.getAttribute("height"), alt: i.alt, src: i.getAttribute("src") })),
  }));
  ok(![t.title, ...t.txt].some((x) => ent.test(x)), `no entities in title/crumbs/pager/headings ${p}`);
  shots += t.imgs.length;
  await page.evaluate(() => document.querySelectorAll("img[loading=lazy]").forEach((x) => (x.loading = "eager")));
  await new Promise((r) => setTimeout(r, 300));
  const im = await page.evaluate(() => [...document.querySelectorAll('.docs-article img[src*="/shots/"]')].map((i) => ({ w: i.naturalWidth, ss: i.getAttribute("srcset"), wa: i.getAttribute("width"), ha: i.getAttribute("height"), alt: i.alt, src: i.getAttribute("src") })));
  ok(im.every((i) => i.w > 0 && /2x/.test(i.ss || "") && i.wa && i.ha && i.alt.length > 8), `shots load with srcset/size/alt ${p} (${im.length})`);
}
ok(shots >= 14, `docs embed ${shots} /shots images`);

// heading outline: sidebar/TOC titles are <p>, nothing heading-level before the h1; accuracy copy
for (const p of ["/docs/first-watcher", "/docs/install"]) {
  await go(p, 1440);
  const h = await page.evaluate(() => {
    const hs = [...document.querySelectorAll("h1,h2,h3,h4,h5,h6")];
    return { first: hs[0]?.tagName, sideH: document.querySelectorAll(".docs-side h4, .toc h4, .footer h4").length, titles: [...document.querySelectorAll(".docs-group__t, .toc__t")].length, aria: [...document.querySelectorAll(".docs-header img, .footer img")].every((i) => i.getAttribute("aria-hidden") === "true") };
  });
  ok(h.first === "H1" && h.sideH === 0 && h.titles > 0 && h.aria, `${p}: outline starts at h1, titles are <p>, header/footer icons aria-hidden ${JSON.stringify(h)}`);
}
const txt = async (p) => (await (await fetch(BASE + p)).text()).replace(/<[^>]+>/g, " ").replace(/&#x27;|&#39;/g, "'").replace(/\s+/g, " ");
const fw = await txt("/docs/first-watcher");
ok(/Badge and count watchers notify when the number goes up/.test(fw) && !/only notifies when the value changes/.test(fw), "first-watcher: rises-only copy");
const cn = await txt("/docs/custom-notifications");
ok(/text watchers notify on any change/.test(cn) && !/only notifies when the value changes/.test(cn), "custom-notifications: rises-only copy");
ok(/Delete moves the messages to Trash/.test(await txt("/docs/sender-and-domain-watchers")), "sender watchers: Delete moves to Trash");
ok(/group by site/.test(await txt("/docs/herald-delivery")) && /group by sender address/.test(await txt("/docs/herald-delivery")), "herald-delivery: stacking by site and by sender");
const llms = await (await fetch(BASE + "/llms.txt")).text();
ok(/gmail\.modify/.test(llms) && !/read-only/i.test(llms), "llms.txt: gmail.modify, not read-only");

// rail highlight while scrolling
await go("/docs/finding-the-element", 1440, 700);
const ids = await page.$$eval(".toc a", (as) => as.map((a) => a.getAttribute("href").slice(1)));
const last = ids[ids.length - 1];
await page.evaluate((id) => document.getElementById(id).scrollIntoView(), last);
await new Promise((r) => setTimeout(r, 500));
const on = await page.$eval(".toc a.is-on", (a) => a.getAttribute("href").slice(1)).catch(() => null);
ok(on && on !== ids[0], `rail highlights current heading while scrolling (${on})`);

// narrow: details inline TOC
await go("/docs/finding-the-element", 834, 844);
const det = await page.evaluate(() => { const d = document.querySelector("details.toc-inline, .toc-inline"); return d ? { tag: d.tagName, vis: d.getBoundingClientRect().height > 0, rail: getComputedStyle(document.querySelector(".toc")).display } : null; });
ok(det && det.tag === "DETAILS" && det.vis && det.rail === "none", `details inline TOC at 834, rail hidden ${JSON.stringify(det)}`);

// drawer + search at 390
await go("/docs/install", 390, 844);
await page.click(".docs-menu-btn");
await page.waitForSelector("#docs-drawer a");
const dr = await page.evaluate(() => ({ n: document.querySelectorAll("#docs-drawer a").length, ov: document.documentElement.scrollWidth - document.documentElement.clientWidth }));
ok(dr.n > 15 && dr.ov <= 0, `drawer opens at 390 (${dr.n} links, overflow ${dr.ov})`);
await Promise.all([page.waitForFunction(() => location.pathname.endsWith("/docs/permissions")), page.click('#docs-drawer a[href$="/docs/permissions"]')]);
await new Promise((r) => setTimeout(r, 300));
ok(!(await page.$("#docs-drawer")), "drawer closes after navigating");
await page.click(".search-btn");
await page.waitForSelector(".search__box input");
await page.type(".search__box input", "gmail");
const rs = await page.$$eval(".search__list li", (l) => l.map((x) => x.textContent));
ok(rs.length > 0 && !rs.some((x) => ent.test(x)), `search opens by button and returns results (${rs.length})`);
await page.keyboard.press("Escape");
await page.waitForFunction(() => !document.querySelector(".search__box"));
await page.keyboard.press("/");
ok(!!(await page.waitForSelector(".search__box input", { timeout: 2000 }).catch(() => null)), "search opens with /");
await page.keyboard.press("Escape");

// changelog
await go("/changelog", 1440);
const cl = await page.evaluate(() => {
  const es = [...document.querySelectorAll(".log__entry")];
  return { n: es.length, ids: es.every((e) => /^v\d/.test(e.id)), mono: es.slice(0, 3).map((e) => [...e.querySelectorAll("*")].some((x) => /mono/i.test(getComputedStyle(x).fontFamily))) };
});
ok(cl.n >= 3 && cl.ids && cl.mono.every(Boolean), `changelog ${cl.n} entries with anchors and mono columns`);
await go("/docs/finding-the-element", 1440, 900); await page.screenshot({ path: ".screenshots/docs-finding-1440.png" });
await go("/docs/finding-the-element", 390, 844); await page.screenshot({ path: ".screenshots/docs-finding-390.png" });
await b.close();
process.exit(fail ? 1 : 0);
