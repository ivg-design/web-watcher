"use client";

import "@/styles/privacy.css";
import { useEffect, useRef, useState } from "react";
import Link from "next/link";
import { asset } from "@/lib/config";
import Roll from "./hero/Roll";

const SWITCHES = [
  { label: "Safari ▸ Develop ▸ Allow JavaScript from Apple Events", note: "Lets WebWatcher read the tab you point it at." },
  { label: "System Settings ▸ Privacy & Security ▸ Automation ▸ Safari & System Events", note: "One prompt, once." },
  { label: "Notifications ▸ Allow", note: "So changes can reach you." },
];

const ZEROS = ["servers", "analytics", "data collected"];
const STEP = 140;

function Zeros() {
  const ref = useRef<HTMLDivElement>(null);
  const [v, setV] = useState([0, 0, 0]);
  const [inst, setInst] = useState(true);
  useEffect(() => {
    const el = ref.current;
    if (!el || window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    const timers: number[] = [];
    const io = new IntersectionObserver(([e]) => {
      if (!e.isIntersecting) return;
      io.disconnect();
      setInst(true);
      setV([3, 3, 3]);
      ZEROS.forEach((_, i) => {
        for (let k = 1; k <= 3; k++) {
          timers.push(window.setTimeout(() => {
            setInst(false);
            setV((a) => a.map((x, j) => (j === i ? 3 - k : x)));
          }, 120 * i + STEP * k + 30));
        }
      });
    }, { threshold: 0.4 });
    io.observe(el);
    return () => { io.disconnect(); timers.forEach(clearTimeout); };
  }, []);
  return (
    <div className="pvz" ref={ref} role="list" aria-label="No servers, no analytics, no data collected" data-testid="pv-zeros">
      {ZEROS.map((l, i) => (
        <div className="pvz__i" role="listitem" aria-label={`No ${l}`} key={l} data-testid={`pv-zero-${i + 1}`}>
          <span className="pvz__n t-wide t-num" aria-hidden="true">(<Roll v={v[i]} instant={inst} />)</span>
          <span className="pvz__l" aria-hidden="true">{l}</span>
        </div>
      ))}
    </div>
  );
}

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
      <div className="pvd__node pvd__node--core pvd__n2" data-testid="pv-node-2"><b><span className="nw">WebWatcher</span></b><span>your Mac</span></div>
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
    <section id="privacy" className="pvx section">
      <div className="container">
        <div className="pvx__top">
          <h2 className="h2-v3 pvx__h">It runs on your Mac, in your Safari, and nowhere else.</h2>
          <p className="pvx__p">
            Checks run in the Safari tab you are already signed into, nothing is proxied or logged, and your config
            lives in <code>~/Library/Application Support/WebWatcher/</code>. Gmail tokens stay in the macOS Keychain
            with the <code>gmail.modify</code> scope only. The app is <span className="nw">Developer ID</span> signed and notarized, MIT licensed,
            with the source on <span className="nw">GitHub</span>.
          </p>
        </div>
        <Zeros />
        <Diagram />
        <div className="pvs">
          <div className="pvs__head">
            <h3 className="pvs__h">Three switches, once</h3>
            <p className="pvs__sub">The only setup macOS asks for. Try them.</p>
          </div>
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
                  <span className="pvs__t"><span>{s.label.split(" ▸ ").map((seg, k) => <span key={seg}>{k > 0 && " ▸ "}<span className="nw">{seg}</span></span>)}</span><small>{s.note}</small></span>
                  <span className="pvs__tg" aria-hidden="true" />
                </button>
              </li>
            ))}
          </ul>
          <div className="pvs__ready" aria-live="polite" data-on={ready}>
            {ready && (
              <span data-testid="pv-ready">
                Ready. <Link href={asset("/docs/first-watcher")}>Add your first watcher →</Link>
              </span>
            )}
          </div>
        </div>
      </div>
    </section>
  );
}
