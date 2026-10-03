"use client";

import { Pause, Play, Volume2, VolumeX } from "lucide-react";
import { useCallback, useEffect, useRef, useState } from "react";
import { DEMO_DURATION, DEMO_VIDEO_SRC, DEMO_POSTER, asset } from "@/lib/config";
import "@/styles/hero.css";

/**
 * The demo plays in place. Before the click it is a muted loop (when allowed and on screen);
 * the play button restarts it from the top with sound, on the same frame. No dialog.
 */
export default function HeroDemo() {
  const frameRef = useRef<HTMLDivElement>(null);
  const videoRef = useRef<HTMLVideoElement>(null);
  const onScreen = useRef(false);
  const [near, setNear] = useState(false);
  const [engaged, setEngaged] = useState(false); // user chose to watch with sound
  const [paused, setPaused] = useState(false);
  const [muted, setMuted] = useState(true);
  const [rolling, setRolling] = useState(false); // first frame is actually painting

  const reduced = () => typeof window !== "undefined" && window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  const sync = useCallback(() => {
    const v = videoRef.current;
    if (!v || !v.getAttribute("src")) return;
    if (engaged) return; // the viewer is in control
    if (onScreen.current && !document.hidden && !reduced()) void v.play().catch(() => {});
    else v.pause();
  }, [engaged]);

  useEffect(() => {
    const el = frameRef.current;
    if (!el || typeof IntersectionObserver === "undefined") return;
    const nearObs = new IntersectionObserver(([e]) => { if (e.isIntersecting) { setNear(true); nearObs.disconnect(); } }, { rootMargin: "300px" });
    const seenObs = new IntersectionObserver(([e]) => {
      onScreen.current = e.isIntersecting;
      const v = videoRef.current;
      if (engaged && v && !e.isIntersecting) { v.pause(); setPaused(true); } // never keep sound running off screen
      else sync();
    }, { threshold: 0.25 });
    nearObs.observe(el);
    seenObs.observe(el);
    const onVis = () => sync();
    document.addEventListener("visibilitychange", onVis);
    return () => { nearObs.disconnect(); seenObs.disconnect(); document.removeEventListener("visibilitychange", onVis); };
  }, [sync, engaged]);

  useEffect(() => { if (near) sync(); }, [near, sync]);

  const playWithSound = () => {
    const v = videoRef.current;
    if (!v) return;
    if (!v.getAttribute("src")) v.src = asset(DEMO_VIDEO_SRC);
    v.currentTime = 0;
    v.muted = false;
    v.loop = false;
    setMuted(false);
    setEngaged(true);
    setPaused(false);
    void v.play().catch(() => { v.muted = true; setMuted(true); void v.play().catch(() => {}); });
  };
  const togglePause = () => {
    const v = videoRef.current;
    if (!v) return;
    if (v.paused) { void v.play(); setPaused(false); } else { v.pause(); setPaused(true); }
  };
  const toggleMute = () => {
    const v = videoRef.current;
    if (!v) return;
    v.muted = !v.muted;
    setMuted(v.muted);
  };
  const onEnded = () => {
    const v = videoRef.current;
    if (!v) return;
    v.muted = true; v.loop = true; setMuted(true);
    setEngaged(false);
    v.currentTime = 0;
    if (onScreen.current && !reduced()) void v.play().catch(() => {});
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
        <div className={`hv__win${rolling ? " is-on" : ""}`}>
          <video
            ref={videoRef}
            data-testid="hv-video"
            src={near ? asset(DEMO_VIDEO_SRC) : undefined}
            muted
            loop
            playsInline
            preload="none"
            aria-label="WebWatcher demo: picking the Rive community bell and getting the first notification"
            onPlaying={() => setRolling(true)}
            onPause={() => { if (engaged) setPaused(true); }}
            onPlay={() => setPaused(false)}
            onEnded={onEnded}
            onVolumeChange={(e) => setMuted((e.target as HTMLVideoElement).muted)}
          />
        </div>

        {!engaged && (
          <button type="button" className="hv__play" data-testid="hv-play" onClick={playWithSound}>
            <span className="hv__play-btn"><Play size={28} fill="currentColor" strokeWidth={0} style={{ marginLeft: 3 }} /></span>
            <span className="hv__play-label">Play with sound · {DEMO_DURATION}</span>
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
