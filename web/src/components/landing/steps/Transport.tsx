"use client";

import { useEffect, useRef, useState, type ReactNode } from "react";
import { DURATION, TOTAL_MS, NOTIFY_MS } from "./data";

const STARTS = DURATION.reduce<number[]>((a, d, i) => { a.push(i === 0 ? 0 : a[i - 1] + DURATION[i - 1]); return a; }, []);
const fmt = (ms: number) => {
  const t = Math.min(Math.round(ms / 100), TOTAL_MS / 100);
  return `${String(Math.floor(t / 10)).padStart(2, "0")}.${t % 10}`;
};

interface Props {
  beat: number;
  epoch: number;
  active: boolean;
  reduce: boolean;
  notified: boolean;
  children: ReactNode;
}

/** The transport: the running time, the ruler of the whole run, and the chapters under it. Owns the 10 Hz state. */
export default function Transport({ beat, epoch, active, reduce, notified, children }: Props) {
  const key = `${beat}-${epoch}-${active ? 1 : 0}`;
  const [seg, setSeg] = useState({ key, ms: 0 });

  useEffect(() => {
    if (reduce || !active) return;
    const t0 = performance.now();
    const id = window.setInterval(() => setSeg({ key, ms: Math.floor(Math.min(performance.now() - t0, DURATION[beat]) / 100) * 100 }), 100);
    return () => clearInterval(id);
  }, [beat, key, active, reduce]);

  const now = reduce ? TOTAL_MS : Math.floor(STARTS[beat] / 100) * 100 + (seg.key === key ? seg.ms : 0);

  return (
    <div className="hw-transport">
      <div className="hw-clock" role="timer" aria-label="Seconds into the demo">
        <div className="hw-clock__row">
          <span className="hw-clock__n t-wide t-num" data-testid="hw-clock" aria-hidden="true">{fmt(now)}</span>
          <span className="hw-clock__s t-label" aria-hidden="true">s</span>
        </div>
        <span className="hw-clock__l t-label">seconds into the demo</span>
      </div>
      <div className="hw-track">
        <Ruler now={now} notified={notified} />
        {children}
      </div>
    </div>
  );
}

function Ruler({ now, notified }: { now: number; notified: boolean }) {
  const cv = useRef<HTMLCanvasElement>(null);
  const state = useRef({ now, notified });

  useEffect(() => {
    const c = cv.current;
    if (!c) return;
    const draw = () => {
      const w = c.clientWidth, h = c.clientHeight;
      if (!w) return;
      const dpr = window.devicePixelRatio || 1;
      if (c.width !== Math.round(w * dpr) || c.height !== Math.round(h * dpr)) { c.width = Math.round(w * dpr); c.height = Math.round(h * dpr); }
      const g = c.getContext("2d");
      if (!g) return;
      g.setTransform(dpr, 0, 0, dpr, 0, 0);
      g.clearRect(0, 0, w, h);
      const cs = getComputedStyle(c);
      const ink = cs.getPropertyValue("--n-ink").trim() || "#f4f1ea";
      const dim = cs.getPropertyValue("--n-line-2").trim() || "#555";
      const red = cs.getPropertyValue("--n-signal").trim() || "#e5484d";
      const { now: nowMs, notified: hit } = state.current;
      const steps = TOTAL_MS / 100;
      const step = w < 700 ? 2 : 1;
      const base = h;
      const X = (i: number) => Math.round((i / steps) * (w - 1) * dpr) / dpr + 0.5 / dpr;
      for (let i = 0; i <= steps; i += step) {
        const whole = i % 10 === 0;
        const isRed = hit && i === NOTIFY_MS / 100;
        const th = isRed ? 28 : whole ? 18 : 9;
        g.fillStyle = isRed ? red : i * 100 <= nowMs ? ink : dim;
        g.fillRect(X(i) - 0.5 / dpr, base - th, 1, th);
      }
      if (hit) { // the red tick is also drawn when the step grid skips it
        const i = NOTIFY_MS / 100;
        if (i % step) { g.fillStyle = red; g.fillRect(X(i) - 0.5 / dpr, base - 28, 1, 28); }
      }
      g.fillStyle = ink;
      g.fillRect(X(nowMs / 100) - 0.5 / dpr, base - 34, 1, 34);
    };
    draw();
    const ro = new ResizeObserver(draw);
    ro.observe(c);
    (c as HTMLCanvasElement & { _draw?: () => void })._draw = draw;
    return () => ro.disconnect();
  }, []);

  useEffect(() => {
    state.current = { now, notified };
    (cv.current as (HTMLCanvasElement & { _draw?: () => void }) | null)?._draw?.();
  }, [now, notified]);

  const labels = Array.from({ length: 12 }, (_, s) => s);
  return (
    <div className="hw-ruler">
      <canvas ref={cv} className="hw-ruler__cv" aria-hidden="true" />
      {notified && (
        <span className="hw-notified t-label" data-testid="hw-notified" style={{ left: `${(NOTIFY_MS / TOTAL_MS) * 100}%` }}>t+{(NOTIFY_MS / 1000).toFixed(1)} s notified</span>
      )}
      <div className="hw-ruler__labels" aria-hidden="true">
        {labels.map((s) => (
          <span key={s} className={"t-label" + (s % 2 ? " is-odd" : "")} style={{ left: `${((s * 1000) / TOTAL_MS) * 100}%` }}>{s} s</span>
        ))}
      </div>
    </div>
  );
}
