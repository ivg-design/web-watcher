"use client";

import { useEffect, useRef, useState } from "react";
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
};

/* Notification text mirrors NotificationService.watcherContent defaults: title = watcher name. */
const ROWS: Row[] = [
  { slug: "badge", name: "Badge/Number", desc: "A number inside an element, or the (N) in a tab title like “(3) Inbox”. Notifies when the number rises.", Ex: BadgeEx, watcher: "Rive Community bell", body: "You have 5 new messages", value: "5" },
  { slug: "count", name: "Element Count", desc: "How many elements match: new rows, cards, replies. Notifies when the count rises.", Ex: CountEx, watcher: "Rive Community thread", body: "1 new item (4 total)", value: "4 items" },
  { slug: "text", name: "Text Change", desc: "Any text in the element, like a status. Notifies on any change.", Ex: TextEx, watcher: "Ticket 482 status", body: "Content updated", sub: "Closed", value: "Closed" },
  { slug: "exists", name: "Element Exists", desc: "An element turns up, like a “Sold out” label on a product page.", Ex: ExistsEx, watcher: "Studio headphones label", body: "Element appeared", value: "Sold out" },
  { slug: "disappears", name: "Element Disappears", desc: "An element goes away, like a “Join waitlist” button when a spot opens.", Ex: DisappearsEx, watcher: "Waitlist button", body: "Element disappeared", value: "gone" },
  { slug: "subtree", name: "Anything Changes Inside", desc: "A fingerprint of an element’s children, for a bell with no badge yet. Notifies on any change.", Ex: SubtreeEx, watcher: "Notifications bell", body: "Something changed inside the watched area", value: "changed" },
];

export default function WatchTypes() {
  const { record } = useWatch();
  const [done, setDone] = useState<Record<string, boolean>>({});
  const [notif, setNotif] = useState<Row | null>(null);
  const [flash, setFlash] = useState<string | null>(null);
  const timers = useRef<Record<string, number>>({});
  useEffect(() => {
    const t = timers.current;
    return () => Object.values(t).forEach(window.clearTimeout);
  }, []);

  const play = (r: Row) => {
    if (done[r.slug]) return;
    setDone((d) => ({ ...d, [r.slug]: true }));
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
        <h2 id="types-title" className="h2-v3">Badges are the start.</h2>
        <p className="lede">Six ways to read a page. The picker chooses one for you. Pick by hand when you know better. Click a panel to watch it change.</p>
        <ul className="wt-wall">
          {ROWS.map((r) => {
            const on = !!done[r.slug];
            const lands = notif?.slug === r.slug;
            const hint = on ? (r.value === "changed" ? "changed" : `changed: ${r.value}`) : "see it change";
            return (
              <li key={r.slug} className={`wt-panel${on ? " is-changed" : ""}${flash === r.slug ? " is-flash" : ""}${lands ? " has-notif" : ""}`} data-s={r.slug}>
                <button type="button" className="wt-btn" aria-pressed={on} data-testid={`wt-row-${r.slug}`} onClick={() => play(r)}>
                  <span className="wt-top">
                    <span id={`wt-n-${r.slug}`} className="t-label wt-name">{r.name}</span>
                    <span className="t-label wt-tick" aria-hidden="true"><Hourglass size={12} strokeWidth={1.75} />30 s</span>
                  </span>
                  <span className="wt-stage" aria-hidden="true"><r.Ex on={on} /></span>
                  <span className="wt-foot">
                    <span id={`wt-d-${r.slug}`} className="wt-desc">{r.desc}</span>
                    <span id={`wt-h-${r.slug}`} className="t-label wt-hint" aria-hidden="true">{hint}</span>
                  </span>
                </button>
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
              </li>
            );
          })}
        </ul>
        <p className="wt-profiles">
          <span className="t-label">Site profiles</span>
          <span>Rive community, LinkedIn, Reddit, Contra, and any site with a (N) tab title. One click fills in the right strategy, selector and refresh behaviour.</span>
        </p>
      </div>
    </section>
  );
}
