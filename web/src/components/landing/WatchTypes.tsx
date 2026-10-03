"use client";

import { useEffect, useRef, useState } from "react";
import { Sparkles } from "lucide-react";
import Reveal from "@/components/motion/Reveal";
import { useWatch } from "@/components/watch/WatchContext";
import { asset } from "@/lib/config";
import { AppearsEx, BadgeEx, CountEx, SubtreeEx, TextEx, TitleEx } from "./types/examples";
import "@/styles/watch-types.css";

type Row = {
  slug: string;
  name: string;
  desc: string;
  Ex: (p: { on: boolean }) => React.ReactElement;
  watcher: string;
  title: string;
  body: string;
  value: string;
};

const ROWS: Row[] = [
  { slug: "badge", name: "Badge count", desc: "A number inside an element. Notifies when it rises; shows the count.", Ex: BadgeEx, watcher: "Rive Community · bell", title: "Rive Community — 5 new", body: "Badge went 3 → 5", value: "5" },
  { slug: "text", name: "Text change", desc: "Any text in the element. Notifies on change, shows old → new.", Ex: TextEx, watcher: "Ticket 482 · status", title: "Ticket 482 — status changed", body: "Text went “Open” → “Closed”", value: "Closed" },
  { slug: "count", name: "Element count", desc: "How many elements match. New rows, new cards, new replies.", Ex: CountEx, watcher: "Rive Community · thread", title: "Rive Community — new reply", body: "Elements went 3 → 4", value: "4 items" },
  { slug: "appears", name: "Element appears / disappears", desc: "An element turns up, or goes away — a “Sold out” label, a “Join” button.", Ex: AppearsEx, watcher: "Studio headphones · label", title: "Studio headphones — Sold out", body: "“Sold out” appeared", value: "Sold out" },
  { slug: "title", name: "Document title", desc: "The tab title, e.g. (3) Inbox. No element needed.", Ex: TitleEx, watcher: "Inbox · tab title", title: "Inbox — 3 new", body: "Title went “(0) Inbox” → “(3) Inbox”", value: "(3) Inbox" },
  { slug: "subtree", name: "Anything changes inside", desc: "A fingerprint of an element’s children. For bells with no badge yet.", Ex: SubtreeEx, watcher: "Notifications · bell", title: "Notifications changed", body: "Contents changed — a badge appeared", value: "1" },
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
    record({ source: "types", name: r.watcher, title: r.title, body: r.body, value: r.value });
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
              <li key={r.slug} className={`wt-row${on ? " is-changed" : ""}`}>
                <button type="button" className="wt-row__btn" aria-label={`Watch ${r.name} change`} aria-pressed={on} data-testid={`wt-row-${r.slug}`} onClick={() => play(r)}>
                  <span className="wt-row__name">{r.name}</span>
                  <span className="wt-row__desc">{r.desc}</span>
                  <span className="wt-ex"><r.Ex on={on} /></span>
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
        <div className="wt-slot" aria-live="polite">
          {!notif && <p className="wt-slot__hint">The notification WebWatcher posts lands here. Click a row.</p>}
          {notif && (
            <div className="wt-notif" key={notif.slug} data-testid="wt-notif" role="group" aria-label="Notification as WebWatcher posts it">
              <img src={asset("/images/webwatcher-icon.png")} alt="" width={36} height={36} />
              <div className="wt-notif__t">
                <strong data-testid="wt-notif-title">{notif.title}</strong>
                <span>{notif.body}</span>
              </div>
              <span className="wt-notif__now">now</span>
            </div>
          )}
        </div>
        <Reveal className="wt-profiles" delay={0.1}>
          <Sparkles size={18} aria-hidden="true" />
          <span>Site profiles: Rive community, LinkedIn, Reddit, Contra, and any site with a (N) tab title — one click fills in the right strategy, selector and refresh behaviour.</span>
        </Reveal>
      </div>
    </section>
  );
}
