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

const escapeHtml = (s: string) =>
  s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");

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
      image({ href, text: rawText }: Tokens.Image) {
        const local = href.startsWith("/") && !href.startsWith("//");
        const size = local ? pngSize(href) : null;
        const retina = local && /\.png$/.test(href) ? href.replace(/\.png$/, "@2x.png") : "";
        const srcset = retina && hasFile(retina) ? ` srcset="${escapeHtml(fix(href))} 1x, ${escapeHtml(fix(retina))} 2x"` : "";
        const text = decodeEntities(rawText);
        const dims = size ? ` width="${size[0]}" height="${size[1]}"` : "";
        const tall = size && size[1] > size[0] * 1.2 ? " tall" : "";
        return `<figure class="shot${tall}"><img src="${escapeHtml(fix(href))}" alt="${escapeHtml(text)}"${srcset}${dims} loading="lazy" decoding="async" /><figcaption>${escapeHtml(text)}</figcaption></figure>`;
      },
      blockquote({ tokens }: Tokens.Blockquote) {
        return `<aside class="callout">${this.parser.parse(tokens)}</aside>\n`;
      },
      table(token: Tokens.Table) {
        const head = token.header.map((c) => `<th>${this.parser.parseInline(c.tokens)}</th>`).join("");
        const labels = token.header.map((c) => c.text);
        const rows = token.rows
          .map((r) => `<tr>${r.map((c, i) => `<td data-label="${escapeHtml(labels[i])}">${this.parser.parseInline(c.tokens)}</td>`).join("")}</tr>`)
          .join("");
        return `<div class="table-wrap"><table><thead><tr>${head}</tr></thead><tbody>${rows}</tbody></table></div>\n`;
      },
    },
  });
  return { html: nowrapHtml(marked.parse(src) as string), headings };
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
