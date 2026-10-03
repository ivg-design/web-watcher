"use client";

/**
 * The page's watcher: the hourglass with the eye. SVG renderer ships first (SSR-safe, always
 * works); the Rive renderer swaps in once /rive/watcher-mark.riv exists and loads.
 * Eye = watching (follows the cursor), sand = interval, flip = check, badge = unseen changes.
 */
import { useCallback, useEffect, useId, useRef, useState, type ComponentType } from "react";
import { asset } from "@/lib/config";
import { useWatch } from "./WatchContext";
import WatchPopover, { type Anchor } from "./WatchPopover";
import { OPEN_EVENT, CHECK_EVENT, OPENED_EVENT, CLOSED_EVENT, WINK_EVENT } from "./events";
import "@/styles/watch.css";

type RiveComp = ComponentType<import("./WatchMarkRive").RiveProps>;

const RIVE_SRC = "/rive/watcher-mark.riv";
let riveProbe: Promise<boolean> | null = null;
function probeRive(): Promise<boolean> {
  riveProbe ??= fetch(asset(RIVE_SRC), { method: "HEAD" })
    .then((r) => r.ok && !(r.headers.get("content-type") ?? "").includes("text/html"))
    .catch(() => false);
  return riveProbe;
}

// Geometry measured off the Rive mark (36px box, artboard 48 at 0.69): SVG phase must match within ~1px.
const TOP = "M9.8 8.3H20.6V11.4L16.4 18.7H14L9.8 11.4Z";
const BOT = "M9.8 29.1H20.6V26L16.4 18.7H14L9.8 26Z";
const EYE = "M22.6 28C24.6 24.8 26.2 23.4 28 23.4C29.8 23.4 31.4 24.8 33.4 28C31.4 31.2 29.8 32.6 28 32.6C26.2 32.6 24.6 31.2 22.6 28Z";
const LOOK_X = 2.8; // Rive: +-4 px of 48 -> 0.69 scale
const LOOK_Y = 2.1;
const clamp = (v: number) => Math.max(-1, Math.min(1, v));

