"use client";

import { useEffect, useState } from "react";

/**
 * The roll primitive as a component: when `v` changes the old value rolls up and the new one rolls in
 * from below (180 ms). The outgoing layer is drawn from a data attribute so textContent only ever
 * holds the current value. `instant` swaps without a roll.
 */
export default function Roll({ v, instant = false }: { v: string | number; instant?: boolean }) {
  const s = String(v);
  const [st, setSt] = useState<{ cur: string; prev: string | null }>({ cur: s, prev: null });
  if (st.cur !== s) setSt({ cur: s, prev: instant ? null : st.cur });
  useEffect(() => {
    if (st.prev === null) return;
    const t = window.setTimeout(() => setSt((x) => (x.cur === st.cur ? { cur: x.cur, prev: null } : x)), 200);
    return () => window.clearTimeout(t);
  }, [st.cur, st.prev]);
  return (
    <span className="roll">
      {st.prev !== null && <span key={"o" + st.prev + st.cur} className="roll__v is-out" data-v={st.prev} aria-hidden="true" />}
      <span key={st.cur} className={"roll__v" + (st.prev === null ? " is-still" : "")}>{st.cur}</span>
    </span>
  );
}
