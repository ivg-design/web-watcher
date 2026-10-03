"use client";

import { useEffect, useRef, useState } from "react";
import { Accessibility, GitBranch, Hash, Heading1, Sparkles, TextCursor, type LucideIcon } from "lucide-react";
import Reveal from "@/components/motion/Reveal";
import { asset } from "@/lib/config";
import "@/styles/sections-a.css";
import "@/styles/watch-types.css";

type T = {
  slug: string;
  Icon: LucideIcon;
  name: string;
  desc: string;
  before: string;
  after: string;
  title: string;
  body: string;
};

const TYPES: T[] = [
  { slug: "badge", Icon: Hash, name: "Badge count", desc: "A number inside an element. Notifies when it rises; shows the count.", before: "3", after: "5", title: "Rive Community — 5 new", body: "Notifications badge went 3 → 5" },
  { slug: "text", Icon: TextCursor, name: "Text change", desc: "Any text in the element. Notifies on change, shows old → new.", before: "“Open”", after: "“Closed”", title: "Status changed", body: "Text went “Open” → “Closed”" },
  { slug: "subtree", Icon: GitBranch, name: "Subtree change", desc: "A fingerprint of an element’s children. For bells with no badge yet.", before: "48 items", after: "51 items", title: "Notifications changed", body: "Contents changed: 48 → 51 items" },
  { slug: "title", Icon: Heading1, name: "Document title", desc: "The tab title, e.g. “(3) Inbox”. No element needed.", before: "(0)", after: "(3)", title: "Inbox changed", body: "Tab title went “(0) Inbox” → “(3) Inbox”" },
  { slug: "aria", Icon: Accessibility, name: "ARIA count", desc: "aria-label / aria-live counters that have no visible number.", before: "1 new", after: "2 new", title: "Rive Community — 2 new", body: "aria-label went “1 new” → “2 new”" },
];

type Phase = "idle" | "changed" | "notified";

function Row({ t, i }: { t: T; i: number }) {
  const [phase, setPhase] = useState<Phase>("idle");
  const [ran, setRan] = useState(false);
  const timers = useRef<number[]>([]);
  useEffect(() => () => timers.current.forEach(window.clearTimeout), []);

  const run = (resetFirst: boolean) => {
    timers.current.forEach(window.clearTimeout);
    timers.current = [];
    setRan(true);
    const start = () => {
      setPhase("changed");
      timers.current.push(window.setTimeout(() => setPhase("notified"), 450));
    };
    if (resetFirst) {
      setPhase("idle");
      timers.current.push(window.setTimeout(start, 350));
    } else start();
  };

  const busy = phase === "changed";
  const shown = phase === "idle" ? t.before : t.after;
  return (
    <Reveal as="li" className="type" delay={i * 0.06} y={12}>
      <t.Icon className="type__ico" size={22} aria-hidden="true" />
      <span className="type__name">{t.name}</span>
      <span className="type__desc">{t.desc}</span>
      <span className="type__eg">
        <span className="wt-ctl">
          <span className="wt-val" data-testid={`wt-val-${t.slug}`}>
            <span key={phase === "idle" ? "b" : "a"} className={`wt-val__v${phase === "idle" ? "" : " is-changed"}`}>{shown}</span>
          </span>
          {ran ? (
            <button type="button" className="wt-btn" disabled={busy} data-testid={`wt-replay-${t.slug}`} onClick={() => run(true)}>
              Replay
            </button>
          ) : (
            <button type="button" className="wt-btn" data-testid={`wt-play-${t.slug}`} onClick={() => run(false)}>
              Play
            </button>
          )}
        </span>
      </span>
      <div className="wt-live" aria-live="polite">
        {phase === "notified" && (
          <div className="wt-notif" data-testid={`wt-notif-${t.slug}`} role="group" aria-label="Notification as WebWatcher posts it">
            <img src={asset("/images/webwatcher-icon.png")} alt="" width={34} height={34} />
            <div className="wt-notif__t">
              <strong>{t.title}</strong>
              <span>{t.body}</span>
            </div>
            <span className="wt-notif__now">now</span>
          </div>
        )}
      </div>
    </Reveal>
  );
}

export default function WatchTypes() {
  return (
    <section id="watch-types" className="section" aria-labelledby="types-title">
      <div className="container">
        <Reveal>
          <p className="eyebrow">What it can watch</p>
          <h2 id="types-title" className="h2">Badges are the start.</h2>
          <p className="lede">Five ways to read a page, chosen for you by the picker — or by hand when you know better. Press Play to see the change and the notification it produces.</p>
        </Reveal>
        <ul className="types" style={{ listStyle: "none", padding: 0 }}>
          {TYPES.map((t, i) => (
            <Row key={t.slug} t={t} i={i} />
          ))}
        </ul>
        <Reveal className="profiles" delay={0.1}>
          <Sparkles size={20} aria-hidden="true" />
          <span>
            Site profiles: Rive community, LinkedIn, Reddit, Contra, and any site with a (N) tab
            title — one click fills in the right strategy, selector and refresh behaviour.
          </span>
        </Reveal>
      </div>
    </section>
  );
}