export default function WatchMark() {
  const { unseen, count, changes, markSeen, interval } = useWatch();
  const uid = useId().replace(/:/g, "");
  const btnRef = useRef<HTMLButtonElement>(null);
  const irisRef = useRef<SVGGElement>(null);
  const eyeRef = useRef<SVGGElement>(null);
  const flipRef = useRef<SVGGElement>(null);
  const glassRef = useRef<SVGGElement>(null);
  const sinkRef = useRef<((x: number, y: number) => void) | null>(null);

  const [renderer, setRenderer] = useState<"svg" | "rive">("svg");
  const [mountRive, setMountRive] = useState(false);
  // The Rive file's sand is bound to a view-model number the page writes (progress of the current check), so it
  // follows every interval and the Rive renderer is the one on screen once it has loaded; the SVG is the fallback.
  const shown: "svg" | "rive" = renderer;
  const [hover, setHover] = useState(false);
  const [reduced, setReduced] = useState(false);
  const [tickSignal, setTickSignal] = useState(0);
  const [anchor, setAnchor] = useState<Anchor | null>(null);
  const [lastCheck, setLastCheck] = useState(() => Date.now());

  // Rive is deferred: gated (see below), then after idle (fallback 1200 ms), only while the mark is in the viewport.
  // Probe the file, then import the runtime chunk.
  const [RiveComp, setRiveComp] = useState<RiveComp | null>(null);
  useEffect(() => {
    let live = true;
    let started = false;
    let idleId = 0;
    let timer = 0;
    let io: IntersectionObserver | null = null;
    const w = window as Window & { requestIdleCallback?: (cb: () => void) => number; cancelIdleCallback?: (id: number) => void };
    const go = async () => {
      if (started) return;
      started = true;
      io?.disconnect();
      if (!(await probeRive()) || !live) return;
      const mod = await import("./WatchMarkRive").catch(() => null);
      if (live && mod) { setRiveComp(() => mod.default); setMountRive(true); }
    };
    const whenVisible = () => {
      const b = btnRef.current;
      if (!b || typeof IntersectionObserver === "undefined") { void go(); return; }
      io = new IntersectionObserver((es) => { if (es.some((e) => e.isIntersecting)) void go(); });
      io.observe(b);
    };
    const schedule = () => {
      if (!live) return;
      if (w.requestIdleCallback) idleId = w.requestIdleCallback(whenVisible);
      else timer = window.setTimeout(whenVisible, 1200);
    };
    // Never compete with the page load: start only once `load` has fired.
    // Skip entirely: reduced motion, Save-Data / 2g, or touch-sized screens (eye-follow is a no-op there).
    const conn = (navigator as Navigator & { connection?: { saveData?: boolean; effectiveType?: string } }).connection;
    if (
      window.matchMedia("(prefers-reduced-motion: reduce)").matches ||
      conn?.saveData ||
      /2g$/.test(conn?.effectiveType ?? "") ||
      (window.matchMedia("(pointer: coarse)").matches && window.innerWidth < 640)
    ) return;
    // Then wait for page load AND a first pointermove/scroll/keydown, so a bounce visit never pays for it.
    let loaded = document.readyState === "complete";
    let touched = false;
    let kicked = false;
    const maybe = () => { if (loaded && touched && !kicked) { kicked = true; schedule(); } };
    const onLoad = () => { loaded = true; maybe(); };
    const onTouch = () => { touched = true; maybe(); };
    const EVTS = ["pointermove", "scroll", "keydown"] as const;
    for (const e of EVTS) window.addEventListener(e, onTouch, { once: true, passive: true });
    if (!loaded) window.addEventListener("load", onLoad, { once: true });
    return () => {
      live = false;
      window.removeEventListener("load", onLoad);
      for (const e of EVTS) window.removeEventListener(e, onTouch);
      io?.disconnect();
      if (idleId) w.cancelIdleCallback?.(idleId);
      window.clearTimeout(timer);
    };
  }, []);

  // Reduced motion (loop off, eye still follows).
  useEffect(() => {
    const mq = window.matchMedia("(prefers-reduced-motion: reduce)");
    const sync = () => setReduced(mq.matches);
    sync();
    mq.addEventListener("change", sync);
    return () => mq.removeEventListener("change", sync);
  }, []);

  // Cursor-following eye: normalised -1..1 relative to the mark centre, damped with rAF.
  useEffect(() => {
    const target = { x: 0, y: 0 };
    const ptr = { x: 0, y: 0, t: -1e9 };
    let lastScroll = window.scrollY;
    let settle = 0;
    const cur = { x: 0, y: 0 };
    let raf = 0;
    const apply = () => {
      irisRef.current?.style.setProperty("transform", `translate(${(cur.x * LOOK_X).toFixed(2)}px, ${(cur.y * LOOK_Y).toFixed(2)}px)`);
      const b = btnRef.current;
      if (b) { b.dataset.lookX = cur.x.toFixed(3); b.dataset.lookY = cur.y.toFixed(3); }
      sinkRef.current?.(cur.x, cur.y);
    };
    const loop = () => {
      cur.x += (target.x - cur.x) * 0.16;
      cur.y += (target.y - cur.y) * 0.16;
      apply();
      raf = Math.abs(target.x - cur.x) + Math.abs(target.y - cur.y) > 0.002 ? requestAnimationFrame(loop) : 0;
    };
    const pointerActive = () => performance.now() - ptr.t < 1500;
    const onScroll = () => {
      const d = window.scrollY - lastScroll;
      lastScroll = window.scrollY;
      if (!d || pointerActive()) return;
      target.y = clamp(d / 40);
      if (!raf) raf = requestAnimationFrame(loop);
      window.clearTimeout(settle);
      settle = window.setTimeout(() => {
        target.y = pointerActive() ? ptr.y : 0;
        if (!raf) raf = requestAnimationFrame(loop);
      }, 120);
    };
    const onMove = (e: PointerEvent) => {
      if (e.pointerType === "touch") return;
      const r = btnRef.current?.getBoundingClientRect();
      if (!r) return;
      const cx = r.left + r.width / 2;
      const cy = r.top + r.height / 2;
      ptr.x = clamp((e.clientX - cx) / Math.max(cx, window.innerWidth - cx, 1));
      ptr.y = clamp((e.clientY - cy) / Math.max(cy, window.innerHeight - cy, 1));
      ptr.t = performance.now();
      target.x = ptr.x;
      target.y = ptr.y;
      if (!raf) raf = requestAnimationFrame(loop);
    };
    apply();
    window.addEventListener("pointermove", onMove, { passive: true });
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => { window.removeEventListener("pointermove", onMove); window.removeEventListener("scroll", onScroll); window.clearTimeout(settle); cancelAnimationFrame(raf); };
  }, []);

  // Blink: hover >= 3 s, then every ~4 s while hovered.
  const blink = useCallback(() => {
    eyeRef.current?.animate(
      [{ transform: "scaleY(1)" }, { transform: "scaleY(0.08)", offset: 0.45 }, { transform: "scaleY(1)" }],
      { duration: 200, easing: "cubic-bezier(0.25, 1, 0.5, 1)" },
    );
  }, []);
  useEffect(() => {
    if (!hover || reduced) return;
    let iv = 0;
    const stop = () => { window.clearInterval(iv); iv = 0; };
    const start = () => { if (!iv && !document.hidden) iv = window.setInterval(blink, 4000); };
    const onVis = () => (document.hidden ? stop() : start());
    const t = window.setTimeout(() => { if (!document.hidden) blink(); start(); }, 3000);
    document.addEventListener("visibilitychange", onVis);
    return () => { window.clearTimeout(t); stop(); document.removeEventListener("visibilitychange", onVis); };
  }, [hover, reduced, blink]);

  // New change -> tick.
  const prevCount = useRef(count);
  useEffect(() => {
    if (count > prevCount.current) setTickSignal((n) => n + 1);
    prevCount.current = count;
  }, [count]);

  // Check -> flip the glass, restart the sand loop.
  const flip = useCallback(() => {
    const flipEl = flipRef.current;
    const glass = glassRef.current;
    setLastCheck(Date.now());
    setTickSignal((n) => n + 1);
    if (!flipEl || reduced) return;
    const a = flipEl.animate([{ transform: "rotate(0deg)" }, { transform: "rotate(180deg)" }], { duration: 500, easing: "cubic-bezier(0.22, 1, 0.36, 1)" });
    a.onfinish = () => {
      if (!glass) return;
      glass.style.animation = "none";
      void glass.getBoundingClientRect();
      glass.style.animation = "";
    };
  }, [reduced]);

  const open = useCallback(() => {
    const r = btnRef.current?.getBoundingClientRect();
    if (!r) return;
    setAnchor({ top: r.bottom + 8, right: Math.max(8, window.innerWidth - r.right), sheet: window.matchMedia("(max-width: 640px)").matches });
    markSeen();
    window.dispatchEvent(new Event(OPENED_EVENT));
  }, [markSeen]);
  const close = useCallback((refocus = true) => {
    setAnchor(null);
    window.dispatchEvent(new Event(CLOSED_EVENT));
    if (refocus) btnRef.current?.focus({ preventScroll: true });
  }, []);

  useEffect(() => {
    const onOpen = () => open();
    const onCheck = () => flip();
    const onWink = () => {
      blink();
      // Rive renders the eye inside the canvas: squint the whole mark a touch.
      btnRef.current?.querySelector(".ww-mark__rive")?.animate(
        [{ transform: "scale(0.92)" }, { transform: "scale(0.92, 0.81)", offset: 0.45 }, { transform: "scale(0.92)" }],
        { duration: 220, easing: "cubic-bezier(0.25, 1, 0.5, 1)" },
      );
    };
    window.addEventListener(WINK_EVENT, onWink);
    window.addEventListener(OPEN_EVENT, onOpen);
    window.addEventListener(CHECK_EVENT, onCheck);
    return () => { window.removeEventListener(OPEN_EVENT, onOpen); window.removeEventListener(CHECK_EVENT, onCheck); window.removeEventListener(WINK_EVENT, onWink); };
  }, [open, flip, blink]);

  const label = `WebWatcher is watching this page · ${count} change${count === 1 ? "" : "s"}`;
  const clipTop = `ww-top-${uid}`;
  const clipBot = `ww-bot-${uid}`;
  const clipEye = `ww-eye-${uid}`;

  return (
    <>
      <button
        ref={btnRef}
        type="button"
        className="ww-mark"
        data-testid="watch-mark"
        data-renderer={shown}
        data-reduced={reduced ? "1" : "0"}
        style={{ "--ww-period": interval <= 60 ? `${interval}s` : "6.5s" } as React.CSSProperties}
        aria-label={label}
        aria-haspopup="dialog"
        aria-expanded={!!anchor}
        onClick={() => (anchor ? close() : open())}
        onPointerEnter={() => setHover(true)}
        onPointerLeave={() => setHover(false)}
      >
        <svg className="ww-mark__svg" viewBox="0 0 36 36" width="36" height="36" aria-hidden focusable="false" data-hidden={shown === "rive" ? "1" : "0"}>
          <defs>
            <clipPath id={clipTop}><path d={TOP} /></clipPath>
            <clipPath id={clipBot}><path d={BOT} /></clipPath>
            <clipPath id={clipEye}><path d={EYE} /></clipPath>
          </defs>
          <g ref={flipRef} className="ww-flip">
            <g ref={glassRef} className={`ww-glass${reduced ? " is-still" : ""}`}>
              <g clipPath={`url(#${clipTop})`}><rect className="ww-sand ww-sand--top" x="8" y="8.3" width="14.4" height="10.4" fill="#F3F1EC" /></g>
              <g clipPath={`url(#${clipBot})`}><rect className="ww-sand ww-sand--bot" x="8" y="18.7" width="14.4" height="10.4" fill="#F3F1EC" /></g>
              <rect className="ww-stream" x="14.7" y="18" width="1" height="11" fill="#F3F1EC" />
              <path d={TOP} fill="none" stroke="#F3F1EC" strokeWidth="1.25" strokeLinejoin="round" />
              <path d={BOT} fill="none" stroke="#F3F1EC" strokeWidth="1.25" strokeLinejoin="round" />
              <rect x="7.7" y="6.3" width="15" height="2" rx="1" fill="#F3F1EC" />
              <rect x="7.7" y="29.1" width="15" height="2" rx="1" fill="#F3F1EC" />
            </g>
          </g>
          <g ref={eyeRef} className="ww-eye">
            <path d={EYE} fill="#fff" stroke="#F3F1EC" strokeWidth="1.25" strokeLinejoin="round" />
            <g clipPath={`url(#${clipEye})`}>
              <g ref={irisRef} className="ww-iris" data-testid="watch-iris">
                <circle cx="28" cy="28" r="2.1" fill="#1A1C23" />
              </g>
            </g>
          </g>
        </svg>
        {mountRive && RiveComp && (
          <RiveComp
            sinkRef={sinkRef}
            unseen={unseen}
            hover={hover}
            reduced={reduced}
            tickSignal={tickSignal}
            interval={interval}
            lastCheck={lastCheck}
            onReady={() => setRenderer("rive")}
            onError={() => { setRenderer("svg"); setMountRive(false); }}
          />
        )}
        {unseen > 0 && (
          <span key={unseen} className="ww-badge" data-testid="watch-badge" aria-hidden>
            <span className="ww-badge__n">{unseen > 99 ? "99+" : unseen}</span>
          </span>
        )}
      </button>
      <WatchPopover anchor={anchor} changes={changes} lastCheck={lastCheck} onClose={close} triggerRef={btnRef} />
    </>
  );
}
