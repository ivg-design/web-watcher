"use client";

import { useEffect, useRef, useState } from "react";
import Roll from "./hero/Roll";
import { Hourglass } from "lucide-react";
import { useWatch } from "@/components/watch/WatchContext";
import { asset } from "@/lib/config";
import { BadgeEx, CountEx, DisappearsEx, ExistsEx, SubtreeEx, TextEx } from "./types/examples";
import "@/styles/watch-types.css";

type Row = {
  slug: string;
  name: string;
  desc: string;
  Ex: (p: { on: boolean }) => React.ReactElement;
  /** The watcher's name, which is also the notification title. */
  watcher: string;
  sub?: string;
  body: string;
  value: string;
  /** What the page read before the change. */
  was: string;
  /** The watcher's own interval (the app's list) and its fixed phase, in seconds. */
  every: number;
  offset: number;
  /** "fit": old and new share one line when the column is wide enough; otherwise stacked. */
  fit?: boolean;
};

/* Notification text mirrors NotificationService.watcherContent defaults: title = watcher name. */
const ROWS: Row[] = [
  { slug: "badge", name: "Badge/Number", desc: "A number inside an element, or the (N) in a tab title like “(3) Inbox”. Notifies when the number rises.", Ex: BadgeEx, watcher: "Rive Community bell", body: "You have 5 new messages", value: "5", was: "3", every: 30, offset: 0, fit: true },
  { slug: "count", name: "Element Count", desc: "How many elements match: new rows, cards, replies. Notifies when the count rises.", Ex: CountEx, watcher: "Rive Community thread", body: "1 new item (4 total)", value: "4 items", was: "3 items", every: 15, offset: 7 },
  { slug: "text", name: "Text Change", desc: "Any text in the element, like a status. Notifies on any change.", Ex: TextEx, watcher: "Ticket 482 status", body: "Content updated", sub: "Closed", value: "Closed", was: "Open", every: 60, offset: 23, fit: true },
  { slug: "exists", name: "Element Exists", desc: "An element turns up, like a “Sold out” label on a product page.", Ex: ExistsEx, watcher: "Studio headphones label", body: "Element appeared", value: "Sold out", was: "absent", every: 120, offset: 41 },
  { slug: "disappears", name: "Element Disappears", desc: "An element goes away, like a “Join waitlist” button when a spot opens.", Ex: DisappearsEx, watcher: "Waitlist button", body: "Element disappeared", value: "gone", was: "present", every: 300, offset: 97 },
  { slug: "subtree", name: "Anything Changes Inside", desc: "A fingerprint of an element’s children, for a bell with no badge yet. Notifies on any change.", Ex: SubtreeEx, watcher: "Notifications bell", body: "Something changed inside the watched area", value: "changed", was: "no badge", every: 600, offset: 211 },
];

const fmt = (n: number) => `${Math.floor(n / 60)}:${String(n % 60).padStart(2, "0")}`;
const everyLabel = (n: number) => (n < 60 ? `${n} s` : `${n / 60} min`);
const stamp = (ms: number) => {
  const d = new Date(ms);
  const h = d.getHours();
  return `${h % 12 || 12}:${String(d.getMinutes()).padStart(2, "0")}:${String(d.getSeconds()).padStart(2, "0")} ${h < 12 ? "AM" : "PM"}`;
};

