import PEAKS from "./peaks.json";

export type Key = "herald-email-3" | "herald-email-4" | "herald-contra";
export const SAMPLES = PEAKS as Record<Key, { dur: number; peaks: number[] }>;
export const WIN = 0.04;
export const fmt = (t: number) => `${Math.floor(t / 60)}:${(Math.floor(t * 10) / 10 % 60).toFixed(1).padStart(4, "0")}`;
// level of bar i of n (0 = oldest) at time t: the real peaks of the n most recent 40 ms windows
export const barLevel = (key: Key, t: number, i: number, n: number) => {
  const pk = SAMPLES[key].peaks;
  const at = Math.floor(t / WIN) - (n - 1 - i);
  return 0.18 + 0.82 * (pk[Math.max(0, Math.min(pk.length - 1, at))] ?? 0);
};
