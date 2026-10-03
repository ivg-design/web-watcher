"use client";

import { useEffect, useRef, useState } from "react";
import { Sparkles } from "lucide-react";
import Reveal from "@/components/motion/Reveal";
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
  const timers = useRef<Record<string, number>>({});
  useEffect(() => {
    const t = timers.current;
    return () => Object.values(t).forEach(window.clearTimeout);
  }, []);

  const play = (r: Row) => {
    if (done[r.slug]) return;
    setDone((d) => ({ ...d, [r.slug]: true }));
    record({ source: "types", name: r.watcher, title: r.watcher, body: r.body, value: r.value });
    window.clearTimeout(timers.current.notif);
    timers.current.notif = window.setTimeout(() => setNotif(r), 450);
  };
  const reset = (r: Row) => {
    setDone((d) => ({ ...d, [r.slug]: false }));
    setNotif((n) => (n?.slug === r.slug ? null : n));
    if (notif?.slug !== r.slug) return;
    window.clearTimeout(timers.current.notif);
  };

  return (
    <section id="watch-types" className="section" aria-labelledby="types-title">
      <div className="container">
        <Reveal>
          <p className="eyebrow"><span className="eyebrow__n">03</span>What it can watch</p>
          <h2 id="types-title" className="h2">Badges are the start.</h2>
          <p className="lede">Six ways to read a page. The picker chooses one for you; pick by hand when you know better. Click a row to watch it happen.</p>
        </Reveal>
        <ul className="wt-table">
          {ROWS.map((r) => {
            const on = !!done[r.slug];
            return (
              <li key={r.slug} className={`wt-row${on ? " is-changed" : ""}`} data-s={r.slug === "count" ? "list" : r.slug === "exists" || r.slug === "disappears" ? "prod" : undefined}>
                <button type="button" className="wt-row__btn" aria-label={`Watch ${r.name} change`} aria-pressed={on} data-testid={`wt-row-${r.slug}`} onClick={() => play(r)}>
                  <span className="wt-row__name">{r.name}</span>
                  <span className="wt-row__dw">
                    <span className="wt-row__desc">{r.desc}</span>
                    {!on && <span className="wt-row__hint" aria-hidden="true">see it change ▸</span>}
                  </span>
                  <span className="wt-ex">
                    <span className="wt-stage">
                      <span className="wt-stage__in"><r.Ex on={on} /></span>
                      {!on && <span className="wt-tap" aria-hidden="true">tap</span>}
                    </span>
                  </span>
                </button>
                {on && (
                  <span className="wt-row__state">
                    <i aria-hidden="true" />changed
                  </span>
                )}
                {on && (
                  <button type="button" className="wt-row__reset" data-testid={`wt-reset-${r.slug}`} aria-label={`Reset ${r.name}`} onClick={() => reset(r)}>
                    Reset
                  </button>
                )}
              </li>
            );
          })}
        </ul>
        <div className="wt-slot">
          {!notif && <p className="wt-slot__hint">The notification <span className="nw">WebWatcher</span> posts lands here. Click a row.</p>}
          <div className="wt-live" aria-live="polite">
            {notif && (
              <div className="wt-notif" key={notif.slug} data-testid="wt-notif" role="group" aria-label="Notification as WebWatcher posts it">
                <img src={asset("/images/webwatcher-icon.png")} alt="" aria-hidden="true" width={36} height={36} />
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
        <Reveal className="wt-profiles" delay={0.1}>
          <Sparkles size={18} aria-hidden="true" />
          <span>Site profiles: Rive community, LinkedIn, Reddit, Contra, and any site with a (N) tab title — one click fills in the right strategy, selector and refresh behaviour.</span>
        </Reveal>
      </div>
    </section>
  );
}
