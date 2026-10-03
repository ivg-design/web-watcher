"use client";

/**
 * One-time callout. Every demo stage draws its own banner, so the site itself speaks only once:
 * the first recorded change on a page load slides a small dark chip out of the mark, inside the
 * header ("Logged in your menu bar — click it."). It never leaves the header, so it can never sit on
 * a stage's own banner. Later changes only tick the badge.
 */
import { useCallback, useEffect, useRef, useState } from "react";
import { AnimatePresence, motion, useReducedMotion } from "framer-motion";
import { useWatch, type WatchChange, type WatchInput } from "./WatchContext";
import { OPEN_EVENT, OPENED_EVENT, CLOSED_EVENT } from "./events";
import "@/styles/watch.css";

declare global {
  interface Window { __ww_record?: (c: WatchInput) => WatchChange }
}

const SHOW_MS = 6000;
const EASE = [0.22, 1, 0.36, 1] as const;
const W = 360;

/** The chip lives INSIDE the header, immediately left of the mark, so it can never collide with a stage's own banner. */
interface Place { top: number; right: number; maxWidth: number; height: number; fill: boolean }

function place(): Place {
  const r = document.querySelector('[data-testid="watch-mark"]')?.getBoundingClientRect();
  if (!r) return { top: 20, right: 60, maxWidth: Math.min(W, document.documentElement.clientWidth - 32), height: 36, fill: false };
  const brand = document.querySelector(".site-header .brand img")?.getBoundingClientRect();
  const left = brand ? brand.right + 10 : 16;
  const height = 36;
  // the fixed-position viewport excludes the scrollbar: measure the fixed inset:0 container itself
  const vw = document.querySelector(".ww-notices")?.getBoundingClientRect().width || document.documentElement.clientWidth;
  const right = vw - r.left + 8;
  // On narrow headers the chip fills the space between the app icon and the mark, covering the wordmark cleanly.
  return { top: r.top + (r.height - height) / 2, right, maxWidth: Math.max(96, Math.min(W, r.left - 8 - left)), height, fill: window.innerWidth < 600 };
}

export default function WatchNotices() {
  const { latest, record } = useWatch();
  const reduce = useReducedMotion();
  const [shown, setShown] = useState<WatchChange | null>(null);
  const [pos, setPos] = useState<Place>({ top: 20, right: 60, maxWidth: W, height: 36, fill: false });
  const used = useRef(false);
  const popOpen = useRef(false);
  const lastId = useRef(0);
  const timer = useRef(0);
  const remaining = useRef(SHOW_MS);
  const startedAt = useRef(0);

  useEffect(() => {
    window.__ww_record = record;
    return () => { delete window.__ww_record; };
  }, [record]);

  const dismiss = useCallback(() => { window.clearTimeout(timer.current); setShown(null); }, []);
  const arm = useCallback((ms: number) => {
    window.clearTimeout(timer.current);
    remaining.current = ms;
    startedAt.current = performance.now();
    timer.current = window.setTimeout(dismiss, ms);
  }, [dismiss]);

  // Popover open: the callout has done its job.
  useEffect(() => {
    const onOpened = () => { popOpen.current = true; dismiss(); };
    const onClosed = () => { popOpen.current = false; };
    window.addEventListener(OPENED_EVENT, onOpened);
    window.addEventListener(CLOSED_EVENT, onClosed);
    return () => { window.removeEventListener(OPENED_EVENT, onOpened); window.removeEventListener(CLOSED_EVENT, onClosed); };
  }, [dismiss]);

  // Only the first change on this page load gets a callout.
  useEffect(() => {
    if (!latest || latest.id === lastId.current) return;
    lastId.current = latest.id;
    if (used.current) return;
    used.current = true;
    if (popOpen.current) return;
    // Anchor to the live mark position (header is sticky, so this is stable).
    window.setTimeout(() => { setPos(place()); setShown(latest); arm(SHOW_MS); }, 0);
  }, [latest, arm]);

  useEffect(() => () => window.clearTimeout(timer.current), []);

  const pause = () => {
    window.clearTimeout(timer.current);
    remaining.current = Math.max(600, remaining.current - (performance.now() - startedAt.current));
  };
  const resume = () => arm(remaining.current);

  return (
    <div className="ww-notices" aria-live="polite" aria-atomic="true">
      <AnimatePresence>
        {shown && (
          <motion.button
            key={shown.id}
            type="button"
            className="ww-notice"
            data-testid="watch-notice"
            style={{ top: pos.top, right: pos.right, maxWidth: pos.maxWidth, minWidth: pos.fill ? pos.maxWidth : undefined, height: pos.height }}
            onMouseEnter={pause}
            onMouseLeave={resume}
            onFocus={pause}
            onBlur={resume}
            onClick={() => { dismiss(); window.dispatchEvent(new Event(OPEN_EVENT)); }}
            initial={reduce ? { opacity: 0 } : { opacity: 0, x: 10 }}
            animate={{ opacity: 1, x: 0, transition: { duration: 0.28, ease: EASE } }}
            exit={{ opacity: 0, x: reduce ? 0 : 8, transition: { duration: 0.2, ease: EASE } }}
          >
            <b className="ww-notice__title">{shown.title}</b>
            <small className="ww-notice__hint ww-notice__hint--l">Logged in your menu bar — click it.</small>
            <small className="ww-notice__hint ww-notice__hint--s" aria-hidden="true">Logged here</small>
            <span className="ww-notice__arrow" aria-hidden="true">→</span>
          </motion.button>
        )}
      </AnimatePresence>
    </div>
  );
}
