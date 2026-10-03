"use client";

import { Pause, Play } from "lucide-react";
import { useCallback, useEffect, useRef, useState } from "react";
import { DEMO_DURATION, DEMO_VIDEO_SRC, DEMO_POSTER, DEMO_POSTER_2X, asset } from "@/lib/config";
import "@/styles/hero.css";

const PLAY_EVENT = "hero-demo-play";

/** Text link under the CTAs; starts the same in-place playback as the frame's play control. */
export function HeroWatchLink({ className, style }: { className?: string; style?: React.CSSProperties }) {
  return (
    <button type="button" className={className} style={style} data-testid="hv-link" onClick={() => window.dispatchEvent(new Event(PLAY_EVENT))}>
      <Play size={13} fill="currentColor" strokeWidth={0} aria-hidden="true" />
      Watch the demo, {DEMO_DURATION}
    </button>
  );
}

/**
 * The poster (a frame of the recording) is all the visitor sees until they press play; the demo then
 * plays in place on the same frame. The recording is silent, so there is no sound control. No dialog, no autoplay.
 */
export default function HeroDemo() {
  const frameRef = useRef<HTMLDivElement>(null);
  const videoRef = useRef<HTMLVideoElement>(null);
  const [near, setNear] = useState(false);
  const [engaged, setEngaged] = useState(false);
  const [paused, setPaused] = useState(false);
  const [rolling, setRolling] = useState(false); // first frame is painting
  const engagedRef = useRef(false);
  const seenRef = useRef(false); // true once the frame has been on screen during this playback

  useEffect(() => {
    const el = frameRef.current;
    // Touch screens and Save-Data: the mp4 is not requested until the visitor presses play (start() assigns src).
    const conn = (navigator as Navigator & { connection?: { saveData?: boolean } }).connection;
    const lean = window.matchMedia("(pointer: coarse)").matches || !!conn?.saveData;
    if (!el || typeof IntersectionObserver === "undefined") return;
    const nearObs = new IntersectionObserver(([e]) => { if (e.isIntersecting) { if (!lean) setNear(true); nearObs.disconnect(); } }, { rootMargin: "400px" });
    // never keep it running off screen
    const seenObs = new IntersectionObserver(([e]) => {
      const v = videoRef.current;
      if (e.isIntersecting) { seenRef.current = true; return; }
      // Only after it has been seen: start() may begin playing while the smooth scroll to the frame is still under way.
      if (seenRef.current && engagedRef.current && v && !v.paused) { v.pause(); seenRef.current = false; }
    }, { threshold: 0.2 });
    nearObs.observe(el);
    seenObs.observe(el);
    const onVis = () => { const v = videoRef.current; if (document.hidden && engagedRef.current && v && !v.paused) v.pause(); };
    document.addEventListener("visibilitychange", onVis);
    return () => { nearObs.disconnect(); seenObs.disconnect(); document.removeEventListener("visibilitychange", onVis); };
  }, []);

  const start = useCallback(() => {
    const v = videoRef.current;
    if (!v) return;
    if (!v.getAttribute("src")) v.src = asset(DEMO_VIDEO_SRC);
    if (window.matchMedia("(max-width: 1099px)").matches) {
      frameRef.current?.scrollIntoView({ block: "center", behavior: window.matchMedia("(prefers-reduced-motion: reduce)").matches ? "auto" : "smooth" });
    }
    v.currentTime = 0;
    v.muted = true;
    v.loop = false;
    engagedRef.current = true;
    const r = frameRef.current?.getBoundingClientRect();
    seenRef.current = !!r && r.top < window.innerHeight * 0.8 && r.bottom > window.innerHeight * 0.2;
    setEngaged(true);
    setPaused(false);
    void v.play().catch(() => {});
  }, []);

  useEffect(() => {
    window.addEventListener(PLAY_EVENT, start);
    return () => window.removeEventListener(PLAY_EVENT, start);
  }, [start]);

  const togglePause = () => {
    const v = videoRef.current;
    if (!v) return;
    if (v.paused) void v.play(); else v.pause();
  };
  const onEnded = () => {
    engagedRef.current = false;
    setEngaged(false);
    setRolling(false);
    setPaused(false);
    frameRef.current?.style.setProperty("--p", "0");
  };
  const onTime = (v: HTMLVideoElement) => {
    if (v.duration) frameRef.current?.style.setProperty("--p", String(v.currentTime / v.duration));
  };

  return (
    <div className={`hv${engaged ? " is-engaged" : ""}`} data-testid="hv" ref={frameRef}>
      <div className="hv__frame">
        { }
        <img
          className={`hv__poster${rolling ? " is-hidden" : ""}`}
          src={asset(DEMO_POSTER)}
          srcSet={`${asset(DEMO_POSTER)} 1x, ${asset(DEMO_POSTER_2X)} 2x`}
          alt="A Safari window on a community feed with a bell badge of 3, and beside it the WebWatcher Add Watcher window listing the number it found"
          width={1440}
          height={896}
          fetchPriority="high"
        />
        <div className={`hv__win${rolling ? " is-on" : ""}`} onClick={engaged ? togglePause : undefined}>
          <video
            ref={videoRef}
            data-testid="hv-video"
            src={near ? asset(DEMO_VIDEO_SRC) : undefined}
            playsInline
            muted
            preload="metadata"
            aria-label="WebWatcher demo: picking the Rive community bell and getting the first notification"
            onPlaying={() => { if (engagedRef.current) setRolling(true); }}
            onPause={(e) => { if (engagedRef.current && !(e.target as HTMLVideoElement).ended) setPaused(true); }}
            onPlay={() => setPaused(false)}
            onEnded={onEnded}
            onTimeUpdate={(e) => onTime(e.target as HTMLVideoElement)}
          />
          <i className="hv__progress" aria-hidden="true" />
        </div>

        {!engaged && (
          <>
            <div className="hv__hit" onClick={start} aria-hidden="true" />
            <button type="button" className="hv__play" data-testid="hv-play" aria-label={`Watch the demo, ${DEMO_DURATION}`} onClick={start}>
              <span className="hv__play-btn"><Play size={14} fill="currentColor" strokeWidth={0} style={{ marginLeft: 1 }} /></span>
              <span className="hv__play-label">Watch the demo, {DEMO_DURATION}</span>
            </button>
          </>
        )}

        {engaged && (
          <div className="hv__bar" role="group" aria-label="Demo controls">
            <button type="button" data-testid="hv-pause" onClick={togglePause} aria-label={paused ? "Play" : "Pause"}>
              {paused ? <Play size={18} fill="currentColor" strokeWidth={0} /> : <Pause size={18} fill="currentColor" strokeWidth={0} />}
            </button>
          </div>
        )}
      </div>
      <p className="hv__cap"><span className="t-label">The real app, 15 s</span><span>Adding a watcher for a community bell and getting the first notification. Recorded from <span className="nw">WebWatcher</span> 1.10.9.</span></p>
    </div>
  );
}
