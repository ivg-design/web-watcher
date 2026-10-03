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

/** Short one-line summary of an entry for the landing page list. */
export function summarize(e: ChangelogEntry): string {
  const firsts = e.sections.flatMap((s) => s.items).slice(0, 3);
  const text = firsts
    .map((i) => i.replace(/`/g, "").replace(/:\s.*$/, "").replace(/\.$/, ""))
    .join(" · ");
  return text.length > 190 ? `${text.slice(0, 187).trimEnd()}…` : text;
}

/** The three latest meaningful releases (pure Herald client re-syncs are skipped). */
export function recentUpdates(n = 3): ChangelogEntry[] {
  return getChangelog().filter((e) => !isHeraldResync(e)).slice(0, n);
}
