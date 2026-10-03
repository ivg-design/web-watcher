"use client";

import { useEffect, useRef, useState, type CSSProperties, type ReactNode } from "react";
import { Volume2, X } from "lucide-react";
import { asset } from "@/lib/config";
import "@/styles/herald.css";

type Phase = "idle" | "shown" | "leaving" | "snoozed" | "done";
type Id = 1 | 2;
const AUDIO_EMAIL3 = "/audio/herald-email-3.mp3";
const AUDIO_EMAIL4 = "/audio/herald-email-4.mp3";
const AUDIO_CONTRA = "/audio/herald-contra.mp3";
const BARS = [0, 1, 2, 3, 4];
// deterministic pseudo level for bar i at playback time t (0.25..1)
const barLevel = (t: number, i: number) => 0.25 + 0.75 * Math.abs(Math.sin(t * 7.3 + i * 1.7) * Math.cos(t * 3.1 + i * 0.9));
const SLIDE_MS = 240;
const GROW_MS = 220;

type BannerProps = {
  id: Id;
  phase: Phase;
  testid: string;
  tip: string;
  app: string;
  time: string;
  title: ReactNode;
  body: ReactNode;
  pills: { testid: string; label: string; snooze?: boolean }[];
  closeId: string;
  speakId: string;
  speaking: boolean;
  level: number;
  onLeave: (next: "done" | "snoozed") => void;
  onSpeak: () => void;
  icon: string;
};

function Banner(p: BannerProps) {
  return (
    <div
      className={`hx__banner${p.phase === "leaving" ? " is-out" : " is-in"}`}
      data-testid={p.testid}
      role="group"
      aria-label={p.id === 1 ? "Herald banner" : "Herald banner, WebWatcher Contra"}
    >
      <img className="hx__icon" src={p.icon} alt="" aria-hidden="true" width={56} height={56} />
      <div className="hx__main">
        <div className="hx__top">
          <span className="hx__app">{p.app}</span>
          <span className="hx__time">{p.time}</span>
          <span className="hx__ctl">
          <button
            type="button"
            className={`hx__speak${p.speaking ? " is-on" : ""}`}
            data-testid={p.speakId}
            data-speaking={p.speaking ? "1" : "0"}
            aria-pressed={p.speaking}
            aria-label="Read aloud"
            onClick={p.onSpeak}
          >
            {p.speaking ? (
              <span className="hx__meter" aria-hidden="true">
                {BARS.map((i) => (
                  <i key={i} style={{ "--l": barLevel(p.level, i).toFixed(2) } as CSSProperties} />
                ))}
              </span>
            ) : (
              <Volume2 size={14} aria-hidden="true" />
            )}
            {p.speaking ? <span className="hx__reading">reading</span> : null}
          </button>
          <button type="button" className="hx__x" data-testid={p.closeId} aria-label="Dismiss" onClick={() => p.onLeave("done")}>
            <X size={13} strokeWidth={2.6} />
          </button>
          </span>
        </div>
        <div className={p.speaking ? "hx__tw is-reading" : "hx__tw"}>{p.title}</div>
        {p.body}
        <div className="hx__btns">
          {p.pills.map((b) =>
            b.snooze ? (
              <button key={b.testid} type="button" className="hx__pill hx__snooze" data-testid={b.testid} aria-describedby={p.tip} onClick={() => p.onLeave("snoozed")}>
                {b.label}
                <span className="hx__tip" id={p.tip} role="tooltip">returns at 9:00</span>
              </button>
            ) : (
              <button key={b.testid} type="button" className="hx__pill" data-testid={b.testid} onClick={() => p.onLeave("done")}>{b.label}</button>
            ),
          )}
        </div>
      </div>
    </div>
  );
}


