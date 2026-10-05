import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { Marked, type Tokens } from "marked";
import { nowrapHtml } from "./nowrap";

export interface Heading { id: string; text: string; level: number }

export const slugify = (s: string) =>
  s.toLowerCase().replace(/<[^>]+>/g, "").replace(/&[a-z]+;/g, "").replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");

const NAMED: Record<string, string> = { quot: '"', amp: "&", lt: "<", gt: ">", apos: "'", nbsp: "\u00a0" };

/** Decodes the named and numeric HTML entities that marked emits, so text is plain. */
export function decodeEntities(s: string): string {
  return s.replace(/&(#x[0-9a-f]+|#\d+|[a-z]+);/gi, (m, e: string) => {
    if (e[0] === "#") {
      const n = e[1].toLowerCase() === "x" ? parseInt(e.slice(2), 16) : parseInt(e.slice(1), 10);
      return Number.isFinite(n) && n > 0 && n <= 0x10ffff ? String.fromCodePoint(n) : m;
    }
    return NAMED[e.toLowerCase()] ?? m;
  });
}

/** The label shown above a fenced block, by language. A fence may override it: ```json watchers.json */
const CODE_LABELS: Record<string, string> = {
  bash: "Terminal", sh: "Terminal", json: "JSON", css: "CSS selector", xpath: "XPath", text: "Text", url: "URL", template: "Template",
};

const sizeCache = new Map<string, [number, number] | null>();

/** Reads width/height from the PNG IHDR of public/<href>; null when missing or not a PNG. */
function pngSize(href: string): [number, number] | null {
  if (sizeCache.has(href)) return sizeCache.get(href) ?? null;
  let size: [number, number] | null = null;
  try {
    const buf = readFileSync(join(process.cwd(), "public", href));
    if (buf.length >= 24 && buf.toString("ascii", 1, 4) === "PNG") size = [buf.readUInt32BE(16), buf.readUInt32BE(20)];
  } catch { /* missing file: no dimensions */ }
  sizeCache.set(href, size);
  return size;
}

const hasFile = (href: string) => existsSync(join(process.cwd(), "public", href));

interface ShotFile { src: string; src2x?: string; w?: number; h?: number; shows?: string }
interface ManifestEntry { file: string; file2x?: string; width?: number; height?: number; appearance?: string; title?: string; shows?: string; section?: string }

