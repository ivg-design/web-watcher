"use client";

import { RotateCw } from "lucide-react";
import { useCallback, useEffect, useRef, useState } from "react";
import { useWatch } from "@/components/watch/WatchContext";
import Roll from "./Roll";
import "@/styles/moment.css";

const REFRESHES = 5;
const GAP = 400;

/**
 * The fold's object: a tab that is reloaded by hand five times while the count stays (0), then the
 * moment: the count ticks to (1). Time-driven once, on mount, when in view. Per-frame work lives in
 * refs and the Web Animations API; React state changes only at the discrete steps.
 */
export default function Moment() {
  const { record } = useWatch();
  const recordRef = useRef(record);
  useEffect(() => { recordRef.current = record; }, [record]);

  const rootRef = useRef<HTMLDivElement>(null);
  const glyphRef = useRef<SVGSVGElement>(null);
  const progRef = useRef<HTMLSpanElement>(null);
  const timers = useRef<number[]>([]);
  const reduced = useRef(false);
  const started = useRef(false);

  const [count, setCount] = useState(0);
  const [tab, setTab] = useState(0);
  const [num, setNum] = useState(0);
  const [done, setDone] = useState(false);
  const [instant, setInstant] = useState(false);

  const setLine2 = (lit: boolean) => {
    const el = document.getElementById("hero-line2");
    if (el) el.dataset.lit = lit ? "1" : "0";
  };

  const refresh = useCallback(() => {
    setCount((c) => c + 1);
    if (reduced.current) return;
    glyphRef.current?.animate([{ transform: "rotate(0deg)" }, { transform: "rotate(360deg)" }], { duration: 300, easing: "cubic-bezier(.16,1,.3,1)" });
    progRef.current?.animate([{ transform: "scaleX(0)" }, { transform: "scaleX(1)" }], { duration: 260, easing: "linear" });
  }, []);

  const fire = useCallback(() => {
    setTab(1);
    setNum(1);
    setDone(true);
    setLine2(true);
    recordRef.current({ source: "hero", name: "Contra Inbox", title: "Contra Inbox", body: "You have 1 new message", value: "1" });
  }, []);

  const clear = () => { timers.current.forEach((t) => window.clearTimeout(t)); timers.current = []; };

  const run = useCallback(() => {
    clear();
    setCount(0); setTab(0); setNum(0); setDone(false);
    setLine2(false);
    for (let i = 0; i < REFRESHES; i++) timers.current.push(window.setTimeout(refresh, GAP * (i + 1)));
    timers.current.push(window.setTimeout(fire, GAP * (REFRESHES + 1)));
  }, [refresh, fire]);

  useEffect(() => {
    reduced.current = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    const root = rootRef.current;
    if (reduced.current) {
      // End state at mount; swaps, no rolls.
      setInstant(true);
      setCount(REFRESHES); setTab(1); setNum(1); setDone(true);
      setLine2(true);
      if (!started.current) { started.current = true; recordRef.current({ source: "hero", name: "Contra Inbox", title: "Contra Inbox", body: "You have 1 new message", value: "1" }); }
      return clear;
    }
    if (!root || typeof IntersectionObserver === "undefined") return;
    let visible = false;
    const tryStart = () => {
      if (started.current || !visible || document.hidden) return;
      started.current = true;
      io.disconnect();
      document.removeEventListener("visibilitychange", tryStart);
      run();
    };
    const io = new IntersectionObserver(([e]) => { visible = e.isIntersecting; tryStart(); }, { threshold: 0.3 });
    io.observe(root);
    document.addEventListener("visibilitychange", tryStart);
    return () => { io.disconnect(); document.removeEventListener("visibilitychange", tryStart); clear(); };
  }, [run]);

  const replay = () => {
    if (reduced.current) {
      clear();
      setCount(0); setTab(0); setNum(0); setDone(false); setLine2(false);
      timers.current.push(window.setTimeout(() => { setCount(REFRESHES); fire(); }, 60));
      return;
    }
    run();
  };

  return (
    <div className="mo" ref={rootRef} data-testid="mo">
      <span className="mo__num t-wide t-num" data-testid="mo-num" data-on={num ? "1" : "0"} aria-hidden="true">
        (<Roll v={num} instant={instant} />)
      </span>
      <div className="mo__strip" role="group" aria-label="A Safari tab being reloaded by hand">
        <div className="mo__bar">
          <span className="mo__lights" aria-hidden="true"><i /><i /><i /></span>
          <span className="mo__nav" aria-hidden="true">
            <svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round"><path d="M10 3 5 8l5 5" /></svg>
            <svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round"><path d="m6 3 5 5-5 5" /></svg>
          </span>
          <span className="mo__addr">
            <span className="mo__prog" ref={progRef} aria-hidden="true" />
            <span className="mo__url">contra.com/inbox</span>
            <button type="button" className="mo__reload" data-testid="mo-reload" aria-label="Reload (refreshing by hand)" onClick={refresh}>
              <RotateCw ref={glyphRef} size={14} strokeWidth={2} aria-hidden="true" />
            </button>
          </span>
        </div>
        <div className="mo__tabrow">
          <span className="mo__tab" data-testid="mo-tab">
            (<Roll v={tab} instant={instant} />) Inbox — Contra
          </span>
          <span className="mo__count" data-testid="mo-count">⌘R ×<Roll v={count} instant={instant} /></span>
        </div>
      </div>
      <div className="mo__meta">
        <span className="mo__capwrap" data-show={done ? "1" : "0"}>
          <span className="mo__cap" data-testid="mo-cap">Seen on its next check. You did not have to look.</span>
          <button type="button" className="mo__replay" data-testid="mo-replay" onClick={replay}>Replay</button>
        </span>
      </div>
      <span className="sr-only" aria-live="polite">{done ? "You have 1 new message" : ""}</span>
    </div>
  );
}
