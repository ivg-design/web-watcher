"use client";

import { useLayoutEffect, useRef, useState } from "react";
import { asset } from "@/lib/config";
import { TOOLBAR_TEXT } from "./data";

type R = { x: number; y: number; w: number; h: number };
type Rects = { item: R; row: R; badge: R };

interface Props {
  beat: number;
  sub: number;
  pressed: "down" | "right" | "enter" | null;
}

const KEYS: { id: string; label: string; match: Props["pressed"] }[] = [
  { id: "up", label: "↑", match: null },
  { id: "left", label: "←", match: null },
  { id: "down", label: "↓", match: "down" },
  { id: "right", label: "→", match: "right" },
  { id: "enter", label: "⏎", match: "enter" },
];

export default function Stage({ beat, sub, pressed }: Props) {
  const page = useRef<HTMLDivElement>(null);
  const itemRef = useRef<HTMLLIElement>(null);
  const rowRef = useRef<HTMLDivElement>(null);
  const badgeRef = useRef<HTMLSpanElement>(null);
  const [rects, setRects] = useState<Rects | null>(null);

  useLayoutEffect(() => {
    const measure = () => {
      const p = page.current, a = itemRef.current, b = rowRef.current, c = badgeRef.current;
      if (!p || !a || !b || !c) return;
      const o = p.getBoundingClientRect();
      const m = (e: HTMLElement): R => {
        const r = e.getBoundingClientRect();
        return { x: r.left - o.left, y: r.top - o.top, w: r.width, h: r.height };
      };
      setRects({ item: m(a), row: m(b), badge: m(c) });
    };
    measure();
    const ro = new ResizeObserver(measure);
    if (page.current) ro.observe(page.current);
    return () => ro.disconnect();
  }, []);

  const picking = beat === 1;
  const locked = picking && sub >= 3;
  const target = !rects ? null : sub >= 2 ? rects.badge : sub === 1 ? rects.row : rects.item;
  const ticked = beat === 2 && sub >= 1;
  const notif = beat === 2 && sub >= 2;
  const badgeVal = ticked ? 3 : 2;

  return (
    <div className="hw-stage" data-testid="hw-stage" data-beat={beat + 1} data-sub={sub}>
      <div className="hw-win">
        <div className="hw-chrome">
          <div className="hw-bar1">
            <span className="hw-lights" aria-hidden="true"><i /><i /><i /></span>
            <div className="hw-tabs">
              <span className="hw-tab is-on"><b aria-hidden="true">C</b>Inbox · Contra</span>
              <span className="hw-tab"><b aria-hidden="true" className="alt">D</b>Docs</span>
            </div>
          </div>
          <div className="hw-bar2">
            <span className={"hw-url" + (beat === 0 ? " is-hl" : "")}>
              <svg viewBox="0 0 12 12" width="1em" height="1em" aria-hidden="true"><path d="M3 5.2V4a3 3 0 016 0v1.2M2.5 5.2h7v5h-7z" fill="none" stroke="currentColor" strokeWidth="1.1" /></svg>
              contra.com/inbox
            </span>
          </div>
        </div>

        <div className="hw-page" ref={page}>
          <aside className="hw-side">
            <p className="hw-brand">contra</p>
            <ul>
              <li className="hw-nav" ref={itemRef}>
                <div className="hw-navrow" ref={rowRef}>
                  <svg viewBox="0 0 16 16" width="1.2em" height="1.2em" aria-hidden="true"><path d="M2 4.5h12v8H2zM2.5 5l5.5 4 5.5-4" fill="none" stroke="currentColor" strokeWidth="1.2" strokeLinejoin="round" /></svg>
                  <span>Inbox</span>
                  <span
                    className={"hw-badge" + (ticked ? " is-tick" : "")}
                    data-testid="hw-badge"
                    data-prev="2"
                    ref={badgeRef}
                    key={badgeVal}
                  >{badgeVal}</span>
                </div>
              </li>
              <li className="hw-nav dim"><div className="hw-navrow"><svg viewBox="0 0 16 16" width="1.2em" height="1.2em" aria-hidden="true"><path d="M2 8l12-5-4 11-2.5-4.5z" fill="none" stroke="currentColor" strokeWidth="1.2" strokeLinejoin="round" /></svg><span>Sent</span></div></li>
              <li className="hw-nav dim"><div className="hw-navrow"><svg viewBox="0 0 16 16" width="1.2em" height="1.2em" aria-hidden="true"><path d="M2.5 3.5h11v9h-11zM2.5 6.5h11" fill="none" stroke="currentColor" strokeWidth="1.2" /></svg><span>Projects</span></div></li>
            </ul>
          </aside>
          <main className="hw-main">
            <h4>Inbox</h4>
            <div className="hw-thread unread">
              <i className="hw-av a" aria-hidden="true">DW</i>
              <div><p className="who">Dana Whitfield <span>Harbor &amp; Co</span></p><p className="pv">Can you send the revised quote before Friday?</p></div>
              <time>2 days ago</time>
            </div>
            <div className="hw-thread unread">
              <i className="hw-av b" aria-hidden="true">PR</i>
              <div><p className="who">Priya Raman <span>Kite Labs</span></p><p className="pv">Scope for the May sprint, ok to start?</p></div>
              <time>Mon</time>
            </div>
            <div className={"hw-thread hw-thread--new" + (ticked ? " unread is-new" : "")} data-testid="hw-newmail">
              <i className="hw-av c" aria-hidden="true">ML</i>
              <div><p className="who">Marcus Lee <span>Northwind</span></p><p className="pv">Contract draft v3 attached</p></div>
              <time>{ticked ? "now" : "Sun"}</time>
            </div>
            <div className="hw-thread">
              <i className="hw-av d" aria-hidden="true">TI</i>
              <div><p className="who">Tomás Ibarra <span>Foxglove</span></p><p className="pv">Thanks, invoice received.</p></div>
              <time>Fri</time>
            </div>
          </main>

          <span
            className={"hw-outline" + (picking ? " is-on" : "") + (locked ? " is-locked" : "") + (picking ? "" : " no-anim")}
            data-testid="hw-outline"
            style={target ? { width: target.w, height: target.h, transform: `translate(${target.x}px, ${target.y}px)` } : undefined}
          />

          <div className={"hw-keys" + (picking ? " is-on" : "")} aria-hidden="true">
            {KEYS.map((k) => (
              <kbd key={k.id} className={pressed && k.match === pressed ? "is-down" : ""}>{k.label}</kbd>
            ))}
          </div>
          <div className={"hw-toolbar" + (picking ? " is-on" : "")} data-testid="hw-toolbar" aria-hidden={!picking}>
            <span>{TOOLBAR_TEXT}</span>
            <button type="button" tabIndex={-1}>Use this element</button>
            <button type="button" tabIndex={-1} className="ghost">Cancel</button>
          </div>
        </div>
      </div>

      <div className={"hw-sheet" + (beat === 2 ? " is-pop" : "")} data-testid="hw-sheet">
        <div className="hw-sheet__in" key={`${beat}-${beat === 1 && sub >= 3 ? "l" : "p"}-${beat === 2 && sub >= 2 ? "n" : "m"}`}>
          {beat !== 2 && (
            <p className="hw-sheet__h"><img src={asset("/images/webwatcher-icon.png")} alt="" aria-hidden="true" width={16} height={16} />Add Watcher</p>
          )}
          {beat === 0 && (
            <>
              <p className="hw-sheet__t">Found in Safari: Inbox · Contra</p>
              <p className="hw-sheet__m">contra.com/inbox</p>
            </>
          )}
          {beat === 1 && (locked ? (
            <>
              <p className="hw-sheet__t">Watching: badge count · 2</p>
              <p className="hw-sheet__m">span.badge</p>
            </>
          ) : (
            <>
              <p className="hw-sheet__t">Pick in Safari</p>
              <p className="hw-sheet__m">Use the arrow keys, then Return</p>
            </>
          ))}
          {beat === 2 && (
            <p className="hw-sheet__row"><i aria-hidden="true" />Contra · Inbox badge — {notif ? 3 : 2}</p>
          )}
        </div>
      </div>

      <div className={"hw-notif" + (notif ? " is-on" : "")} data-testid="hw-notif" aria-hidden={!notif}>
        <img src={asset("/images/webwatcher-icon.png")} alt="" aria-hidden="true" width={36} height={36} />
        <div>
          <p className="t">Contra</p>
          <p className="b">You have 3 new messages</p>
        </div>
        <time>now</time>
      </div>
    </div>
  );
}