export default function HeraldDemo() {
  const [ph, setPh] = useState<Record<Id, Phase>>({ 1: "idle", 2: "idle" });
  const phRef = useRef<Record<Id, Phase>>({ 1: "idle", 2: "idle" });
  const [enter, setEnter] = useState<Record<Id, number>>({ 1: 0, 2: 0 });
  const [speaking, setSpeaking] = useState<0 | Id>(0);
  const [count, setCount] = useState(3);
  const [prev, setPrev] = useState<number | null>(null);
  const [level, setLevel] = useState(0);
  const audioRef = useRef<HTMLAudioElement | null>(null);
  const stage = useRef<HTMLDivElement>(null);
  const slots = useRef<Record<Id, HTMLDivElement | null>>({ 1: null, 2: null });
  const started = useRef(false);
  const timers = useRef<number[]>([]);
  const snoozeT = useRef<Partial<Record<Id, number>>>({});
  const later = (fn: () => void, ms: number) => {
    const t = window.setTimeout(fn, ms);
    timers.current.push(t);
    return t;
  };
  const reduced = () => window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  const setP = (id: Id, p: Phase) => {
    phRef.current = { ...phRef.current, [id]: p };
    setPh(phRef.current);
  };

  const showOne = (id: Id) => {
    window.clearTimeout(snoozeT.current[id]);
    setEnter((e) => ({ ...e, [id]: e[id] + 1 }));
    setP(id, "shown");
  };
  const showBoth = () => {
    if (phRef.current[1] !== "shown") showOne(1);
    if (phRef.current[2] !== "shown") later(() => showOne(2), reduced() ? 0 : 700);
  };

  // a banner that re-enters after its slot collapsed grows back open
  useEffect(() => {
    ([1, 2] as Id[]).forEach((id) => {
      const el = slots.current[id];
      if (!el || !el.classList.contains("is-collapsed") || phRef.current[id] !== "shown") return;
      void el.offsetHeight;
      el.classList.remove("is-collapsed");
      later(() => el.classList.remove("is-collapsing"), GROW_MS);
    });
  }, [enter]);

  useEffect(() => {
    const el = stage.current;
    if (!el) return;
    const go = () => {
      if (started.current) return;
      started.current = true;
      io.disconnect();
      hio?.disconnect();
      showOne(1);
      later(() => showOne(2), reduced() ? 0 : 700);
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
      audioRef.current?.pause();
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const stopSpeech = () => {
    audioRef.current?.pause();
    setSpeaking(0);
  };
  const collapse = (id: Id) => {
    const el = slots.current[id];
    if (!el) return;
    el.classList.add("is-collapsing");
    void el.offsetHeight;
    el.classList.add("is-collapsed");
  };
  const leave = (id: Id, next: "done" | "snoozed") => {
    if (phRef.current[id] !== "shown") return;
    if (speaking === id) stopSpeech();
    setP(id, "leaving");
    later(
      () => {
        // the banner stays mounted (invisible) while its slot folds, so the grid-rows transition has content to fold
        collapse(id);
        later(() => {
          setP(id, next);
          if (next === "snoozed") snoozeT.current[id] = later(() => showOne(id), 3000);
        }, reduced() ? 0 : GROW_MS);
      },
      reduced() ? 0 : SLIDE_MS,
    );
  };
  const speak = (id: Id) => {
    if (speaking === id) return stopSpeech();
    let a = audioRef.current;
    if (!a) {
      a = new Audio();
      a.preload = "none";
      a.addEventListener("timeupdate", () => setLevel(a!.currentTime));
      a.addEventListener("ended", () => setSpeaking(0));
      a.addEventListener("error", () => setSpeaking(0));
      audioRef.current = a;
    }
    a.pause();
    a.src = asset(id === 2 ? AUDIO_CONTRA : count > 3 ? AUDIO_EMAIL4 : AUDIO_EMAIL3);
    a.currentTime = 0;
    setLevel(0);
    setSpeaking(id);
    try {
      void Promise.resolve(a.play()).catch(() => setSpeaking(0));
    } catch {
      setSpeaking(0);
    }
  };
  const deliver = () => {
    if (count >= 4) return;
    setPrev(count);
    setCount(4);
    later(() => setPrev(null), 520);
    if (phRef.current[1] !== "shown" && phRef.current[1] !== "leaving") showOne(1);
  };

  const icon = asset("/images/herald-icon.png");
  const rolling = prev !== null;
  const emailBody = (count > 3 ? "Beta invite · " : "") + "Scripting update · Office hours · Release notes";
  const note1 = ph[1];

  return (
    <div className="hxw">
      <div className="hx" ref={stage}>
        <div className="hx__menubar" aria-hidden="true">
          <span className="hx__apple" />
          <span>Finder</span>
          <span className="hx__clock">Thu 8:14 PM</span>
        </div>
        <div className="hx__stack" aria-live="off">
          {ph[1] !== "idle" ? (
            <div className="hx__slot" ref={(el) => { slots.current[1] = el; }}>
              <div className="hx__slotin">
              {ph[1] === "shown" || ph[1] === "leaving" ? (
                <Banner
                  key={enter[1]}
                  id={1}
                  phase={ph[1]}
                  testid="hb-banner"
                  tip="hx-tip"
                  icon={icon}
                  app="WebWatcher · Email"
                  time="now"
                  title={
                    <div className="hx__title">
                      <span className={`hx__count${rolling ? " is-rolling" : ""}`}>
                        <span className="hx__roll" key={count}>{count}</span>
                        {rolling ? <span className="hx__roll hx__roll--old" aria-hidden="true" key={"o" + prev}>{prev}</span> : null}
                      </span>
                      {" new from Rive team"}
                    </div>
                  }
                  body={<div className={`hx__body${rolling ? " is-fresh" : ""}`}>{emailBody}</div>}
                  pills={[
                    { testid: "hb-read", label: "Mark as Read" },
                    { testid: "hb-archive", label: "Archive" },
                    { testid: "hb-delete", label: "Delete" },
                    { testid: "hb-spam", label: "Spam" },
                    { testid: "hb-snooze", label: "Snooze", snooze: true },
                  ]}
                  closeId="hb-close"
                  speakId="hb-speak"
                  speaking={speaking === 1}
                  level={level}
                  onLeave={(n) => leave(1, n)}
                  onSpeak={() => speak(1)}
                />
              ) : null}
              </div>
            </div>
          ) : null}
          {ph[2] !== "idle" ? (
            <div className="hx__slot" ref={(el) => { slots.current[2] = el; }}>
              <div className="hx__slotin">
              {ph[2] === "shown" || ph[2] === "leaving" ? (
                <Banner
                  key={enter[2]}
                  id={2}
                  phase={ph[2]}
                  testid="hb-banner-2"
                  tip="hx-tip-2"
                  icon={icon}
                  app="WebWatcher · Contra"
                  time="2 min ago"
                  title={<div className="hx__title">Contra</div>}
                  body={<div className="hx__body">You have 1 new message</div>}
                  pills={[
                    { testid: "hb2-open", label: "Open" },
                    { testid: "hb2-snooze", label: "Snooze", snooze: true },
                  ]}
                  closeId="hb2-close"
                  speakId="hb2-speak"
                  speaking={speaking === 2}
                  level={level}
                  onLeave={(n) => leave(2, n)}
                  onSpeak={() => speak(2)}
                />
              ) : null}
              </div>
            </div>
          ) : null}
        </div>
        <div className="hx__note" role="status">
          {note1 === "snoozed" ? <span data-testid="hb-returns">Snoozed · returns at 9:00</span> : null}
          {note1 === "done" ? (
            <span>
              Done. Herald told WebWatcher, which told Gmail.{" "}
              <button type="button" className="hx__link" data-testid="hb-show" onClick={showBoth}>Show again</button>
            </span>
          ) : null}
        </div>
      </div>
      <div className="hx__under">
        <button type="button" className="hx__link hx__more" data-testid="hb-more" disabled={count >= 4} onClick={deliver}>
          {count >= 4 ? "Delivered from Rive team" : "Deliver another from Rive team"}
        </button>
        <p className="hx__caption">Banners stay until you act on them, stacked per sender or site.</p>
        <p className="hx__caption">Herald can read a banner aloud. This is how it sounds.</p>
      </div>
    </div>
  );
}
