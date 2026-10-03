"use client";

/**
 * The page's watcher: the hourglass with the eye. SVG renderer ships first (SSR-safe, always
 * works); the Rive renderer swaps in once /rive/watcher-mark.riv exists and loads.
 * Eye = watching (follows the cursor), sand = interval, flip = check, badge = unseen changes.
 */
import { useCallback, useEffect, useId, useRef, useState } from "react";
import dynamic from "next/dynamic";
import { asset } from "@/lib/config";
import { useWatch } from "./WatchContext";
import WatchPopover, { type Anchor } from "./WatchPopover";
import { OPEN_EVENT, CHECK_EVENT, OPENED_EVENT, CLOSED_EVENT, WINK_EVENT } from "./events";
import "@/styles/watch.css";

const WatchMarkRive = dynamic(() => import("./WatchMarkRive"), { ssr: false });

const RIVE_SRC = "/rive/watcher-mark.riv";
let riveProbe: Promise<boolean> | null = null;
function probeRive(): Promise<boolean> {
  riveProbe ??= fetch(asset(RIVE_SRC), { method: "HEAD" })
    .then((r) => r.ok && !(r.headers.get("content-type") ?? "").includes("text/html"))
    .catch(() => false);
  return riveProbe;
}

const MAX_LOOK = 4;
const clamp = (v: number) => Math.max(-1, Math.min(1, v));

