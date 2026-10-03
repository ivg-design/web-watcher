"use client";

import { useEffect, useRef, useState } from "react";
import { useInView, useReducedMotion } from "framer-motion";
import { ArrowDown, ArrowLeft, ArrowRight, ArrowUp, Bell, CornerDownLeft, X } from "lucide-react";

/** Step 2 mock: keys press in sequence, the outline hops twice, once when in view. */
export function PointerMock() {
  const ref = useRef<HTMLDivElement>(null);
  const inView = useInView(ref, { once: true, margin: "0px 0px -15% 0px" });
  const reduce = useReducedMotion();
  const [pressed, setPressed] = useState(-1);
  const [hop, setHop] = useState(false);

  useEffect(() => {
    if (!inView || reduce) return;
    const timers: number[] = [];
    // ↑ ↓ ← → press 160 ms apart, each held ~120 ms.
    [0, 1, 2, 3].forEach((k) => {
      timers.push(window.setTimeout(() => setPressed(k), 400 + k * 160));
      timers.push(window.setTimeout(() => setPressed((p) => (p === k ? -1 : p)), 400 + k * 160 + 120));
    });
    timers.push(window.setTimeout(() => setHop(true), 400));
    return () => timers.forEach(window.clearTimeout);
  }, [inView, reduce]);

  const keys = [ArrowUp, ArrowDown, ArrowLeft, ArrowRight];
  return (
    <div
      ref={ref}
      className="step__card"
      role="img"
      aria-label="Picker toolbar with arrow keys, confirm and cancel above an outlined Notifications bell, selector button.nav-bell › span.badge"
    >
      <div className="keybar" aria-hidden="true">
        {keys.map((Icon, i) => (
          <span key={i} className={`kbd${pressed === i ? " is-pressed" : ""}`}>
            <Icon size={13} />
          </span>
        ))}
        <span className="kbd"><CornerDownLeft size={12} /> confirm</span>
        <span className="kbd"><X size={12} /> cancel</span>
      </div>
      <div className={`picker-outline${hop ? " is-hopping" : ""}`} aria-hidden="true">
        <Bell size={14} /> Notifications
      </div>
      <div className="step__sel" aria-hidden="true">button.nav-bell › span.badge</div>
    </div>
  );
}
