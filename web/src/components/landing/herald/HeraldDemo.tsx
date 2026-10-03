"use client";

import { useEffect, useRef, useState, useSyncExternalStore, type ReactNode } from "react";
import { Volume2, X } from "lucide-react";
import { asset } from "@/lib/config";
import "@/styles/herald.css";

type Phase = "idle" | "shown" | "leaving" | "snoozed" | "done";
type Id = 1 | 2;
const SPOKEN3 = "3 new from Rive team. Scripting update, office hours, release notes.";
const SPOKEN4 = "4 new from Rive team. Beta invite, scripting update, office hours, release notes.";
const SPOKEN_WEB = "Contra, 1 new. Inbox badge went 0 to 1.";
const SLIDE_MS = 240;
const GROW_MS = 300;

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
  canSpeak: boolean;
  speaking: boolean;
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
      <img className="hx__icon" src={p.icon} alt="" width={56} height={56} />
      <div className="hx__main">
        <div className="hx__top">
          <span className="hx__app">{p.app}</span>
          <span className="hx__time">{p.time}</span>
          <button type="button" className="hx__x" data-testid={p.closeId} aria-label="Dismiss" onClick={() => p.onLeave("done")}>
            <X size={13} strokeWidth={2.6} />
          </button>
        </div>
        {p.title}
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
      {p.canSpeak ? (
        <button
          type="button"
          className={`hx__speak${p.speaking ? " is-on" : ""}`}
          data-testid={p.speakId}
          data-speaking={p.speaking ? "1" : "0"}
          aria-pressed={p.speaking}
          aria-label={p.speaking ? "Stop reading aloud" : "Read aloud"}
          onClick={p.onSpeak}
        >
          <Volume2 size={15} />
          {p.speaking ? <span className="hx__reading">reading aloud</span> : null}
        </button>
      ) : null}
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
  const canSpeak = useSyncExternalStore(
    () => () => {},
    () => "speechSynthesis" in window && !!window.speechSynthesis,
    () => false,
  );
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
      if (!el || el.style.height !== "0px" || phRef.current[id] !== "shown") return;
      el.classList.add("is-collapsing");
      void el.offsetHeight;
      el.style.height = el.scrollHeight + "px";
      later(() => {
        el.style.height = "";
        el.classList.remove("is-collapsing");
      }, GROW_MS);
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
      try {
        window.speechSynthesis?.cancel();
      } catch {}
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const stopSpeech = () => {
    try {
      window.speechSynthesis?.cancel();
    } catch {}
    setSpeaking(0);
  };
  const collapse = (id: Id) => {
    const el = slots.current[id];
    if (!el) return;
    el.style.height = el.offsetHeight + "px";
    el.classList.add("is-collapsing");
    void el.offsetHeight;
    el.style.height = "0px";
  };
  const leave = (id: Id, next: "done" | "snoozed") => {
    if (phRef.current[id] !== "shown") return;
    if (speaking === id) stopSpeech();
    setP(id, "leaving");
    later(
      () => {
        collapse(id);
        setP(id, next);
        if (next === "snoozed") snoozeT.current[id] = later(() => showOne(id), 3000);
      },
      reduced() ? 0 : SLIDE_MS,
    );
  };
  const speak = (id: Id) => {
    if (speaking === id) return stopSpeech();
    try {
      window.speechSynthesis?.cancel();
      const u = new SpeechSynthesisUtterance(id === 2 ? SPOKEN_WEB : count > 3 ? SPOKEN4 : SPOKEN3);
      u.onend = () => setSpeaking(0);
      u.onerror = () => setSpeaking(0);
      setSpeaking(id);
      window.speechSynthesis.speak(u);
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
        <div className="hx__stack">
          {ph[1] !== "idle" ? (
            <div className="hx__slot" ref={(el) => { slots.current[1] = el; }}>
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
                    { testid: "hb-open", label: "Open" },
                    { testid: "hb-read", label: "Mark as Read" },
                    { testid: "hb-archive", label: "Archive" },
                    { testid: "hb-snooze", label: "Snooze", snooze: true },
                  ]}
                  closeId="hb-close"
                  speakId="hb-speak"
                  canSpeak={canSpeak}
                  speaking={speaking === 1}
                  onLeave={(n) => leave(1, n)}
                  onSpeak={() => speak(1)}
                />
              ) : null}
            </div>
          ) : null}
          {ph[2] !== "idle" ? (
            <div className="hx__slot" ref={(el) => { slots.current[2] = el; }}>
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
                  title={<div className="hx__title">Contra — 1 new</div>}
                  body={<div className="hx__body">Inbox badge went 0 → 1</div>}
                  pills={[
                    { testid: "hb2-open", label: "Open" },
                    { testid: "hb2-dismiss", label: "Dismiss" },
                    { testid: "hb2-snooze", label: "Snooze", snooze: true },
                  ]}
                  closeId="hb2-close"
                  speakId="hb2-speak"
                  canSpeak={canSpeak}
                  speaking={speaking === 2}
                  onLeave={(n) => leave(2, n)}
                  onSpeak={() => speak(2)}
                />
              ) : null}
            </div>
          ) : null}
        </div>
        <div className="hx__note" role="status">
          {note1 === "snoozed" ? <span data-testid="hb-returns">Snoozed · returns at 9:00</span> : null}
          {note1 === "done" ? (
            <span>
              Done — Herald told WebWatcher, which told Gmail ·{" "}
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
      </div>
    </div>
  );
}