export default function WatchMark() {
  const { unseen, count, changes, markSeen } = useWatch();
  const uid = useId().replace(/:/g, "");
  const btnRef = useRef<HTMLButtonElement>(null);
  const irisRef = useRef<SVGGElement>(null);
  const eyeRef = useRef<SVGGElement>(null);
  const flipRef = useRef<SVGGElement>(null);
  const glassRef = useRef<SVGGElement>(null);
  const sinkRef = useRef<((x: number, y: number) => void) | null>(null);

  const [renderer, setRenderer] = useState<"svg" | "rive">("svg");
  const [mountRive, setMountRive] = useState(false);
  const [hover, setHover] = useState(false);
  const [reduced, setReduced] = useState(false);
  const [tickSignal, setTickSignal] = useState(0);
  const [anchor, setAnchor] = useState<Anchor | null>(null);
  const [lastCheck, setLastCheck] = useState(() => Date.now());

  // Rive file guard: HEAD check once, cached.
  useEffect(() => {
    let live = true;
    probeRive().then((ok) => { if (live && ok) setMountRive(true); });
    return () => { live = false; };
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
    const cur = { x: 0, y: 0 };
    let raf = 0;
    const apply = () => {
      irisRef.current?.style.setProperty("transform", `translate(${(cur.x * MAX_LOOK).toFixed(2)}px, ${(cur.y * MAX_LOOK).toFixed(2)}px)`);
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
    const onMove = (e: PointerEvent) => {
      const r = btnRef.current?.getBoundingClientRect();
      if (!r) return;
      const cx = r.left + r.width / 2;
      const cy = r.top + r.height / 2;
      target.x = clamp((e.clientX - cx) / Math.max(cx, window.innerWidth - cx, 1));
      target.y = clamp((e.clientY - cy) / Math.max(cy, window.innerHeight - cy, 1));
      if (!raf) raf = requestAnimationFrame(loop);
    };
    apply();
    window.addEventListener("pointermove", onMove, { passive: true });
    return () => { window.removeEventListener("pointermove", onMove); cancelAnimationFrame(raf); };
  }, []);

  // Blink: hover >= 3 s, then every ~4 s while hovered.
  const blink = useCallback(() => {
    eyeRef.current?.animate(
      [{ transform: "scaleY(1)" }, { transform: "scaleY(0.08)", offset: 0.45 }, { transform: "scaleY(1)" }],
      { duration: 200, easing: "cubic-bezier(0.25, 1, 0.5, 1)" },
    );
  }, []);
  useEffect(() => {
    if (!hover) return;
    let iv = 0;
    const t = window.setTimeout(() => { blink(); iv = window.setInterval(blink, 4000); }, 3000);
    return () => { window.clearTimeout(t); window.clearInterval(iv); };
  }, [hover, blink]);

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
        data-renderer={renderer}
        data-reduced={reduced ? "1" : "0"}
        aria-label={label}
        aria-haspopup="dialog"
        aria-expanded={!!anchor}
        onClick={() => (anchor ? close() : open())}
        onPointerEnter={() => setHover(true)}
        onPointerLeave={() => setHover(false)}
      >
        <svg className="ww-mark__svg" viewBox="0 0 36 36" width="36" height="36" aria-hidden focusable="false" data-hidden={renderer === "rive" ? "1" : "0"}>
          <defs>
            <clipPath id={clipTop}><path d="M11.5 6.4H24.5C24.5 12 20 14.5 18 18C16 14.5 11.5 12 11.5 6.4Z" /></clipPath>
            <clipPath id={clipBot}><path d="M11.5 29.6H24.5C24.5 24 20 21.5 18 18C16 21.5 11.5 24 11.5 29.6Z" /></clipPath>
            <clipPath id={clipEye}><circle cx="26" cy="26" r="6" /></clipPath>
          </defs>
          <g ref={flipRef} className="ww-flip">
            <g ref={glassRef} className={`ww-glass${reduced ? " is-still" : ""}`}>
              <path d="M11.5 6.4H24.5C24.5 12 20 14.5 18 18C16 14.5 11.5 12 11.5 6.4Z" fill="#fff" />
              <path d="M11.5 29.6H24.5C24.5 24 20 21.5 18 18C16 21.5 11.5 24 11.5 29.6Z" fill="#fff" />
              <g clipPath={`url(#${clipTop})`}><rect className="ww-sand ww-sand--top" x="10" y="6" width="16" height="12" fill="#1F5EFF" /></g>
              <g clipPath={`url(#${clipBot})`}><rect className="ww-sand ww-sand--bot" x="10" y="18" width="16" height="12" fill="#1F5EFF" /></g>
              <rect className="ww-stream" x="17.4" y="17" width="1.2" height="12" fill="#1F5EFF" />
              <path d="M11.5 6.4H24.5C24.5 12 20 14.5 18 18C16 14.5 11.5 12 11.5 6.4Z" fill="none" stroke="#14161C" strokeWidth="2" strokeLinejoin="round" />
              <path d="M11.5 29.6H24.5C24.5 24 20 21.5 18 18C16 21.5 11.5 24 11.5 29.6Z" fill="none" stroke="#14161C" strokeWidth="2" strokeLinejoin="round" />
              <rect x="8" y="3.6" width="20" height="2.8" rx="1.2" fill="#14161C" />
              <rect x="8" y="29.6" width="20" height="2.8" rx="1.2" fill="#14161C" />
            </g>
          </g>
          <g ref={eyeRef} className="ww-eye">
            <circle cx="26" cy="26" r="7" fill="#fff" stroke="#14161C" strokeWidth="1.6" />
            <g clipPath={`url(#${clipEye})`}>
              <g ref={irisRef} className="ww-iris" data-testid="watch-iris">
                <circle cx="26" cy="26" r="2.4" fill="#14161C" />
                <circle cx="25.2" cy="25.2" r="0.7" fill="#fff" />
              </g>
            </g>
          </g>
        </svg>
        {mountRive && (
          <WatchMarkRive
            sinkRef={sinkRef}
            unseen={unseen}
            hover={hover}
            reduced={reduced}
            tickSignal={tickSignal}
            onReady={() => setRenderer("rive")}
            onError={() => { setRenderer("svg"); setMountRive(false); }}
          />
        )}
        {unseen > 0 && (
          <span className="ww-badge" data-testid="watch-badge" aria-hidden>
            <span key={unseen} className="ww-badge__n">{unseen > 99 ? "99+" : unseen}</span>
          </span>
        )}
      </button>
      <WatchPopover anchor={anchor} changes={changes} lastCheck={lastCheck} onClose={close} triggerRef={btnRef} />
    </>
  );
}
