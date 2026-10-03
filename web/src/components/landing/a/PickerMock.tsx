"use client";

import { useEffect, useRef, useState } from "react";
import { useInView } from "framer-motion";

type Block = "bell" | "link" | "title" | "list";
const ROWS: { id: Block; title: string; code: string; chip: string; best?: boolean }[] = [
  { id: "bell", title: "Notifications bell · badge “3”", code: "button.nav-bell › span.badge", chip: "badge count", best: true },
  { id: "link", title: "Inbox link · “Inbox (12)”", code: "a[href='/inbox']", chip: "text with number" },
  { id: "title", title: "Page title · “(3) Feed — Rive”", code: "document.title", chip: "document title" },
  { id: "list", title: "Feed list · 48 children", code: "main › ul.feed", chip: "subtree change" },
];

const BLOCKS: Record<Block, React.CSSProperties> = {
  title: { left: 6, top: 5, width: 60, height: 6 },
  bell: { right: 6, top: 4, width: 14, height: 9 },
  link: { left: 6, top: 17, width: 34, height: 6 },
  list: { left: 46, top: 17, width: 80, height: 24 },
};

export default function PickerMock() {
  const [sel, setSel] = useState<Block>("bell");
  const [hover, setHover] = useState<Block | null>(null);
  const [pulse, setPulse] = useState(false);
  const ref = useRef<HTMLDivElement>(null);
  const inView = useInView(ref, { once: true, margin: "0px 0px -20% 0px" });
  const btns = useRef<(HTMLButtonElement | null)[]>([]);

  useEffect(() => {
    if (inView) setPulse(true);
  }, [inView]);

  const hot = hover ?? sel;
  const move = (i: number, d: number) => {
    const n = (i + d + ROWS.length) % ROWS.length;
    setSel(ROWS[n].id);
    btns.current[n]?.focus();
  };

  return (
    <div
      ref={ref}
      className="pcard"
      role="group"
      aria-label="Illustration of the WebWatcher guided picker listing four candidate elements found on a page"
    >
      <div className="pcard__steps" aria-hidden="true">
        <span className="pstep">1 Page</span>
        <span className="pstep--chev">›</span>
        <span className="pstep pstep--on">2 Element</span>
        <span className="pstep--chev">›</span>
        <span className="pstep">3 Confirm</span>
      </div>
      <p className="pcard__q">Showing a count? Pick one of these, or Pick in Safari to point at it yourself.</p>
      <div role="radiogroup" aria-label="Candidate elements" onMouseLeave={() => setHover(null)}>
        {ROWS.map((r, i) => (
          <button
            key={r.id}
            ref={(el) => { btns.current[i] = el; }}
            type="button"
            role="radio"
            aria-checked={sel === r.id}
            tabIndex={sel === r.id ? 0 : -1}
            className={`prow${sel === r.id ? " is-on" : ""}`}
            onClick={() => setSel(r.id)}
            onMouseEnter={() => setHover(r.id)}
            onFocus={() => setHover(r.id)}
            onBlur={() => setHover(null)}
            onKeyDown={(e) => {
              if (e.key === "ArrowDown" || e.key === "ArrowRight") { e.preventDefault(); move(i, 1); }
              if (e.key === "ArrowUp" || e.key === "ArrowLeft") { e.preventDefault(); move(i, -1); }
            }}
          >
            <span className="prow__radio" aria-hidden="true" />
            <span className="prow__t">
              <strong>{r.title}</strong>
              <code>{r.code}</code>
            </span>
            <span className="chip">{r.chip}</span>
            {r.best && <span className={`chip chip--best${pulse ? " is-pulsing" : ""}`}>best match</span>}
          </button>
        ))}
      </div>
      <div className="pcard__foot" aria-hidden="true">
        <span className="link-arrow">Pick in Safari instead →</span>
        <div className="sketch" title="">
          {(Object.keys(BLOCKS) as Block[]).map((b) => (
            <i key={b} className={hot === b ? "is-hot" : ""} style={BLOCKS[b]} />
          ))}
        </div>
        <span className="btn btn--primary btn--sm">Use this element</span>
      </div>
    </div>
  );
}
