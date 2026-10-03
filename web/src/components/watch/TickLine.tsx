"use client";

import { useEffect, useState } from "react";
import { useWatch } from "./WatchContext";
import { CHECK_EVENT } from "./events";

/**
 * The menu bar's bottom edge is the countdown to the next check: it advances one step a second and
 * cuts back to zero when the check happens. It follows the interval picked in "The interval".
 */
export default function TickLine() {
  const { interval, timed } = useWatch();
  const [n, setN] = useState(0);
  useEffect(() => {
    const on = () => setN((v) => v + 1);
    window.addEventListener(CHECK_EVENT, on);
    return () => window.removeEventListener(CHECK_EVENT, on);
  }, []);
  if (!timed) return null;
  return (
    <span className="tickline" data-testid="tickline" data-interval={interval} data-n={n} aria-hidden="true">
      <i key={`${interval}-${n}`} style={{ animationDuration: `${interval}s`, animationTimingFunction: `steps(${interval}, end)` }} />
    </span>
  );
}
