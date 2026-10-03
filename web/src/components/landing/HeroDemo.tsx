"use client";

import { Pause, Play, Volume2, VolumeX } from "lucide-react";
import { useCallback, useEffect, useRef, useState } from "react";
import { DEMO_DURATION, DEMO_VIDEO_SRC, DEMO_POSTER, asset } from "@/lib/config";
import "@/styles/hero.css";

const PLAY_EVENT = "hero-demo-play";

/** Text link under the CTAs; starts the same in-place playback as the frame's play control. */
export function HeroWatchLink({ className, style }: { className?: string; style?: React.CSSProperties }) {
  return (
    <button type="button" className={className} style={style} data-testid="hv-link" onClick={() => window.dispatchEvent(new Event(PLAY_EVENT))}>
      <Play size={13} fill="currentColor" strokeWidth={0} aria-hidden="true" />
      Watch the demo · {DEMO_DURATION}
    </button>
  );
}

/**
 * The poster (the real app) is all the visitor sees until they press play; the demo then plays
 * in place, with sound, on the same frame. No dialog, no muted autoplay.
 */
export default function HeroDemo() {
  const frameRef = useRef<HTMLDivElement>(null);
  const videoRef = useRef<HTMLVideoElement>(null);
  const [near, setNear] = useState(false);
  const [engaged, setEngaged] = useState(false);
  const [paused, setPaused] = useState(false);
  const [muted, setMuted] = useState(false);
  const [rolling, setRolling] = useState(false); // first frame is painting
  const engagedRef = useRef(false);

  useEffect(() => {
    const el = frameRef.current;
    if (!el || typeof IntersectionObserver === "undefined") { setNear(true); return; }
    const nearObs = new IntersectionObserver(([e]) => { if (e.isIntersecting) { setNear(true); nearObs.disconnect(); } }, { rootMargin: "400px" });
    // never keep sound running off screen
    const seenObs = new IntersectionObserver(([e]) => {
      const v = videoRef.current;
      if (!e.isIntersecting && engagedRef.current && v && !v.paused) v.pause();
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
    v.muted = false;
    v.loop = false;
    engagedRef.current = true;
    setMuted(false);
    setEngaged(true);
    setPaused(false);
    void v.play().catch(() => { v.muted = true; setMuted(true); void v.play().catch(() => {}); });
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
  const toggleMute = () => {
    const v = videoRef.current;
    if (!v) return;
    v.muted = !v.muted;
    setMuted(v.muted);
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
          srcSet={`${asset(DEMO_POSTER)} 1x, ${asset(DEMO_POSTER.replace(".png", "@2x.png"))} 2x`}
          alt="The WebWatcher menu bar popover listing three watchers"
          width={1200}
          height={900}
          fetchPriority="high"
        />
        <div className={`hv__win${rolling ? " is-on" : ""}`} onClick={engaged ? togglePause : undefined}>
          <video
            ref={videoRef}
            data-testid="hv-video"
            src={near ? asset(DEMO_VIDEO_SRC) : undefined}
            playsInline
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
          <button type="button" className="hv__play" data-testid="hv-play" onClick={start}>
            <span className="hv__play-btn"><Play size={28} fill="currentColor" strokeWidth={0} style={{ marginLeft: 3 }} /></span>
            <span className="hv__play-label">Watch the demo · {DEMO_DURATION}</span>
          </button>
        )}

        {engaged && (
          <div className="hv__bar" role="group" aria-label="Demo controls">
            <button type="button" data-testid="hv-pause" onClick={togglePause} aria-label={paused ? "Play" : "Pause"}>
              {paused ? <Play size={18} fill="currentColor" strokeWidth={0} /> : <Pause size={18} fill="currentColor" strokeWidth={0} />}
            </button>
            <button type="button" data-testid="hv-mute" onClick={toggleMute} aria-label={muted ? "Unmute" : "Mute"} aria-pressed={muted}>
              {muted ? <VolumeX size={18} /> : <Volume2 size={18} />}
            </button>
          </div>
        )}
      </div>
      <p className="hv__cap">Picking the Rive community bell and getting the first notification.</p>
    </div>
  );
}
