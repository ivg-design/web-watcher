"use client";

/**
 * The page's own watcher. Every demo on the landing page reports the change it just produced
 * here, and the mark in the header (the hourglass with the eye) notices: its badge ticks, a
 * notification lands top-right, and the popover lists what it saw. One system, the product's
 * own loop: something changed below; the thing in the menu bar told you.
 *
 * Demos call `record(...)`. The header/HUD owns the rendering of badge, notice and popover.
 */
import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState, useSyncExternalStore } from "react";
import WatchNotices from "./WatchNotices";
import { CHECK_EVENT } from "./events";

declare global {
  interface Window { __ww_setInterval?: (seconds: number) => void }
}

export type WatchSource = "hero" | "steps" | "picker" | "types" | "gmail" | "herald" | "download";

export interface WatchChange {
  id: number;
  at: number;
  source: WatchSource;
  /** Watcher name as it would appear in the popover row, e.g. "Rive Community · bell". */
  name: string;
  /** Notification title, e.g. "Rive Community — 5 new". */
  title: string;
  /** Notification body, e.g. "Badge went 3 → 5". */
  body: string;
  /** Optional icon path (public/), defaults to the app icon. */
  icon?: string;
  /** Short value for the popover row, e.g. "5" or "$1,199.00". */
  value?: string;
}

export type WatchInput = Omit<WatchChange, "id" | "at">;

interface WatchCtx {
  changes: WatchChange[];
  /** Total changes recorded on this page. */
  count: number;
  /** Changes not yet looked at in the popover (drives the badge). */
  unseen: number;
  /** The most recent change, or null. */
  latest: WatchChange | null;
  record: (c: WatchInput) => WatchChange;
  /** Marks everything seen (popover opened). */
  markSeen: () => void;
  clear: () => void;
  /** The site watcher's check interval in seconds (the app's CheckInterval cases; default 30). */
  interval: number;
  setInterval: (seconds: number) => void;
  /** True while the page is running timed checks (false outside the provider and under reduced motion). */
  timed: boolean;
}

const Ctx = createContext<WatchCtx | null>(null);

const RM = "(prefers-reduced-motion: reduce)";
const subscribeMotion = (cb: () => void) => {
  const m = window.matchMedia(RM);
  m.addEventListener("change", cb);
  return () => m.removeEventListener("change", cb);
};

export function WatchProvider({ children }: { children: React.ReactNode }) {
  const [changes, setChanges] = useState<WatchChange[]>([]);
  const [seenUpTo, setSeenUpTo] = useState(0);
  const [interval, setIntervalState] = useState(30);
  const setInterval = useCallback((s: number) => setIntervalState(s), []);
  const nextId = useRef(1);

  const record = useCallback((c: WatchInput) => {
    const change: WatchChange = { ...c, id: nextId.current++, at: Date.now() };
    setChanges((cur) => [change, ...cur].slice(0, 50));
    // The change is seen on the next check, which is now.
    queueMicrotask(() => window.dispatchEvent(new Event(CHECK_EVENT)));
    return change;
  }, []);
  const markSeen = useCallback(() => setSeenUpTo(nextId.current - 1), []);
  const clear = useCallback(() => { setChanges([]); setSeenUpTo(nextId.current - 1); }, []);

  // The page keeps time: a check every `interval` seconds while visible (end state only under reduced motion).
  useEffect(() => {
    window.__ww_setInterval = setInterval;
    return () => { delete window.__ww_setInterval; };
  }, [setInterval]);
  // A check re-arms the timer, so the next one is always `interval` after the last (a recorded change counts as a check).
  const timed = useSyncExternalStore(subscribeMotion, () => !window.matchMedia(RM).matches, () => false);
  useEffect(() => {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    let id = 0;
    const arm = () => {
      window.clearTimeout(id);
      id = window.setTimeout(() => {
        if (document.hidden) arm(); else window.dispatchEvent(new Event(CHECK_EVENT));
      }, interval * 1000);
    };
    arm();
    window.addEventListener(CHECK_EVENT, arm);
    return () => { window.clearTimeout(id); window.removeEventListener(CHECK_EVENT, arm); };
  }, [interval]);

  const value = useMemo<WatchCtx>(() => ({
    changes,
    count: changes.length,
    unseen: changes.filter((c) => c.id > seenUpTo).length,
    latest: changes[0] ?? null,
    record,
    markSeen,
    clear,
    interval,
    setInterval,
    timed,
  }), [changes, seenUpTo, record, markSeen, clear, interval, setInterval, timed]);

  return (
    <Ctx.Provider value={value}>
      {children}
      <WatchNotices />
    </Ctx.Provider>
  );
}

/** Safe outside a provider (docs pages, tests): records are no-ops. */
export function useWatch(): WatchCtx {
  const ctx = useContext(Ctx);
  return ctx ?? NOOP;
}

const NOOP: WatchCtx = {
  changes: [],
  count: 0,
  unseen: 0,
  latest: null,
  record: (c) => ({ ...c, id: 0, at: 0 }),
  markSeen: () => {},
  clear: () => {},
  interval: 30,
  setInterval: () => {},
  timed: false,
};
