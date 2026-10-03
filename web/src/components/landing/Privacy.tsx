"use client";

import "@/styles/privacy.css";
import { useEffect, useRef, useState } from "react";
import Link from "next/link";
import Reveal from "@/components/motion/Reveal";
import { asset } from "@/lib/config";

const SWITCHES = [
  { label: "Safari ▸ Develop ▸ Allow JavaScript from Apple Events", note: "Lets WebWatcher read the tab you point it at." },
  { label: "System Settings ▸ Privacy & Security ▸ Automation ▸ Safari & System Events", note: "One prompt, once." },
  { label: "Notifications ▸ Allow", note: "So changes can reach you." },
];

function Diagram() {
  const ref = useRef<HTMLDivElement>(null);
  const [live, setLive] = useState(false);
  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    const io = new IntersectionObserver(([e]) => setLive(e.isIntersecting), { threshold: 0.2 });
    io.observe(el);
    return () => io.disconnect();
  }, []);
  return (
    <div className="pvd" ref={ref} data-live={live} data-testid="pv-diagram" role="group" aria-label="Data path: Safari tab to WebWatcher to Notification Center. The internet is not on the path.">
      <div className="pvd__node pvd__n1" data-testid="pv-node-1"><b>Safari tab</b><span>your session</span></div>
      <div className="pvd__conn pvd__c1" aria-hidden="true"><i className="pvd__dot" /></div>
      <div className="pvd__node pvd__node--core pvd__n2" data-testid="pv-node-2"><b>WebWatcher</b><span>your Mac</span></div>
      <div className="pvd__conn pvd__c2" aria-hidden="true"><i className="pvd__dot" /></div>
      <div className="pvd__node pvd__n3" data-testid="pv-node-3"><b>Notification Center / Herald</b><span>your Mac</span></div>
      <div className="pvd__gm" data-testid="pv-node-gmail">
        <div className="pvd__stub" aria-hidden="true" />
        <div className="pvd__node"><b>Gmail API</b><span>only if you sign in, tokens in Keychain</span></div>
      </div>
      <div className="pvd__net" data-testid="pv-node-net">
        <div className="pvd__node"><b>The internet</b><span>Not on the path. Your page data never goes here.</span></div>
      </div>
    </div>
  );
}

export default function Privacy() {
  const [on, setOn] = useState([false, false, false]);
  const ready = on.every(Boolean);
  return (
    <section id="privacy" className="pvx">
      <div className="container">
        <div className="pvx__top">
          <Reveal>
            <p className="eyebrow"><span className="eyebrow__n">06</span>Privacy &amp; permissions</p>
            <h2 className="pvx__h">It runs on your Mac, in your Safari, and nowhere else.</h2>
            <p className="pvx__p">
              Checks run in the Safari tab you are already signed into, nothing is proxied or logged, and your config
              lives in <code>~/Library/Application Support/WebWatcher/</code>. Gmail tokens stay in the macOS Keychain
              with the <code>gmail.modify</code> scope only. The app is <span className="nw">Developer ID</span> signed and notarized, MIT licensed,
              with the source on GitHub.
            </p>
          </Reveal>
          <Reveal delay={0.1}>
            <Diagram />
          </Reveal>
        </div>
        <div className="pvs">
          <div>
            <h3 className="pvs__h">Three switches, once</h3>
            <p className="pvs__sub">The only setup macOS asks for. Try them.</p>
          </div>
          <div>
            <ul className="pvs__list">
              {SWITCHES.map((s, i) => (
                <li key={s.label}>
                  <button
                    type="button"
                    role="switch"
                    aria-checked={on[i]}
                    className="pvs__row"
                    data-testid={`pv-switch-${i + 1}`}
                    onClick={() => setOn((o) => o.map((v, j) => (j === i ? !v : v)))}
                  >
                    <span className="pvs__n">0{i + 1}</span>
                    <span className="pvs__t">{s.label}<small>{s.note}</small></span>
                    <span className="pvs__tg" aria-hidden="true" />
                  </button>
                </li>
              ))}
            </ul>
            <div className="pvs__ready" aria-live="polite" data-on={ready}>
              {ready && (
                <span data-testid="pv-ready">
                  Ready — <Link href={asset("/docs/first-watcher")}>add your first watcher →</Link>
                </span>
              )}
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
