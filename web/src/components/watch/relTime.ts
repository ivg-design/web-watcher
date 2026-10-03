export function relTime(at: number, now = Date.now()): string {
  const s = Math.max(0, Math.round((now - at) / 1000));
  if (s < 45) return "just now";
  const m = Math.round(s / 60);
  if (m < 60) return `${Math.max(1, m)} min ago`;
  return `${Math.round(m / 60)} h ago`;
}

const LABELS: Record<number, string> = { 15: "15 seconds", 30: "30 seconds", 60: "1 minute", 120: "2 minutes", 300: "5 minutes", 600: "10 minutes", 1800: "30 minutes" };
/** The app's CheckInterval labels. */
export function intervalLabel(seconds: number): string {
  return LABELS[seconds] ?? (seconds % 60 === 0 ? `${seconds / 60} minutes` : `${seconds} seconds`);
}
