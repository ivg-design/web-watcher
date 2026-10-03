"use client";

import { useEffect, useRef, useState, useSyncExternalStore } from "react";
import { Volume2, X } from "lucide-react";
import { asset } from "@/lib/config";
import "@/styles/herald.css";

type Phase = "idle" | "shown" | "leaving" | "snoozed" | "done";
const SPOKEN = "3 new from Rive team. Scripting update, office hours, release notes.";

export default function HeraldDemo() {
  const [phase, setPhase] = useState<Phase>("idle");
  const [enter, setEnter] = useState(0); // bumps to replay the entrance
  const [speaking, setSpeaking] = useState(false);
  const canSpeak = useSyncExternalStore(
    () => () => {},
    () => "speechSynthesis" in window && !!window.speechSynthesis,
    () => false,
  );
  const stage = useRef<HTMLDivElement>(null);
  const started = useRef(false);
  const timers = useRef<number[]>([]);
  const later = (fn: () => void, ms: number) => {
    timers.current.push(window.setTimeout(fn, ms));
  };
  const reduced = () => window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  useEffect(() => {
    const el = stage.current;
    if (!el) return;
    const go = () => {
      if (started.current) return;
      started.current = true;
      io.disconnect();
      hio?.disconnect();
      setEnter((n) => n + 1);
      setPhase("shown");
    };
    // stage >= 35 % visible
    const io = new IntersectionObserver(
      (es) => {
        if (es.some((e) => e.isIntersecting && e.intersectionRatio >= 0.35)) go();
      },
      { threshold: [0, 0.35, 0.6, 1] },
    );
    io.observe(el);
    // or the section header has scrolled past / into the reading zone
    const head = el.closest("section")?.querySelector("h2");
    const hio = head
      ? new IntersectionObserver(
          (es) => {
            if (es.some((e) => !e.isIntersecting && e.boundingClientRect.bottom < 0)) go();
          },
          { threshold: 0 },
        )
      : null;
    if (head && hio) hio.observe(head);
    const t = timers.current;
    return () => {
      io.disconnect();
      hio?.disconnect();
      t.forEach(window.clearTimeout);
      try {
        window.speechSynthesis?.cancel();
      } catch {}
    };
  }, []);

  const stopSpeech = () => {
    try {
      window.speechSynthesis?.cancel();
    } catch {}
    setSpeaking(false);
  };
  const show = () => {
    setEnter((n) => n + 1);
    setPhase("shown");
  };
  const leave = (next: "done" | "snoozed") => {
    stopSpeech();
    setPhase("leaving");
    later(
      () => {
        setPhase(next);
        if (next === "snoozed") later(show, 3000);
      },
      reduced() ? 0 : 240,
    );
  };
  const speak = () => {
    if (speaking) return stopSpeech();
    try {
      const u = new SpeechSynthesisUtterance(SPOKEN);
      u.onend = () => setSpeaking(false);
      u.onerror = () => setSpeaking(false);
      setSpeaking(true);
      window.speechSynthesis.speak(u);
    } catch {
      setSpeaking(false);
    }
  };

  const visible = phase === "shown" || phase === "leaving";

  return (
    <div className="hx" ref={stage}>
      <div className="hx__menubar" aria-hidden="true">
        <span className="hx__apple" />
        <span>Finder</span>
        <span className="hx__clock">Thu 8:14 PM</span>
      </div>
      {visible ? (
        <div
          key={enter}
          className={`hx__banner${phase === "leaving" ? " is-out" : " is-in"}`}
          data-testid="hb-banner"
          role="group"
          aria-label="Herald banner"
        >
          <img className="hx__icon" src={asset("/images/herald-icon.png")} alt="" width={56} height={56} />
          <div className="hx__main">
            <div className="hx__top">
              <span className="hx__app">WebWatcher · Email</span>
              <span className="hx__time">now</span>
              <button type="button" className="hx__x" data-testid="hb-close" aria-label="Dismiss" onClick={() => leave("done")}>
                <X size={13} strokeWidth={2.6} />
              </button>
            </div>
            <div className="hx__title">3 new from Rive team</div>
            <div className="hx__body">Scripting update · Office hours · Release notes</div>
            <div className="hx__btns">
              <button type="button" className="hx__pill" data-testid="hb-open" onClick={() => leave("done")}>Open</button>
              <button type="button" className="hx__pill" data-testid="hb-read" onClick={() => leave("done")}>Mark as Read</button>
              <button type="button" className="hx__pill" data-testid="hb-archive" onClick={() => leave("done")}>Archive</button>
              <button type="button" className="hx__pill hx__snooze" data-testid="hb-snooze" aria-describedby="hx-tip" onClick={() => leave("snoozed")}>
                Snooze
                <span className="hx__tip" id="hx-tip" role="tooltip">returns at 9:00</span>
              </button>
            </div>
          </div>
          {canSpeak ? (
            <button
              type="button"
              className={`hx__speak${speaking ? " is-on" : ""}`}
              data-testid="hb-speak"
              data-speaking={speaking ? "1" : "0"}
              aria-pressed={speaking}
              aria-label={speaking ? "Stop reading aloud" : "Read aloud"}
              onClick={speak}
            >
              <Volume2 size={15} />
              {speaking ? <span className="hx__reading">reading aloud</span> : null}
            </button>
          ) : null}
        </div>
      ) : null}
      <div className="hx__note" role="status">
        {phase === "snoozed" ? <span data-testid="hb-returns">Snoozed · returns at 9:00</span> : null}
        {phase === "done" ? (
          <span>
            Done — Herald told WebWatcher, which told Gmail ·{" "}
            <button type="button" className="hx__link" data-testid="hb-show" onClick={show}>Show again</button>
          </span>
        ) : null}
      </div>
    </div>
  );
}
