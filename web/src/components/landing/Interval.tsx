"use client";

import { useEffect, useRef, useState } from "react";
import { useWatch } from "@/components/watch/WatchContext";
import "@/styles/interval.css";

const OPTIONS: { s: number; label: string }[] = [
  { s: 15, label: "15 seconds" },
  { s: 30, label: "30 seconds" },
  { s: 60, label: "1 minute" },
  { s: 120, label: "2 minutes" },
  { s: 300, label: "5 minutes" },
  { s: 600, label: "10 minutes" },
  { s: 1800, label: "30 minutes" },
];

const fmt = (n: number) => n.toLocaleString("en-US");
const perDay = (s: number) => Math.round(86400 / s);

/** A value that rolls one step when it changes. The testid sits on the live (current) node. */
function Roll({ value, testId, innerRef }: { value: string; testId: string; innerRef?: React.Ref<HTMLSpanElement> }) {
  const [prev, setPrev] = useState<{ v: string; k: number } | null>(null);
  const last = useRef(value);
  const n = useRef(0);
  useEffect(() => {
    if (last.current === value) return;
    n.current += 1;
    const k = n.current;
    setPrev({ v: last.current, k });
    last.current = value;
    const t = setTimeout(() => setPrev((p) => (p && p.k === k ? null : p)), 220);
    return () => clearTimeout(t);
  }, [value]);
  return (
    <span className="roll t-num">
      {prev && <span key={"o" + prev.k} className="roll__v is-out" aria-hidden="true">{prev.v}</span>}
      <span key={value} ref={innerRef} className="roll__v" data-testid={testId}>{value}</span>
    </span>
  );
}

export default function Interval() {
  const { interval, setInterval } = useWatch();
  const band = useRef<HTMLDivElement>(null);
  const dayEl = useRef<HTMLSpanElement>(null);
  const weekEl = useRef<HTMLSpanElement>(null);
  const live = useRef(interval);
  useEffect(() => { live.current = interval; }, [interval]);

  const day = perDay(interval);
  const week = day * 7;
  const label = OPTIONS.find((o) => o.s === interval)?.label ?? `${interval} seconds`;

  // Scroll-driven count-up: once, when the band first enters the viewport.
  useEffect(() => {
    const el = band.current;
    if (!el || typeof IntersectionObserver === "undefined") return;
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    let raf = 0;
    const io = new IntersectionObserver((entries) => {
      if (!entries.some((e) => e.isIntersecting)) return;
      io.disconnect();
      const t0 = performance.now();
      const D = 900;
      const ease = (t: number) => (t >= 1 ? 1 : 1 - Math.pow(2, -10 * t)); // expo out
      const frame = (now: number) => {
        const p = Math.min(1, (now - t0) / D);
        const k = ease(p);
        const d = perDay(live.current);
        if (dayEl.current) dayEl.current.textContent = fmt(Math.round(d * k));
        if (weekEl.current) weekEl.current.textContent = fmt(Math.round(d * 7 * k));
        if (p < 1) raf = requestAnimationFrame(frame);
      };
      if (dayEl.current) dayEl.current.textContent = fmt(0);
      if (weekEl.current) weekEl.current.textContent = fmt(0);
      raf = requestAnimationFrame(frame);
    }, { threshold: 0.25 });
    io.observe(el);
    return () => { io.disconnect(); cancelAnimationFrame(raf); };
  }, []);

  return (
    <section id="interval" className="section ivl night" aria-labelledby="ivl-title">
      <div className="container">
        <div className="ivl__band" ref={band}>
          <h2 id="ivl-title" className="t-cond ivl__title">
            Every <Roll value={label} testId="ivl-every" /> it looks.{" "}
            <Roll value={fmt(day)} testId="ivl-day" innerRef={dayEl} /> looks a day,{" "}
            <Roll value={fmt(week)} testId="ivl-week" innerRef={weekEl} /> a week. You make none of them.
          </h2>
          <div className="ivl__ctl">
            <div role="radiogroup" aria-label="Check interval" className="ivl__chips">
              {OPTIONS.map((o) => (
                <button
                  key={o.s}
                  type="button"
                  role="radio"
                  aria-checked={interval === o.s}
                  data-testid={`ivl-${o.s}`}
                  className="ivl__chip"
                  onClick={() => setInterval(o.s)}
                >
                  {o.label}
                </button>
              ))}
            </div>
            <p className="t-label ivl__hint" data-testid="ivl-hint">
              {interval === 30
                ? "The default. Change it per watcher in the app."
                : `The header hourglass now checks every ${label}. Open it.`}
            </p>
          </div>
        </div>
        <p className="ivl__copy">
          Each watcher has its own timer, set to the interval you pick for it. A check reads the page in a Safari tab that stays in the background. A change posts one notification.
        </p>
      </div>
    </section>
  );
}