let manifestCache: Map<string, ManifestEntry> | null = null;
/** public/shots/manifest.json, keyed by file name. Accepts a plain array or { images | shots: [...] }. Empty when absent. */
function shotManifest(): Map<string, ManifestEntry> {
  if (manifestCache) return manifestCache;
  const map = new Map<string, ManifestEntry>();
  try {
    const raw = JSON.parse(readFileSync(join(process.cwd(), "public", "shots", "manifest.json"), "utf8"));
    const list: ManifestEntry[] = Array.isArray(raw) ? raw : raw.images ?? raw.shots ?? Object.values(raw);
    for (const e of list) if (e && typeof e.file === "string") map.set(e.file.replace(/^.*\//, ""), e);
  } catch { /* no manifest: fall back to the files */ }
  manifestCache = map;
  return map;
}

function shotFile(href: string): ShotFile | null {
  if (!hasFile(href)) return null;
  const dir = href.slice(0, href.lastIndexOf("/") + 1);
  const e = shotManifest().get(href.slice(dir.length));
  const guess = /\.png$/.test(href) ? href.replace(/\.png$/, "@2x.png") : "";
  const src2x = e?.file2x ? dir + e.file2x.replace(/^.*\//, "") : guess;
  // The file is the authority on its own size; the manifest fills in when it is not a PNG.
  const size = pngSize(href) ?? (e?.width && e?.height ? ([e.width, e.height] as [number, number]) : null);
  return { src: href, src2x: src2x && hasFile(src2x) ? src2x : undefined, w: size?.[0], h: size?.[1], shows: e?.shows };
}

/** The file a page names, plus its dark twin when the set has one (name-dark.png beside name.png or name-light.png). */
function shotVariants(href: string): { main: ShotFile; dark?: ShotFile } {
  const stem = href.replace(/(-light|-dark)?\.png$/, "");
  const light = shotFile(href) ?? shotFile(`${stem}-light.png`) ?? shotFile(`${stem}.png`) ?? shotFile(`${stem}-dark.png`);
  const dark = shotFile(`${stem}-dark.png`);
  const main = light ?? { src: href };
  return { main, dark: dark && dark.src !== main.src ? dark : undefined };
}

const escapeHtml = (s: string) =>
  s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");

/** Inline code inside a table cell: short tokens stay whole; long ones get <wbr> after separators only. */
const SEP_BEFORE = /(?<=[/._\-:=?&,])/;
function cellCode(html: string): string {
  return html.replace(/<code>([\s\S]*?)<\/code>/g, (_m, inner: string) => {
    const plain = decodeEntities(inner);
    if (plain.length <= 16) return `<code class="tk">${inner}</code>`;
    return `<code>${plain.split(SEP_BEFORE).map(escapeHtml).join("<wbr>")}</code>`;
  });
}

/** Renders trusted, repo-owned Markdown. basePath prefixes root-relative links and images. */
export function renderMarkdown(src: string, basePath = ""): { html: string; headings: Heading[] } {
  const headings: Heading[] = [];
  const used = new Set<string>();
  const marked = new Marked({ gfm: true });
  const fix = (href: string) => (href.startsWith("/") && !href.startsWith("//") ? basePath + href : href);

  marked.use({
    renderer: {
      heading({ tokens, depth }: Tokens.Heading) {
        const html = this.parser.parseInline(tokens);
        const text = decodeEntities(html.replace(/<[^>]+>/g, ""));
        let id = slugify(text) || "section";
        while (used.has(id)) id += "-2";
        used.add(id);
        if (depth === 2 || depth === 3) headings.push({ id, text, level: depth });
        return `<h${depth} id="${id}"><a class="anchor" href="#${id}" aria-label="Link to ${escapeHtml(text)}">#</a>${html}</h${depth}>\n`;
      },
      link({ href, tokens }: Tokens.Link) {
        const external = /^https?:/.test(href);
        const rel = external ? ' target="_blank" rel="noopener noreferrer"' : "";
        return `<a href="${escapeHtml(fix(href))}"${rel}>${this.parser.parseInline(tokens)}</a>`;
      },
      image({ href, title, text: rawText }: Tokens.Image) {
        // ![alt text](/shots/name.png "Caption: what to look at"). Sizes, the 2x file and a light/dark pair come
        // from public/shots/manifest.json when it lists the image, else from the PNG itself.
        const local = href.startsWith("/") && !href.startsWith("//");
        const v = local ? shotVariants(href) : { main: { src: href } as ShotFile };
        const { main, dark } = v;
        const alt = decodeEntities(rawText) || main.shows || "";
        const caption = title ? (new Marked({ gfm: true }).parseInline(title) as string) : escapeHtml(alt);
        const set = (f: ShotFile) => (f.src2x ? `${escapeHtml(fix(f.src))} 1x, ${escapeHtml(fix(f.src2x))} 2x` : "");
        const dims = main.w && main.h ? ` width="${main.w}" height="${main.h}"` : "";
        const tall = main.w && main.h && main.h > main.w * 1.2 ? " tall" : "";
        const srcset = set(main) ? ` srcset="${set(main)}"` : "";
        const img = `<img src="${escapeHtml(fix(main.src))}" alt="${escapeHtml(alt)}"${srcset}${dims} loading="lazy" decoding="async" />`;
        const pic = dark
          ? `<picture><source media="(prefers-color-scheme: dark)" srcset="${set(dark) || escapeHtml(fix(dark.src))}" />${img}</picture>`
          : img;
        const full = escapeHtml(fix(main.src2x || main.src));
        const fullDark = dark ? ` data-full-dark="${escapeHtml(fix(dark.src2x || dark.src))}"` : "";
        return `<figure class="shot${tall}"><button type="button" class="shot__zoom" data-full="${full}"${fullDark}${dims ? ` data-w="${main.w}" data-h="${main.h}"` : ""} aria-label="Enlarge image: ${escapeHtml(alt)}">${pic}<span class="shot__hint" aria-hidden="true">Enlarge</span></button><figcaption>${caption}</figcaption></figure>`;
      },
      strong({ tokens }: Tokens.Strong) {
        const inner = this.parser.parseInline(tokens);
        // **Settings > Notifications > Delivery** is a menu path: each segment is a label, joined by chevrons.
        if (/ (?:>|&gt;) /.test(inner) && !/<code/.test(inner)) {
          const segs = inner.split(/ (?:>|&gt;) /).map((x) => `<span class="path__s">${x}</span>`);
          return `<strong class="path">${segs.join('<span class="path__c" aria-hidden="true">\u203a</span><span class="path__t"> then </span>')}</strong>`;
        }
        return `<strong>${inner}</strong>`;
      },
      paragraph({ tokens }: Tokens.Paragraph) {
        const first = tokens[0];
        // "**You see:** ..." after a step is the visible outcome of that step.
        if (first?.type === "strong" && /^You see:?$/.test(first.text)) {
          return `<p class="see"><span class="see__k">You see</span><span class="see__v">${this.parser.parseInline(tokens.slice(1)).trim()}</span></p>\n`;
        }
        // Inside a list item marked hands over one pre-rendered text token.
        if (tokens.length === 1 && first?.type === "text") {
          const html = this.parser.parseInline(tokens).trim();
          const see = /^<strong>You see:?<\/strong>\s*/.exec(html);
          if (see) return `<p class="see"><span class="see__k">You see</span><span class="see__v">${html.slice(see[0].length)}</span></p>\n`;
          if (/^<figure[\s\S]*<\/figure>$/.test(html)) return html + "\n";
        }
        // A figure stands on its own: never inside a paragraph.
        if (tokens.length === 1 && first.type === "image") return this.parser.parseInline(tokens) + "\n";
        return `<p>${this.parser.parseInline(tokens)}</p>\n`;
      },
      blockquote({ tokens }: Tokens.Blockquote) {
        // One convention: "> **Note.** ...", "> **Tip.** ..." or "> **Warning.** ...".
        let body = this.parser.parse(tokens);
        const m = /^<p><strong>(Note|Tip|Warning)[.:]?<\/strong>\s*/.exec(body);
        const kind = m ? m[1].toLowerCase() : "note";
        if (m) body = "<p>" + body.slice(m[0].length);
        const label = m ? m[1] : "Note";
        return `<aside class="callout" data-kind="${kind}" role="note"><p class="callout__k">${label}</p><div class="callout__b">${body}</div></aside>\n`;
      },
      code({ text, lang }: Tokens.Code) {
        const [id = "", ...rest] = (lang ?? "").trim().split(/\s+/);
        const lines = text.replace(/\n$/, "").split("\n").map((l) => `<span class="ln">${escapeHtml(l) || " "}</span>`).join("");
        const cls = id ? ` class="language-${escapeHtml(id)}"` : "";
        const label = rest.join(" ") || CODE_LABELS[id] || id;
        const cap = label ? `<figcaption class="code__k">${escapeHtml(label)}</figcaption>` : "";
        return `<figure class="code"${id ? ` data-lang="${escapeHtml(id)}"` : ""}>${cap}<pre><code${cls}>${lines}</code></pre></figure>\n`;
      },
      table(token: Tokens.Table) {
        const head = token.header.map((c) => `<th>${this.parser.parseInline(c.tokens)}</th>`).join("");
        const labels = token.header.map((c) => c.text);
        const rows = token.rows
          .map((r) => `<tr>${r.map((c, i) => `<td data-label="${escapeHtml(labels[i])}">${cellCode(this.parser.parseInline(c.tokens))}</td>`).join("")}</tr>`)
          .join("");
        return `<div class="table-wrap"><table><thead><tr>${head}</tr></thead><tbody>${rows}</tbody></table></div>\n`;
      },
    },
  });
  const html = (marked.parse(src) as string).replace(/<ol( start="\d+")?>/g, '<ol class="steps"$1>');
  return { html: nowrapHtml(html), headings };
}

/** Renders a single line of trusted Markdown (code spans, bold, links) without a wrapping paragraph. */
export function renderInline(src: string): string {
  const marked = new Marked({ gfm: true });
  marked.use({
    renderer: {
      link({ href, tokens }: Tokens.Link) {
        const external = /^https?:/.test(href);
        const rel = external ? ' target="_blank" rel="noopener noreferrer"' : "";
        return `<a href="${escapeHtml(href)}"${rel}>${this.parser.parseInline(tokens)}</a>`;
      },
    },
  });
  return nowrapHtml(marked.parseInline(src) as string);
}
