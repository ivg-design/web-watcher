import { Accessibility, GitBranch, Hash, Heading1, Sparkles, TextCursor } from "lucide-react";
import Reveal from "@/components/motion/Reveal";
import "@/styles/sections-a.css";

const TYPES = [
  { Icon: Hash, name: "Badge count", desc: "A number inside an element. Notifies when it rises; shows the count.", before: "3", after: "5" },
  { Icon: TextCursor, name: "Text change", desc: "Any text in the element. Notifies on change, shows old → new.", before: "“Open”", after: "“Closed”" },
  { Icon: GitBranch, name: "Subtree change", desc: "A fingerprint of an element’s children. For bells with no badge yet.", before: "48 items", after: "51" },
  { Icon: Heading1, name: "Document title", desc: "The tab title, e.g. “(3) Inbox”. No element needed.", before: "(0)", after: "(3)" },
  { Icon: Accessibility, name: "ARIA count", desc: "aria-label / aria-live counters that have no visible number.", single: "aria-label=“2 new”" },
] as const;

export default function WatchTypes() {
  return (
    <section id="watch-types" className="section" aria-labelledby="types-title">
      <div className="container">
        <Reveal>
          <p className="eyebrow">What it can watch</p>
          <h2 id="types-title" className="h2">Badges are the start.</h2>
          <p className="lede">Five ways to read a page, chosen for you by the picker — or by hand when you know better.</p>
        </Reveal>
        <ul className="types" style={{ listStyle: "none", padding: 0 }}>
          {TYPES.map((t, i) => (
            <Reveal as="li" key={t.name} className="type" delay={i * 0.06} y={12}>
              <t.Icon className="type__ico" size={22} aria-hidden="true" />
              <span className="type__name">{t.name}</span>
              <span className="type__desc">{t.desc}</span>
              <span className="type__eg">
                {"single" in t ? (
                  <span className="eg">{t.single}</span>
                ) : (
                  <span className="eg" aria-label={`${t.before} to ${t.after}`}>
                    <span className="eg__b" aria-hidden="true">{t.before}</span>
                    <span className="eg__arrow" aria-hidden="true">→</span>
                    <span className="eg__a" aria-hidden="true">{t.after}</span>
                  </span>
                )}
              </span>
            </Reveal>
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
