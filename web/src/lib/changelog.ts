import { readFileSync } from "node:fs";
import { join } from "node:path";

export interface ChangelogSection { title: string; items: string[] }
export interface ChangelogEntry {
  version: string;
  build: string | null;
  date: string;
  sections: ChangelogSection[];
}

let cache: ChangelogEntry[] | null = null;

/** Parses CHANGELOG.md (Keep a Changelog) into entries, newest first. */
export function getChangelog(): ChangelogEntry[] {
  if (cache) return cache;
  const raw = readFileSync(join(process.cwd(), "content", "CHANGELOG.md"), "utf8");
  const entries: ChangelogEntry[] = [];
  let entry: ChangelogEntry | null = null;
  let section: ChangelogSection | null = null;
  let item: string[] | null = null;
  const flush = () => {
    if (section && item) section.items.push(item.join(" ").trim());
    item = null;
  };
  for (const line of raw.split("\n")) {
    const h2 = line.match(/^## \[(\d+\.\d+\.\d+)\](?: \(Build (\d+)\))? - (\d{4}-\d{2}-\d{2})/);
    if (h2) {
      flush();
      entry = { version: h2[1], build: h2[2] ?? null, date: h2[3], sections: [] };
      entries.push(entry);
      section = null;
      continue;
    }
    if (line.startsWith("## ")) { flush(); entry = null; section = null; continue; }
    if (!entry) continue;
    const h3 = line.match(/^### (.+)/);
    if (h3) { flush(); section = { title: h3[1].trim(), items: [] }; entry.sections.push(section); continue; }
    if (!section) continue;
    if (/^- /.test(line)) { flush(); item = [line.slice(2).trim()]; }
    else if (/^\s+\S/.test(line) && item) item.push(line.trim());
    else if (line.trim() === "") flush();
  }
  flush();
  cache = entries;
  return entries;
}

const isHeraldResync = (e: ChangelogEntry) =>
  e.sections.every((s) => s.items.every((i) => /^Vendored Herald client|^Herald client re-synced/i.test(i)));

const ORDER = ["Added", "Changed", "Fixed"];
const LIMIT = 160;
/** Plain text of one item, cut to whole sentences, ending in exactly one terminal mark. */
const cut = (t: string) => {
  const plain = t
    .replace(/\[([^\]]+)\]\([^)]*\)/g, "$1")
    .replace(/[`*]/g, "")
    .replace(/\s+/g, " ")
    .trim()
    .replace(/\.{3,}|…/g, ".");
  if (plain.length <= LIMIT) return /[.!?]$/.test(plain) ? plain : `${plain}.`;
  // Whole sentences that fit in the limit.
  let end = -1;
  for (const m of plain.matchAll(/[.!?](?=\s)/g)) {
    if ((m.index ?? 0) + 1 <= LIMIT) end = (m.index ?? 0) + 1; else break;
  }
  if (end > 0) return plain.slice(0, end);
  // The first sentence is itself too long: cut at a word boundary.
  const head = plain.slice(0, LIMIT);
  const sp = head.lastIndexOf(" ");
  return `${head.slice(0, sp > 40 ? sp : LIMIT).replace(/[\s,;:.\-–—(]+$/, "")}…`;
};

/** Short one-line summary of an entry for the landing page list: the first item only. */
export function summarize(e: ChangelogEntry): string {
  const sorted = [...e.sections].sort((a, b) => ORDER.indexOf(a.title) - ORDER.indexOf(b.title));
  const first = sorted.flatMap((s) => s.items)[0];
  return first ? cut(first) : "";
}

/** Latest meaningful release of each of the newest minor lines (pure Herald client re-syncs are skipped). */
export function recentUpdates(n = 3): ChangelogEntry[] {
  const seen = new Set<string>();
  const out: ChangelogEntry[] = [];
  for (const e of getChangelog()) {
    if (isHeraldResync(e)) continue;
    const minor = e.version.split(".").slice(0, 2).join(".");
    if (seen.has(minor)) continue;
    seen.add(minor);
    out.push(e);
    if (out.length === n) break;
  }
  return out;
}
