"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { useWatch } from "@/components/watch/WatchContext";
import { STEPS, DURATION, SUBS, FINAL_SUB, HOLD_MS } from "./data";
import Stage from "./Stage";

type Key = "down" | "right" | "enter" | null;

export default function StepsDemo() {
  const { record } = useWatch();
  const [beat, setBeat] = useState(0);
  const [sub, setSub] = useState(0);
  const [epoch, setEpoch] = useState(0);
  const [held, setHeld] = useState(false);
  const [active, setActive] = useState(false);
  const [reduce, setReduce] = useState(false);
  const [pressed, setPressed] = useState<Key>(null);
  const root = useRef<HTMLDivElement>(null);
  const holdUntil = useRef(0);
  const clicked = useRef(false);
  const recorded = useRef(false);
  const activeRef = useRef(false);

  useEffect(() => {
    const mq = window.matchMedia("(prefers-reduced-motion: reduce)");
    const apply = () => {
      setReduce(mq.matches);
      if (mq.matches) { setBeat(2); setSub(FINAL_SUB[2]); }
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
        if (beat === 1) {
          setPressed(keys[n]);
          timers.push(window.setTimeout(() => setPressed(null), 320));
        }
      }, at));
    });
    const advance = () => {
      const wait = holdUntil.current - Date.now();
      if (wait > 0) {
        timers.push(window.setTimeout(() => { setHeld(false); advance(); }, wait));
        return;
      }
      setHeld(false);
      setSub(0);
      setPressed(null);
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
    setHeld(true);
    activeRef.current = true;
    setActive(true);
    setBeat(i);
    setSub(reduce ? FINAL_SUB[i] : 0);
    setPressed(null);
    setEpoch((e) => e + 1);
  }, [reduce]);

  return (
    <div className="hw" ref={root}>
      <ol className="hw-steps">
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
                <span className="hw-step__n">0{i + 1}</span>
                <span className="hw-step__t">{s.title}</span>
                <span className="hw-step__s">{s.short}</span>
                <span className="hw-step__c">{s.copy}</span>
                <span className="hw-bar" aria-hidden="true">
                  {on && (
                    <i
                      key={`${beat}-${epoch}`}
                      className={held || reduce ? "is-full" : ""}
                      style={{ animationDuration: `${DURATION[beat]}ms`, animationPlayState: active ? "running" : "paused" }}
                    />
                  )}
                </span>
              </button>
            </li>
          );
        })}
      </ol>
      <Stage beat={beat} sub={sub} pressed={pressed} />
    </div>
  );
}
