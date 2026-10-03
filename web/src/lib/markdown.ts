import { Marked, type Tokens } from "marked";

export interface Heading { id: string; text: string; level: number }

export const slugify = (s: string) =>
  s.toLowerCase().replace(/<[^>]+>/g, "").replace(/&[a-z]+;/g, "").replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");

const IMAGE_SIZES: Record<string, [number, number]> = {
  "/shots/add-watcher.png": [1024, 2277],
  "/shots/settings.png": [1048, 1536],
  "/shots/popover.png": [681, 795],
};

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
        const text = html.replace(/<[^>]+>/g, "");
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
      image({ href, text }: Tokens.Image) {
        const size = IMAGE_SIZES[href];
        const dims = size ? ` width="${size[0]}" height="${size[1]}"` : "";
        const tall = size && size[1] > size[0] * 1.2 ? " tall" : "";
        return `<figure class="shot${tall}"><img src="${escapeHtml(fix(href))}" alt="${escapeHtml(text)}"${dims} loading="lazy" decoding="async" /><figcaption>${escapeHtml(text)}</figcaption></figure>`;
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
  return { html: marked.parse(src) as string, headings };
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
  return marked.parseInline(src) as string;
}
