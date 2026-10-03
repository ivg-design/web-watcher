"use client";

import { useEffect, useRef, useState } from "react";

/** Per-character 3D flip (rotateX out / in with stagger). Text swaps instantly under reduced motion. */
function Chars({ text, mode }: { text: string; mode: "out" | "in" | "static" }) {
  const n = Math.max(text.length - 1, 1);
  return (
    <>
      {text.split("").map((c, i) => (
        <span key={i} className={`wt-flip__c wt-flip__c--${mode}`} style={{ "--d": `${Math.round((i / n) * 160)}ms` } as React.CSSProperties}>
          {c === " " ? " " : c}
        </span>
      ))}
    </>
  );
}

export default function Flip({ text, testid, className }: { text: string; testid?: string; className?: string }) {
  const [cur, setCur] = useState(text);
  const [prev, setPrev] = useState<string | null>(null);
  const timer = useRef<number | undefined>(undefined);
  if (text !== cur) {
    setPrev(cur);
    setCur(text);
  }
  useEffect(() => {
    if (prev === null) return;
    window.clearTimeout(timer.current);
    timer.current = window.setTimeout(() => setPrev(null), 700);
    return () => window.clearTimeout(timer.current);
  }, [prev]);
  return (
    <span className={`wt-flip${className ? ` ${className}` : ""}`}>
      {prev !== null && (
        <span className="wt-flip__w" aria-hidden="true">
          <Chars text={prev} mode="out" />
        </span>
      )}
      <span className="wt-flip__w" data-testid={testid}>
        <Chars text={cur} mode={prev !== null ? "in" : "static"} />
      </span>
    </span>
  );
}
