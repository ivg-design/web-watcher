"use client";

/**
 * The page's own watcher. Every demo on the landing page reports the change it just produced
 * here, and the mark in the header (the hourglass with the eye) notices: its badge ticks, a
 * notification lands top-right, and the popover lists what it saw. One system, the product's
 * own loop: something changed below; the thing in the menu bar told you.
 *
 * Demos call `record(...)`. The header/HUD owns the rendering of badge, notice and popover.
 */
import { createContext, useCallback, useContext, useMemo, useRef, useState } from "react";
import WatchNotices from "./WatchNotices";

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
}

const Ctx = createContext<WatchCtx | null>(null);

export function WatchProvider({ children }: { children: React.ReactNode }) {
  const [changes, setChanges] = useState<WatchChange[]>([]);
  const [seenUpTo, setSeenUpTo] = useState(0);
  const nextId = useRef(1);

  const record = useCallback((c: WatchInput) => {
    const change: WatchChange = { ...c, id: nextId.current++, at: Date.now() };
    setChanges((cur) => [change, ...cur].slice(0, 50));
    return change;
  }, []);
  const markSeen = useCallback(() => setSeenUpTo(nextId.current - 1), []);
  const clear = useCallback(() => { setChanges([]); setSeenUpTo(nextId.current - 1); }, []);

  const value = useMemo<WatchCtx>(() => ({
    changes,
    count: changes.length,
    unseen: changes.filter((c) => c.id > seenUpTo).length,
    latest: changes[0] ?? null,
    record,
    markSeen,
    clear,
  }), [changes, seenUpTo, record, markSeen, clear]);

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
};
