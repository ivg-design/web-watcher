"use client";

import { motion, useReducedMotion } from "framer-motion";
import { Bell, BatteryMedium, Play, Search, Wifi, X } from "lucide-react";
import { useCallback, useEffect, useRef, useState } from "react";
import { DEMO_DURATION, DEMO_VIDEO_URL } from "@/lib/config";
import Glyph from "./d/Glyph";
import Roll from "./d/Roll";

const QUART = [0.25, 1, 0.5, 1] as const;

/** Hero scene: the poster mock as real DOM, a lazy muted loop video over it, and a modal player with sound. */
export default function HeroDemo() {
  const reduced = !!useReducedMotion();
  const animate = !reduced;

  const rootRef = useRef<HTMLDivElement>(null);
  const videoRef = useRef<HTMLVideoElement>(null);
  const dialogRef = useRef<HTMLDialogElement>(null);
  const dialogVideoRef = useRef<HTMLVideoElement>(null);
  const returnFocus = useRef<HTMLElement | null>(null);
  const modalOpen = useRef(false);
  const visible = useRef(false);

  const [near, setNear] = useState(false);
  const [playing, setPlaying] = useState(false);
  const [failed, setFailed] = useState(false);
  const [open, setOpen] = useState(false);

  const sync = useCallback(() => {
    const v = videoRef.current;
    if (!v || !v.getAttribute("src")) return;
    const should = visible.current && !document.hidden && !modalOpen.current && !reduced;
    if (should) void v.play().catch(() => {});
    else v.pause();
  }, [reduced]);

  // Load the source only when near the viewport; play only while on screen.
  useEffect(() => {
    const el = rootRef.current;
    if (!el || typeof IntersectionObserver === "undefined") return;
    const nearObs = new IntersectionObserver(
      ([e]) => { if (e.isIntersecting) { setNear(true); nearObs.disconnect(); } },
      { rootMargin: "400px" },
    );
    const seenObs = new IntersectionObserver(
      ([e]) => { visible.current = e.isIntersecting; sync(); },
      { threshold: 0.2 },
    );
    nearObs.observe(el);
    seenObs.observe(el);
    const onVis = () => sync();
    document.addEventListener("visibilitychange", onVis);
    return () => {
      nearObs.disconnect();
      seenObs.disconnect();
      document.removeEventListener("visibilitychange", onVis);
    };
  }, [sync]);

  useEffect(() => { if (near) sync(); }, [near, sync]);

  const openDialog = useCallback(() => {
    const d = dialogRef.current;
    if (!d || d.open) return;
    returnFocus.current = document.activeElement as HTMLElement | null;
    modalOpen.current = true;
    videoRef.current?.pause();
    setOpen(true);
    d.showModal();
  }, []);

  useEffect(() => {
    window.addEventListener("ww:open-demo", openDialog);
    return () => window.removeEventListener("ww:open-demo", openDialog);
  }, [openDialog]);

  const onDialogClose = () => {
    dialogVideoRef.current?.pause();
    modalOpen.current = false;
    setOpen(false);
    returnFocus.current?.focus?.();
    sync();
  };

  // Signature sequence timings (seconds); whole thing lands at ~1.6s.
  const T = { roll: 0.15, lit: 0.55, cap: 0.7, eye: 1.1 };

  return (
    <>
      <div className={`demo${playing ? " is-playing" : ""}`}
           ref={rootRef}>
        <div className="demo__scene" aria-hidden="true">
          <div className="demo__menubar">
            <Wifi size={15} strokeWidth={1.8} />
            <BatteryMedium size={16} strokeWidth={1.8} />
            <Search size={14} strokeWidth={2} />
            <Glyph animate={animate} eyeDelay={T.eye} />
            <span>Thu 20:51</span>
          </div>
          <div className="demo__desk" />
          <div className="demo__safari">
            <div className="demo__bar" />
            <div className="demo__body">
              <div className="demo__col">
                <div className="demo__sk demo__sk--hot" />
                <div className="demo__sk" />
                <div className="demo__sk" />
                <div className="demo__sk" />
                <div className="demo__sk" />
              </div>
              <div className="demo__col demo__col--r">
                <div className="demo__blk" />
                <div className="demo__sk" />
                <div className="demo__sk" />
                <div className="demo__blk demo__blk--tall" />
                <div className="demo__sk" />
                <div className="demo__sk" />
                <div className="demo__blk" />
              </div>
            </div>
            <div className="demo__bell">
              <Bell size={13} strokeWidth={2} />
              <b><Roll to={3} delay={T.roll} duration={0.8} animate={animate} /></b>
            </div>
          </div>
          <div className="demo__pop">
            <h4>Watchers</h4>
            <div className="demo__row">
              <motion.span
                className="demo__row-lit"
                initial={animate ? { opacity: 0 } : false}
                animate={{ opacity: 1 }}
                transition={{ delay: T.lit, duration: 0.5, ease: QUART }}
              />
              <i className="demo__ico" />
              <div><strong>Rive Community · bell</strong><small>Changed 2 min ago</small></div>
              <motion.span
                className="demo__cap"
                initial={animate ? { opacity: 0, scale: 0.6 } : false}
                animate={{ opacity: 1, scale: 1 }}
                transition={{ delay: T.cap, duration: 0.45, ease: [0.16, 1, 0.3, 1] }}
              >
                <span className="demo__cap-in"><Roll to={3} delay={T.cap} duration={0.6} animate={animate} /></span>
              </motion.span>
            </div>
            <div className="demo__row demo__row--on">
              <i className="demo__ico" />
              <div><strong>Gmail · @rive.app</strong><small>2 unread · latest 8:14 PM</small></div>
              <span className="demo__cap">2</span>
            </div>
            <div className="demo__row">
              <i className="demo__ico" />
              <div><strong>GitHub · PR #214</strong><small>Checked just now</small></div>
            </div>
            <div className="demo__row">
              <i className="demo__ico" />
              <div><strong>Forum thread · replies</strong><small>Change today</small></div>
            </div>
            <div className="demo__foot"><span>+ Add watcher</span><span>Settings</span></div>
          </div>
        </div>

        {!failed && (
          <video
            ref={videoRef}
            className={`demo__video${playing ? " is-on" : ""}`}
            src={near && !reduced ? DEMO_VIDEO_URL : undefined}
            muted
            loop
            playsInline
            preload="none"
            aria-hidden="true"
            tabIndex={-1}
            onPlaying={() => setPlaying(true)}
            onError={() => { setFailed(true); setPlaying(false); }}
          />
        )}
        <div className="demo__scrim" />
        <button type="button" className="demo__play" onClick={openDialog}>
          <span className="demo__play-btn"><Play size={34} fill="currentColor" strokeWidth={0} style={{ marginLeft: 4 }} /></span>
          <span className="demo__play-label">Watch the demo · {DEMO_DURATION}</span>
          <span className="demo__play-cap">Picking the Rive community bell and getting the first notification</span>
        </button>
      </div>

      <dialog
        ref={dialogRef}
        className="demo-dialog"
        aria-label="WebWatcher demo video"
        onClose={onDialogClose}
        onClick={(e) => { if (e.target === dialogRef.current) dialogRef.current?.close(); }}
      >
        <button type="button" className="demo-dialog__close" aria-label="Close demo" onClick={() => dialogRef.current?.close()}>
          <X size={20} />
        </button>
        {open && (
          <video ref={dialogVideoRef} src={DEMO_VIDEO_URL} controls autoPlay playsInline preload="auto" />
        )}
      </dialog>
    </>
  );
}
