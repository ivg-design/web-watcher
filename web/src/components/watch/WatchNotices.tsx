"use client";

/**
 * One-time callout. Every demo stage draws its own banner, so the site itself speaks only once:
 * the first recorded change on a page load slides a small dark chip out of the mark, inside the
 * header ("Logged in your menu bar — click it."). It never leaves the header, so it can never sit on
 * a stage's own banner. Later changes only tick the badge.
 */
import { useCallback, useEffect, useRef, useState } from "react";
import { useWatch, type WatchChange, type WatchInput } from "./WatchContext";
import { OPEN_EVENT, OPENED_EVENT, CLOSED_EVENT } from "./events";
import "@/styles/watch.css";

declare global {
  interface Window { __ww_record?: (c: WatchInput) => WatchChange }
}

const SHOW_MS = 6000;
const W = 360;

/** The chip hangs UNDER the mark (header bottom + 8 px, right edge on the mark), so it never covers the nav. */
interface Place { top: number; right: number; maxWidth: number; arrow: number }

function place(): Place {
  const vw = document.querySelector(".ww-notices")?.getBoundingClientRect().width || document.documentElement.clientWidth;
  const maxWidth = Math.min(W, vw - 32);
  const r = document.querySelector('[data-testid="watch-mark"]')?.getBoundingClientRect();
  const hb = document.querySelector("header.site-header")?.getBoundingClientRect().bottom ?? 64;
  if (!r) return { top: hb + 8, right: 16, maxWidth, arrow: 24 };
  const right = Math.max(16, Math.min(vw - r.right, vw - 16 - maxWidth));
  // arrow centre sits over the mark centre
  const arrow = Math.max(12, Math.min(maxWidth - 24, r.left + r.width / 2 - (vw - right - maxWidth)));
  return { top: hb + 8, right, maxWidth, arrow };
}

export default function WatchNotices() {
  const { latest, record } = useWatch();
  const [shown, setShown] = useState<WatchChange | null>(null);
  const [pos, setPos] = useState<Place>({ top: 72, right: 16, maxWidth: W, arrow: 24 });
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
    // Stacked layouts: the hero's own moment sits right under the header, so its record only ticks the badge; the chip waits for the first demo.
    if (latest.source === "hero" && window.innerWidth < 1100) return;
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
      {shown && (
        <button
          key={shown.id}
          type="button"
          className="ww-notice"
          data-testid="watch-notice"
          style={{ top: pos.top, right: pos.right, width: pos.maxWidth, maxWidth: pos.maxWidth, ["--arrow-x" as string]: `${pos.arrow}px` }}
          onMouseEnter={pause}
          onMouseLeave={resume}
          onFocus={pause}
          onBlur={resume}
          onClick={() => { dismiss(); window.dispatchEvent(new Event(OPEN_EVENT)); }}
        >
          <span className="ww-notice__arrow" aria-hidden="true">↑</span>
          <span className="ww-notice__txt">
            <b className="ww-notice__title">{shown.title}</b>
            <small className="ww-notice__hint ww-notice__hint--l">Logged in your menu bar. Click it.</small>
          </span>
        </button>
      )}
    </div>
  );
}
