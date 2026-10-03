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

const timeFmt = new Intl.DateTimeFormat("en-US", { hour: "numeric", minute: "2-digit", hour12: true });
const BONE = "#f3f1ec";
const REST = "#5b606c";

/**
 * The hour, ruled: one tick per check at the chosen interval, from the top of the hour to the next.
 * Ticks already behind the real clock are lit. On narrow screens the span drops to ten minutes so
 * ticks stay apart. Drawn on a canvas at device pixels so 240 one-pixel ticks stay sharp.
 */
function HourRuler({ interval }: { interval: number }) {
  const wrap = useRef<HTMLDivElement>(null);
  const canvas = useRef<HTMLCanvasElement>(null);
  const [width, setWidth] = useState(0);
  const [now, setNow] = useState<number | null>(null);

  useEffect(() => {
    const el = wrap.current;
    if (!el) return;
    const ro = new ResizeObserver(() => setWidth(el.clientWidth));
    ro.observe(el);
    const tick = () => setNow(Math.floor(Date.now() / 1000));
    tick();
    const id = window.setInterval(tick, 1000);
    return () => { ro.disconnect(); window.clearInterval(id); };
  }, []);

  // Span: the hour, unless its ticks would sit under 4 px apart; then ten minutes.
  const span = width > 0 && interval < 600 && width / (3600 / interval) < 4 ? 600 : 3600;
  const total = Math.max(1, Math.round(span / interval));
  const local = now === null ? null : now - new Date(now * 1000).getTimezoneOffset() * 60;
  const start = local === null ? null : local - (local % span);
  const elapsed = local === null || start === null ? 0 : local - start;
  const lit = Math.floor(elapsed / interval);
  const hourLit = local === null ? 0 : Math.floor((local % 3600) / interval);
  const hourTotal = Math.round(3600 / interval);

  useEffect(() => {
    const c = canvas.current;
    if (!c || !width) return;
    const dpr = Math.min(3, window.devicePixelRatio || 1);
    const H = 56;
    c.width = Math.round(width * dpr);
    c.height = Math.round(H * dpr);
    const g = c.getContext("2d");
    if (!g) return;
    g.clearRect(0, 0, c.width, c.height);
    const w = Math.max(1, Math.round(dpr));
    const major = span === 3600 ? 300 : 60; // five-minute or one-minute marks stand taller
    for (let i = 0; i <= total; i++) {
      const t = i * interval;
      const x = Math.min(c.width - w, Math.round((t / span) * (c.width - w)));
      const tall = t % major === 0;
      const h = Math.round((tall ? 40 : 24) * dpr);
      g.fillStyle = i <= lit && now !== null ? BONE : REST;
      g.fillRect(x, c.height - h, w, h);
    }
  }, [width, interval, span, total, lit, now === null]); // eslint-disable-line react-hooks/exhaustive-deps

  const label = (sec: number) => timeFmt.format(new Date((sec + new Date(sec * 1000).getTimezoneOffset() * 60) * 1000));
  const marks = start === null ? [] : (span === 3600 ? [0, 900, 1800, 2700, 3600] : [0, 300, 600]).map((o) => ({ o, text: label(start + o) }));
  const pct = (elapsed / span) * 100;

  return (
    <div className="ivl__ruler" data-testid="ivl-ruler" data-span={span} data-ticks={total} data-lit={lit}>
      <p className="ivl__since t-label" data-testid="ivl-since">
        {start === null || local === null
          ? `A watcher on this interval looks ${fmt(hourTotal)} ${hourTotal === 1 ? "time" : "times"} an hour.`
          : <>Since {label(local - (local % 3600))} a watcher on this interval has looked <b className="t-num">{fmt(hourLit)}</b> {hourLit === 1 ? "time" : "times"}. {fmt(hourTotal - hourLit)} to go before {label(local - (local % 3600) + 3600)}.</>}
      </p>
      <div className="ivl__rule" ref={wrap} aria-hidden="true">
        <canvas ref={canvas} />
        {start !== null && <i className="ivl__now" data-edge={pct < 6 ? "s" : pct > 94 ? "e" : undefined} style={{ left: `${pct}%` }}><span>{label(local ?? 0)}</span></i>}
      </div>
      <div className="ivl__marks t-label" aria-hidden="true">
        {marks.map((m) => <span key={m.o} style={{ left: `${(m.o / span) * 100}%` }} data-edge={m.o === 0 ? "s" : m.o === span ? "e" : undefined}>{m.text}</span>)}
      </div>
    </div>
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
          <div className="ivl__main">
          <h2 id="ivl-title" className="t-cond ivl__title">
            Every <Roll value={label} testId="ivl-every" /> it looks.{" "}
            <Roll value={fmt(day)} testId="ivl-day" innerRef={dayEl} /> looks a day,{" "}
            <Roll value={fmt(week)} testId="ivl-week" innerRef={weekEl} /> a week. You make none of them.
          </h2>
          <p className="ivl__copy">
            Each watcher has its own timer, set to the interval you pick for it. A check reads the page from a Safari tab, and opens one in the background if there is none. A change posts one notification.
          </p>
          </div>
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
                  <span>{o.label}</span>
                  <span className="ivl__n">{fmt(perDay(o.s))} a day</span>
                </button>
              ))}
            </div>
            <p className="t-label ivl__hint" data-testid="ivl-hint">
              {interval === 30
                ? "The default. Change it per watcher in the app."
                : `The header hourglass now checks every ${label}. Open it.`}
            </p>
          </div>
          <HourRuler interval={interval} />
        </div>
      </div>
    </section>
  );
}
