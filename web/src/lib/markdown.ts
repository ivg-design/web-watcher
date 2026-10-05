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
        // ![alt text](/shots/name.png "Caption: what to look at"). The 2x file is what the enlarge view shows.
        const local = href.startsWith("/") && !href.startsWith("//");
        const size = local ? pngSize(href) : null;
        const retina = local && /\.png$/.test(href) ? href.replace(/\.png$/, "@2x.png") : "";
        const has2x = !!retina && hasFile(retina);
        const srcset = has2x ? ` srcset="${escapeHtml(fix(href))} 1x, ${escapeHtml(fix(retina))} 2x"` : "";
        const alt = decodeEntities(rawText);
        const caption = title ? (new Marked({ gfm: true }).parseInline(title) as string) : escapeHtml(alt);
        const dims = size ? ` width="${size[0]}" height="${size[1]}"` : "";
        const tall = size && size[1] > size[0] * 1.2 ? " tall" : "";
        const full = escapeHtml(fix(has2x ? retina : href));
        const img = `<img src="${escapeHtml(fix(href))}" alt="${escapeHtml(alt)}"${srcset}${dims} loading="lazy" decoding="async" />`;
        return `<figure class="shot${tall}"><button type="button" class="shot__zoom" data-full="${full}"${dims ? ` data-w="${size![0]}" data-h="${size![1]}"` : ""} aria-label="Enlarge image: ${escapeHtml(alt)}">${img}<span class="shot__hint" aria-hidden="true">Enlarge</span></button><figcaption>${caption}</figcaption></figure>`;
      },
      strong({ tokens }: Tokens.Strong) {
        const inner = this.parser.parseInline(tokens);
        // **Settings > Notifications > Delivery** is a menu path: each segment is a label, joined by chevrons.
        if (/ (?:>|&gt;) /.test(inner) && !/<code/.test(inner)) {
          const segs = inner.split(/ (?:>|&gt;) /).map((x) => `<span class="path__s">${x}</span>`);
          return `<strong class="path">${segs.join('<span class="path__c" aria-hidden="true">\u203a</span><span class="sr-only"> then </span>')}</strong>`;
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
