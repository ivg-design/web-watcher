/** Proper nouns, product names, versions and key combos that must never break across lines. */
export const NOWRAP_PHRASES = [
  "IVG Design", "WebWatcher", "Web Watcher", "Claude Code", "Apple Silicon", "Apple Events",
  "Notification Center", "System Settings", "macOS 13+", "macOS 13", "SHA-256", "Developer ID",
  "Google OAuth", "Sign in with Google", "⌘ + K", "⌘K", "Ctrl+K",
];

const esc = (s: string) => s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
const VERSION = String.raw`v?\d+\.\d+\.\d+ \((?:Build )?\d+\)`;
const BUILD = String.raw`Build \d+`;
const RE = new RegExp(
  `(${[VERSION, BUILD, ...[...NOWRAP_PHRASES].sort((a, b) => b.length - a.length).map(esc)].join("|")})`,
  "g",
);

/** Wraps phrases in text nodes with <span class="nw">; leaves tags, attributes, <code>, <pre> untouched. */
export function nowrapHtml(html: string): string {
  let skip = 0;
  return html
    .split(/(<[^>]*>)/)
    .map((part) => {
      if (part.startsWith("<")) {
        const m = /^<(\/?)(code|pre)\b/i.exec(part);
        if (m) skip += m[1] ? -1 : 1;
        return part;
      }
      return skip > 0 ? part : part.replace(RE, '<span class="nw">$1</span>');
    })
    .join("");
}
