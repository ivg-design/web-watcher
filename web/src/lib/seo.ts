export const CANONICAL_HOST = "https://forge.mograph.life";
export const CANONICAL_BASE_PATH = "/apps/webwatcher";

export function toCanonicalUrl(path = ""): string {
  const p = path.startsWith("/") ? path : `/${path}`;
  if (p === "/") return `${CANONICAL_HOST}${CANONICAL_BASE_PATH}/`;
  return `${CANONICAL_HOST}${CANONICAL_BASE_PATH}${p}`;
}

export const SITE_TITLE = "WebWatcher — Stop refreshing. Start knowing.";
export const SITE_DESCRIPTION =
  "A free, open-source macOS menu bar app that watches the badges, counters and inboxes you keep checking by hand — Safari tabs and Gmail senders — and notifies you the moment they change.";