export default function WatchTypes() {
  const { record } = useWatch();
  const [done, setDone] = useState<Record<string, boolean>>({});
  const [notif, setNotif] = useState<Row | null>(null);
  const [flash, setFlash] = useState<string | null>(null);
  const [clicked, setClicked] = useState<Record<string, number>>({});
  /** Wall-clock seconds, null until mounted (server HTML shows the intervals). */
  const [now, setNow] = useState<number | null>(null);
  const [reduced, setReduced] = useState(false);
  const [seen, setSeen] = useState(false);
  const board = useRef<HTMLUListElement>(null);
  const timers = useRef<Record<string, number>>({});
  useEffect(() => {
    const t = timers.current;
    return () => Object.values(t).forEach(window.clearTimeout);
  }, []);
  useEffect(() => {
    const mq = window.matchMedia("(prefers-reduced-motion: reduce)");
    const upd = () => setReduced(mq.matches);
    const id = window.setTimeout(upd, 0);
    mq.addEventListener("change", upd);
    return () => { window.clearTimeout(id); mq.removeEventListener("change", upd); };
  }, []);
  useEffect(() => {
    const el = board.current;
    if (!el) return;
    const io = new IntersectionObserver(([e]) => setSeen(e.isIntersecting), { rootMargin: "100px" });
    io.observe(el);
    return () => io.disconnect();
  }, []);
  useEffect(() => {
    if (reduced || !seen) return;
    let iv = 0;
    const tick = () => setNow(Math.floor(Date.now() / 1000));
    const run = () => { window.clearInterval(iv); if (document.hidden) return; tick(); iv = window.setInterval(tick, 1000); };
    run();
    document.addEventListener("visibilitychange", run);
    return () => { window.clearInterval(iv); document.removeEventListener("visibilitychange", run); };
  }, [reduced, seen]);

  const play = (r: Row) => {
    if (done[r.slug]) return;
    setDone((d) => ({ ...d, [r.slug]: true }));
    setClicked((c) => ({ ...c, [r.slug]: Date.now() }));
    record({ source: "types", name: r.watcher, title: r.watcher, body: r.body, value: r.value });
    setFlash(r.slug);
    window.clearTimeout(timers.current.flash);
    timers.current.flash = window.setTimeout(() => setFlash(null), 1200);
    window.clearTimeout(timers.current.notif);
    timers.current.notif = window.setTimeout(() => setNotif(r), 450);
  };
  const reset = (r: Row) => {
    setDone((d) => ({ ...d, [r.slug]: false }));
    setFlash((f) => (f === r.slug ? null : f));
    if (notif?.slug === r.slug || flash === r.slug) window.clearTimeout(timers.current.notif);
    setNotif((n) => (n?.slug === r.slug ? null : n));
  };

  return (
    <section id="watch-types" className="section wt" aria-labelledby="types-title">
      <div className="container">
        <div className="wt-head">
          <h2 id="types-title" className="h2-v3">Badges are the start.</h2>
          <p className="lede">Six ways to read a page. The picker chooses one for you. Pick by hand when you know better. Click a row to change its page and check it now.</p>
        </div>
        <div className="wt-board">
          <div className="wt-cols t-label" aria-hidden="true">
            <span>Next check</span><span>Watches</span><span>On the page</span><span>Reads</span>
          </div>
          <ul className="wt-wall" ref={board}>
            {ROWS.map((r) => {
              const on = !!done[r.slug];
              const lands = notif?.slug === r.slug;
              const hint = on ? "changed" : "see it change";
              const live = now !== null && !reduced;
              const elapsed = live ? (now + r.offset) % r.every : 0;
              const remaining = r.every - elapsed;
              const flip = live && Math.floor((now + r.offset) / r.every) % 2 === 1;
              const lastMs = live ? Math.max((now - elapsed) * 1000, clicked[r.slug] ?? 0) : null;
              const next = reduced ? everyLabel(r.every) : fmt(live ? remaining : r.every);
              return (
                <li key={r.slug} className={`wt-panel${on ? " is-changed" : ""}${flash === r.slug ? " is-flash" : ""}${lands ? " has-notif" : ""}`} data-s={r.slug}>
                  <button type="button" className="wt-btn" aria-pressed={on} aria-labelledby={`wt-n-${r.slug}`} aria-describedby={`wt-d-${r.slug}`} data-testid={`wt-row-${r.slug}`} onClick={() => play(r)}>
                    <span className="wt-next" aria-hidden="true">
                      <span className={`t-wide t-num wt-next__n${reduced ? " is-static" : ""}`} data-testid={`wt-next-${r.slug}`}>{next}</span>
                      <span className="t-label wt-tick">
                        <span className={`wt-glass${flip ? " is-flipped" : ""}`}><Hourglass size={12} strokeWidth={1.75} /></span>
                        every {everyLabel(r.every)}
                      </span>
                    </span>
                    <span className="wt-watches">
                      <span id={`wt-n-${r.slug}`} className="t-cond wt-name">{r.name}</span>
                      <span id={`wt-d-${r.slug}`} className="wt-desc">{r.desc}</span>
                      <span id={`wt-h-${r.slug}`} className="t-label wt-hint" aria-hidden="true">{hint}</span>
                    </span>
                    <span className="wt-stage" aria-hidden="true"><r.Ex on={on} /></span>
                    <span className="wt-reads" aria-hidden="true">
                      <span className="wt-rv">
                        <span className="t-label wt-rl">reads</span>
                        <span className={`wt-val t-wide t-num${on ? " is-on" : ""}${r.fit ? " is-fit" : " is-stack"}`}>
                          {on && <span key="was" className="wt-was" data-testid={`wt-was-${r.slug}`}>{r.was}</span>}
                          {on && <span key="rule" className="wt-rule" />}
                          <span key="now" className="wt-now" data-testid={on ? `wt-now-${r.slug}` : `wt-reads-${r.slug}`}><Roll v={on ? r.value : r.was} /></span>
                        </span>
                      </span>
                      <span className="t-label wt-stamp" data-testid={`wt-stamp-${r.slug}`}>{lastMs !== null ? `read ${stamp(lastMs)}` : "\u00a0"}</span>
                    </span>
                  </button>
                  <div className="wt-after">
                    {on && (
                      <button type="button" className="t-label wt-reset" data-testid={`wt-reset-${r.slug}`} aria-label={`Put ${r.name} back`} onClick={() => reset(r)}>
                        Put it back
                      </button>
                    )}
                    <div className="wt-live" aria-live="polite">
                      {lands && notif && (
                        <div className="wt-notif" data-testid="wt-notif" role="group" aria-label="Notification as WebWatcher posts it">
                          <img src={asset("/images/webwatcher-icon-tile.png")} alt="" aria-hidden="true" width={36} height={36} />
                          <div className="wt-notif__t">
                            <strong data-testid="wt-notif-title">{notif.watcher}</strong>
                            {notif.sub && <b className="wt-notif__sub" data-testid="wt-notif-sub">{notif.sub}</b>}
                            <span data-testid="wt-notif-body">{notif.body}</span>
                          </div>
                          <span className="wt-notif__now">now</span>
                        </div>
                      )}
                    </div>
                  </div>
                </li>
              );
            })}
          </ul>
        </div>
        <p className="wt-profiles">
          <span className="t-label">Site profiles</span>
          <span>Rive community, LinkedIn, Reddit, Contra, and any site with a (N) tab title. One click fills in the right strategy, selector and refresh behaviour.</span>
        </p>
      </div>
    </section>
  );
}
