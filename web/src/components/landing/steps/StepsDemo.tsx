"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { useWatch } from "@/components/watch/WatchContext";
import { STEPS, DURATION, SUBS, FINAL_SUB, HOLD_MS } from "./data";
import Stage from "./Stage";
import Transport from "./Transport";

type Key = "down" | "right" | "enter" | null;

const STARTS = DURATION.reduce<number[]>((a, d, i) => { a.push(i === 0 ? 0 : a[i - 1] + DURATION[i - 1]); return a; }, []);
const stamp = (ms: number) => `t+${(ms / 1000).toFixed(1)} s`;

export default function StepsDemo({ lede }: { lede?: React.ReactNode }) {
  const { record } = useWatch();
  const [beat, setBeat] = useState(0);
  const [sub, setSub] = useState(0);
  const [epoch, setEpoch] = useState(0);
  const [active, setActive] = useState(false);
  const [reduce, setReduce] = useState(false);
  const [pressed, setPressed] = useState<Key>(null);
  const [notified, setNotified] = useState(false);
  const root = useRef<HTMLDivElement>(null);
  const holdUntil = useRef(0);
  const clicked = useRef(false);
  const recorded = useRef(false);
  const activeRef = useRef(false);

  useEffect(() => {
    const mq = window.matchMedia("(prefers-reduced-motion: reduce)");
    const apply = () => {
      setReduce(mq.matches);
      if (mq.matches) { setBeat(2); setSub(FINAL_SUB[2]); setNotified(true); }
    };
    apply();
    mq.addEventListener("change", apply);
    return () => mq.removeEventListener("change", apply);
  }, []);

  useEffect(() => {
    const el = root.current;
    if (!el) return;
    const io = new IntersectionObserver(
      ([e]) => {
        if (e.intersectionRatio >= 0.5 || e.intersectionRect.height >= window.innerHeight * 0.5) {
          if (!activeRef.current) { activeRef.current = true; if (!window.matchMedia("(prefers-reduced-motion: reduce)").matches) setSub(0); }
          setActive(true);
        }
        else if (!e.isIntersecting) { activeRef.current = false; setActive(false); }
      },
      { threshold: [0, 0.25, 0.5, 0.75] },
    );
    io.observe(el);
    return () => io.disconnect();
  }, []);

  // Sequencer: sub-steps inside a beat, then advance (unless held / out of view).
  useEffect(() => {
    if (reduce) return;
    if (!active) return;
    const timers: number[] = [];
    const keys: Key[] = [null, "down", "right", "enter"];
    SUBS[beat].forEach((at, i) => {
      const n = i + 1;
      timers.push(window.setTimeout(() => {
        setSub(n);
        if (beat === 2 && n >= 2) setNotified(true);
        if (beat === 1) {
          setPressed(keys[n]);
          timers.push(window.setTimeout(() => setPressed(null), 320));
        }
      }, at));
    });
    const advance = () => {
      const wait = holdUntil.current - Date.now();
      if (wait > 0) {
        timers.push(window.setTimeout(advance, wait));
        return;
      }
      setSub(0);
      setPressed(null);
      if (beat === 2) setNotified(false);
      setBeat((b) => (b + 1) % 3);
    };
    timers.push(window.setTimeout(advance, DURATION[beat]));
    return () => timers.forEach(clearTimeout);
  }, [beat, epoch, active, reduce]);

  // Report the change once per visit.
  useEffect(() => {
    if (beat === 2 && sub >= 2 && !recorded.current && (active || clicked.current)) {
      recorded.current = true;
      record({ source: "steps", name: "Contra", title: "Contra", body: "You have 3 new messages", value: "3" });
    }
  }, [beat, sub, active, record]);

  const go = useCallback((i: number) => {
    clicked.current = true;
    holdUntil.current = Date.now() + HOLD_MS;
    activeRef.current = true;
    setActive(true);
    if (i === 0) setNotified(false);
    else if (reduce && i === 2) setNotified(true);
    setBeat(i);
    setSub(reduce ? FINAL_SUB[i] : 0);
    setPressed(null);
    setEpoch((e) => e + 1);
  }, [reduce]);

  const chapters = (
    <ol className="hw-steps" aria-label="Three steps on a time ruler">
      {STEPS.map((s, i) => {
        const on = i === beat;
        return (
          <li key={s.title}>
            <button
              type="button"
              className={"hw-step" + (on ? " is-on" : "")}
              data-testid={`hw-step-${i + 1}`}
              aria-current={on ? "step" : undefined}
              onClick={() => go(i)}
            >
              <span className="hw-step__n t-label" data-testid={`hw-time-${i + 1}`}>{stamp(STARTS[i])}</span>
              <span className="hw-step__t">{s.title}</span>
              <span className="hw-step__c">{s.copy}</span>
            </button>
          </li>
        );
      })}
    </ol>
  );

  return (
    <div className="hw" ref={root}>
      <div className="hw-frame">
        <Stage beat={beat} sub={sub} pressed={pressed} />
      </div>
      <Transport beat={beat} epoch={epoch} active={active} reduce={reduce} notified={notified} aside={lede}>{chapters}</Transport>
    </div>
  );
}
