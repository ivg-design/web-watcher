"use client";

import { useEffect, useRef, useState } from "react";
import { useInView, useReducedMotion } from "framer-motion";
import { asset } from "@/lib/config";

const SUBJECTS = ["Scripting update", "Office hours", "Release notes"];
// [delay ms, shown count, read index]
const STEPS: [number, number, number][] = [
  [250, 1, -1],
  [1000, 2, -1],
  [1750, 3, -1],
  [2800, 2, 1],
];

/** Accumulating notification: counts 1 -> 2 -> 3, then one is read and it drops to 2. Runs once. */
export default function GmailCard() {
  const reduce = useReducedMotion();
  const ref = useRef<HTMLDivElement>(null);
  const inView = useInView(ref, { once: true, margin: "0px 0px -15% 0px" });
  const [shown, setShown] = useState(3);
  const [read, setRead] = useState(-1);
  const [started, setStarted] = useState(false);

  useEffect(() => {
    if (reduce || !inView) return;
    setStarted(true);
    setShown(0);
    const timers = STEPS.map(([d, n, r]) =>
      window.setTimeout(() => {
        setShown(n);
        setRead(r);
      }, d),
    );
    return () => timers.forEach(window.clearTimeout);
  }, [inView, reduce]);

  const count = read >= 0 ? shown : shown;
  const visible = reduce || !started ? SUBJECTS : SUBJECTS.slice(0, Math.max(shown, read >= 0 ? 3 : 0));
  const label = shown === 0 && started ? "Watching Rive team" : `${count} new from Rive team`;

  return (
    <div ref={ref}>
      <div className="gnotif" role="group" aria-label="Example grouped notification">
        <img src={asset("/images/webwatcher-icon.png")} alt="" width={36} height={36} />
        <div className="gnotif__t" aria-live="off">
          <strong>{label}</strong>
          <span className="subjects">
            {visible.map((s, i) => (
              <span key={s} className={started && !reduce ? "subj--in" : undefined}>
                {i > 0 ? <span aria-hidden="true">{"· "}</span> : null}
                <span className={`subj${read === i ? " is-read" : ""}`}>{s}</span>
                {i < visible.length - 1 ? " " : ""}
              </span>
            ))}
          </span>
          <span>received Today 8:14 PM</span>
        </div>
        <span className="count roll" aria-label={`${count} unread`}>
          {count > 0 && (
            <span key={count} className={started && !reduce ? "roll__d" : undefined}>
              {count}
            </span>
          )}
        </span>
      </div>
      <div className="pillrow">
        {["Open", "Mark as Read", "Archive", "Delete"].map((b) => (
          <button key={b} type="button" className="pill" tabIndex={-1}>
            {b}
          </button>
        ))}
      </div>
    </div>
  );
}
