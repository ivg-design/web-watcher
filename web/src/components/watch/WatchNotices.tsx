"use client";

/** macOS-style notification for each recorded change. One at a time; a new change replaces the current one after a 150 ms gap. */
import { useCallback, useEffect, useRef, useState } from "react";
import { AnimatePresence, motion, useReducedMotion } from "framer-motion";
import { asset } from "@/lib/config";
import { useWatch, type WatchChange, type WatchInput } from "./WatchContext";
import { OPEN_EVENT, OPENED_EVENT, CLOSED_EVENT } from "./events";
import "@/styles/watch.css";

declare global {
  interface Window { __ww_record?: (c: WatchInput) => WatchChange }
}

const SHOW_MS = 4500;
const GAP_MS = 150;
const EASE = [0.22, 1, 0.36, 1] as const;

export default function WatchNotices() {
  const { latest, record } = useWatch();
  const reduce = useReducedMotion();
  const [shown, setShown] = useState<WatchChange | null>(null);
  const [hintId, setHintId] = useState(0);
  const hintUsed = useRef(false);
  const popOpen = useRef(false);
  const shownRef = useRef<WatchChange | null>(null);
  const lastId = useRef(0);
  const timer = useRef(0);
  const remaining = useRef(SHOW_MS);
  const startedAt = useRef(0);

  useEffect(() => {
    window.__ww_record = record;
    return () => { delete window.__ww_record; };
  }, [record]);

  const dismiss = useCallback(() => { window.clearTimeout(timer.current); shownRef.current = null; setShown(null); }, []);
  const arm = useCallback((ms: number) => {
    window.clearTimeout(timer.current);
    remaining.current = ms;
    startedAt.current = performance.now();
    timer.current = window.setTimeout(dismiss, ms);
  }, [dismiss]);

  // Popover open: no notice may overlap it.
  useEffect(() => {
    const onOpened = () => { popOpen.current = true; dismiss(); };
    const onClosed = () => { popOpen.current = false; };
    window.addEventListener(OPENED_EVENT, onOpened);
    window.addEventListener(CLOSED_EVENT, onClosed);
    return () => { window.removeEventListener(OPENED_EVENT, onOpened); window.removeEventListener(CLOSED_EVENT, onClosed); };
  }, [dismiss]);

  useEffect(() => {
    if (!latest || latest.id === lastId.current) return;
    lastId.current = latest.id;
    const show = () => {
      if (popOpen.current) return;
      if (!hintUsed.current) { hintUsed.current = true; setHintId(latest.id); }
      shownRef.current = latest; setShown(latest); arm(SHOW_MS);
    };
    if (shownRef.current) {
      dismiss();
      const t = window.setTimeout(show, GAP_MS + 240);
      return () => window.clearTimeout(t);
    }
    show();
  }, [latest, arm, dismiss]);

  useEffect(() => () => window.clearTimeout(timer.current), []);

  const pause = () => {
    window.clearTimeout(timer.current);
    remaining.current = Math.max(600, remaining.current - (performance.now() - startedAt.current));
  };
  const resume = () => arm(remaining.current);

  return (
    <div className="ww-notices" aria-live="polite" aria-atomic="true">
      <AnimatePresence mode="wait">
        {shown && (
          <motion.button
            key={shown.id}
            type="button"
            className="ww-notice"
            data-testid="watch-notice"
            onMouseEnter={pause}
            onMouseLeave={resume}
            onFocus={pause}
            onBlur={resume}
            onClick={() => { dismiss(); window.dispatchEvent(new Event(OPEN_EVENT)); }}
            initial={reduce ? { opacity: 0 } : { opacity: 0, x: 56 }}
            animate={{ opacity: 1, x: 0, transition: { duration: 0.32, ease: EASE } }}
            exit={{ opacity: 0, x: reduce ? 0 : 28, transition: { duration: 0.24, ease: EASE } }}
          >
            { }
            <img src={asset(shown.icon ?? "/images/webwatcher-icon.png")} alt="" width={36} height={36} />
            <span className="ww-notice__txt">
              <b>{shown.title}</b>
              <span>{shown.body}</span>
            </span>
            <time>now</time>
            {hintId === shown.id && <small className="ww-notice__hint">Your watcher in the menu bar noticed. Click it.</small>}
          </motion.button>
        )}
      </AnimatePresence>
    </div>
  );
}
