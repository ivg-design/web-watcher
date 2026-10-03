import { FALLBACK_RELEASE, REPO } from "./config";
import { getChangelog } from "./changelog";

export interface LatestRelease {
  version: string;
  build: string;
  date: string;
  dmgName: string;
  dmgUrl: string;
  shaUrl: string;
  sha: string | null;
  sizeMb: string;
  monthYear: string;
}

interface GhAsset { name: string; size: number; browser_download_url: string }

async function fetchJson<T>(url: string): Promise<T | null> {
  try {
    const res = await fetch(url, {
      headers: { Accept: "application/vnd.github+json" },
      signal: AbortSignal.timeout(8000),
    });
    return res.ok ? ((await res.json()) as T) : null;
  } catch {
    return null;
  }
}

let cached: Promise<LatestRelease> | null = null;

/** Latest release from the GitHub API at build time, falling back to the hardcoded asset. */
export function getLatestRelease(): Promise<LatestRelease> {
  cached ??= load();
  return cached;
}

async function load(): Promise<LatestRelease> {
  const fb = FALLBACK_RELEASE;
  const gh = await fetchJson<{ tag_name: string; published_at: string; assets: GhAsset[] }>(
    `https://api.github.com/repos/${REPO}/releases/latest`,
  );
  const dmg = gh?.assets.find((a) => a.name.endsWith(".dmg"));
  const sha = gh?.assets.find((a) => a.name.endsWith(".sha256"));

  let version = fb.version;
  let build = fb.build;
  let date = fb.date;
  let dmgName = fb.dmgName;
  let dmgUrl = fb.dmgUrl;
  let shaUrl = fb.shaUrl;
  let size = fb.size;

  if (gh && dmg) {
    version = gh.tag_name.replace(/^v/, "");
    dmgName = dmg.name;
    dmgUrl = dmg.browser_download_url;
    shaUrl = sha?.browser_download_url ?? `${dmg.browser_download_url}.sha256`;
    size = dmg.size;
    date = gh.published_at.slice(0, 10);
    build = dmg.name.match(/build(\d+)/)?.[1] ?? build;
  }
  // The changelog is the source of truth for build number and date.
  const entry = getChangelog().find((e) => e.version === version);
  if (entry) {
    if (entry.build) build = entry.build;
    date = entry.date;
  }

  let shaText: string | null = null;
  try {
    const res = await fetch(shaUrl, { signal: AbortSignal.timeout(8000) });
    if (res.ok) shaText = (await res.text()).trim().split(/\s+/)[0] ?? null;
  } catch {
    shaText = null;
  }

  const d = new Date(`${date}T00:00:00Z`);
  return {
    version, build, date, dmgName, dmgUrl, shaUrl,
    sha: shaText && /^[0-9a-f]{64}$/i.test(shaText) ? shaText : null,
    sizeMb: `${Math.max(1, Math.round(size / 1048576))} MB`,
    monthYear: d.toLocaleString("en-US", { month: "long", year: "numeric", timeZone: "UTC" }),
  };
}
