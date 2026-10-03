export const REPO = "ivg-design/web-watcher";
export const REPO_URL = `https://github.com/${REPO}`;
export const RELEASES_URL = `${REPO_URL}/releases`;
export const HERALD_URL = "https://github.com/ivg-design/herald";
export const DEMO_VIDEO_URL =
  "https://github.com/user-attachments/assets/8adbf24e-0b20-4d1a-8bc1-d2593f2a02f7";
export const DEMO_DURATION = "0:40";

/** Hardcoded fallback used when the GitHub API is unreachable at build time. Refresh per release. */
export const FALLBACK_RELEASE = {
  version: "1.10.9",
  build: "34",
  date: "2026-10-02",
  dmgName: "WebWatcher-1.10.9-build34-macOS.dmg",
  dmgUrl:
    "https://github.com/ivg-design/web-watcher/releases/download/v1.10.9/WebWatcher-1.10.9-build34-macOS.dmg",
  shaUrl:
    "https://github.com/ivg-design/web-watcher/releases/download/v1.10.9/WebWatcher-1.10.9-build34-macOS.dmg.sha256",
  size: 3316341,
};

export const FORGE_LINKS = [
  { label: "Forge hub", href: "https://forge.mograph.life/" },
  { label: "Herald", href: HERALD_URL },
  { label: "RAV", href: "https://forge.mograph.life/apps/rav/" },
  { label: "LERP", href: "https://forge.mograph.life/apps/lerp/" },
  { label: "fNav+", href: "https://forge.mograph.life/apps/fnav-plus/" },
  { label: "Services", href: "https://contra.com/ivg_design" },
];

/** Prefix applied to root-relative links and public files only when served under forge.mograph.life/apps/webwatcher. */
export const BASE_PATH =
  process.env.NODE_ENV === "production" && process.env.NEXT_PUBLIC_SITE_URL?.includes("forge.mograph.life")
    ? "/apps/webwatcher"
    : "";
export const asset = (path: string) => `${BASE_PATH}${path}`;
