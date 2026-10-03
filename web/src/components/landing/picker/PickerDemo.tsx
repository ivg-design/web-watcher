"use client";

import { useCallback, useEffect, useLayoutEffect, useRef, useState } from "react";
import { Bell, Check, CornerDownLeft, Inbox, MousePointer2, ScanSearch, X, ArrowUp, ArrowDown, ArrowLeft, ArrowRight } from "lucide-react";
import { asset } from "@/lib/config";
import { CANDIDATES, NODES, siblings, type NodeId } from "./data";
import "@/styles/picker.css";

type Step = 1 | 2 | 3;
type Rect = { left: number; top: number; width: number; height: number };

export default function PickerDemo() {
  const [step, setStep] = useState<Step>(1);
  const [scanned, setScanned] = useState(false);
  const [scanning, setScanning] = useState(false);
  const [sel, setSel] = useState<NodeId>("badge");
  const [chosen, setChosen] = useState<NodeId | null>(null);
  const [picking, setPicking] = useState(false);
  const [hover, setHover] = useState<NodeId | null>(null);
  const [reading, setReading] = useState(false);
  const [added, setAdded] = useState(false);
  const [rect, setRect] = useState<Rect | null>(null);

  const sketchRef = useRef<HTMLDivElement>(null);
  const radios = useRef<(HTMLButtonElement | null)[]>([]);
  const timers = useRef<number[]>([]);
  useEffect(() => () => timers.current.forEach(window.clearTimeout), []);
  const later = (fn: () => void, ms: number) => { timers.current.push(window.setTimeout(fn, ms)); };

  // In picking mode the outline follows hover (mouse) or the keyboard cursor; otherwise the selected candidate.
  const lit: NodeId = picking ? (hover ?? sel) : sel;

  const measure = useCallback(() => {
    const root = sketchRef.current;
    const el = root?.querySelector<HTMLElement>(`[data-node="${lit}"]`);
    if (!root || !el) { setRect(null); return; }
    const a = root.getBoundingClientRect();
    const b = el.getBoundingClientRect();
    setRect({ left: b.left - a.left, top: b.top - a.top, width: b.width, height: b.height });
  }, [lit]);
  useLayoutEffect(() => { measure(); }, [measure, step]);
  useEffect(() => {
    const root = sketchRef.current;
    if (!root || typeof ResizeObserver === "undefined") return;
    const ro = new ResizeObserver(measure);
    ro.observe(root);
    return () => ro.disconnect();
  }, [measure, step]);

  const runScan = () => {
    setScanning(true);
    later(() => { setScanning(false); setScanned(true); setStep(2); }, 650);
  };

  const confirmElement = (id: NodeId) => {
    setChosen(id);
    setSel(id);
    setPicking(false);
    setHover(null);
    setAdded(false);
    setReading(true);
    setStep(3);
    later(() => setReading(false), 700);
  };

  const goStep = (s: Step) => {
    if (s === 1) { setStep(1); setPicking(false); }
    else if (s === 2 && scanned) { setStep(2); setPicking(false); }
    else if (s === 3 && chosen) { setStep(3); setPicking(false); }
  };

  const startPicking = () => {
    setPicking(true);
    setHover(null);
    // keyboard cursor starts on the current element when it is part of the page DOM
    if (sel === "title") setSel("badge");
    later(() => sketchRef.current?.focus(), 30);
  };
  const stopPicking = () => {
    setPicking(false);
    setHover(null);
    setSel((s) => (CANDIDATES.some((c) => c.id === s) ? s : "badge"));
  };

  useEffect(() => {
    if (!picking) return;
    const onKey = (e: KeyboardEvent) => { if (e.key === "Escape") stopPicking(); };
    document.addEventListener("keydown", onKey);
    return () => document.removeEventListener("keydown", onKey);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [picking]);

  const moveCursor = (to: NodeId | null | undefined) => { if (to) { setSel(to); setHover(null); } };
  const onSketchKey = (e: React.KeyboardEvent) => {
    if (!picking) return;
    const node = NODES[sel];
    const sibs = siblings(sel);
    const idx = sibs.indexOf(sel);
    switch (e.key) {
      case "ArrowUp": e.preventDefault(); moveCursor(node.parent); break;
      case "ArrowDown": e.preventDefault(); moveCursor(node.children[0]); break;
      case "ArrowRight": e.preventDefault(); moveCursor(sibs[idx + 1]); break;
      case "ArrowLeft": e.preventDefault(); moveCursor(sibs[idx - 1]); break;
      case "Enter": e.preventDefault(); confirmElement(sel); break;
      case "Escape": e.preventDefault(); stopPicking(); break;
    }
  };
  const nodeAt = (t: EventTarget | null): NodeId | null => {
    const el = (t as HTMLElement | null)?.closest?.("[data-node]") as HTMLElement | null;
    const id = el?.dataset.node as NodeId | undefined;
    return id && id !== "title" ? id : null;
  };

  const onRadioKey = (e: React.KeyboardEvent, i: number) => {
    const d = e.key === "ArrowDown" || e.key === "ArrowRight" ? 1 : e.key === "ArrowUp" || e.key === "ArrowLeft" ? -1 : 0;
    if (!d) return;
    e.preventDefault();
    const k = (i + d + CANDIDATES.length) % CANDIDATES.length;
    setSel(CANDIDATES[k].id);
    radios.current[k]?.focus();
  };

  const target = NODES[picking ? lit : sel];
  const done = chosen ? NODES[chosen] : null;

  return (
    <div className="pd" data-testid="pd" data-step={step} data-picking={picking ? "1" : "0"}>
      <ol className="pd__steps" aria-label="Add Watcher steps">
        {([["1", "Page"], ["2", "Element"], ["3", "Confirm"]] as const).map(([k, label]) => {
          const s = Number(k) as Step;
          const enabled = s === 1 || (s === 2 && scanned) || (s === 3 && !!chosen);
          return (
            <li key={k}>
              <button
                type="button"
                data-testid={`pd-step-${k}`}
                className={`pd__pill${step === s ? " is-on" : ""}`}
                aria-current={step === s ? "step" : undefined}
                disabled={!enabled}
                onClick={() => goStep(s)}
              >
                <b>{k}</b> {label}
              </button>
            </li>
          );
        })}
      </ol>

      {(
        <div className={`pd__work${step === 3 ? " is-confirm" : ""}`}>
          {step === 1 && (
        <div className="pd__page" data-testid="pd-page">
          <p className="pd__q">Which Safari tab should WebWatcher look at?</p>
          <div className="pd__tab">
            <span className="pd__tab-ico"><Bell size={16} aria-hidden /></span>
            <span><strong>Rive Community — Feed</strong><code>community.rive.app/feed</code></span>
            <span className="pd__tab-state">open in Safari</span>
          </div>
          <button type="button" className="pd__btn pd__btn--primary" data-testid="pd-scan" onClick={runScan} disabled={scanning}>
            <ScanSearch size={16} aria-hidden /> {scanning ? "Scanning the page…" : "Scan page"}
          </button>
          <p className="pd__hint">Scan page reads the tab through Apple Events and lists what looks watchable.</p>
        </div>
      )}

          {step === 2 && (
            <div className="pd__list" data-testid="pd-list">
              <p className="pd__q">
                {picking ? "Pointing at the page. Move the mouse over it, or use the arrow keys." : "Showing a count? Pick one of these, or Pick in Safari to point at it yourself."}
              </p>
              <div role="radiogroup" aria-label="Candidate elements" className={picking ? "is-dim" : undefined}>
                {CANDIDATES.map((c, i) => (
                  <button
                    key={c.id}
                    ref={(el) => { radios.current[i] = el; }}
                    type="button"
                    role="radio"
                    data-testid={`pd-cand-${c.id}`}
                    aria-checked={sel === c.id && !picking}
                    tabIndex={sel === c.id || (i === 0 && !CANDIDATES.some((x) => x.id === sel)) ? 0 : -1}
                    disabled={picking}
                    className={`pd__row${sel === c.id && !picking ? " is-on" : ""}`}
                    onClick={() => setSel(c.id)}
                    onKeyDown={(e) => onRadioKey(e, i)}
                  >
                    <span className="pd__radio" aria-hidden />
                    <span className="pd__rt"><strong>{c.title}</strong><code>{NODES[c.id].selector}</code></span>
                    <span className="pd__chip">{c.chip}</span>
                    {c.best && <span className="pd__chip pd__chip--best">best match</span>}
                  </button>
                ))}
              </div>
              <div className="pd__actions">
                {!picking ? (
                  <button type="button" className="pd__link" data-testid="pd-pick" onClick={startPicking}>
                    <MousePointer2 size={15} aria-hidden /> Pick in Safari instead
                  </button>
                ) : (
                  <button type="button" className="pd__link" data-testid="pd-cancel" onClick={stopPicking}>
                    <X size={15} aria-hidden /> Back to the list
                  </button>
                )}
              </div>
            </div>
          )}

          {step === 3 && done && (
            <div className="pd__confirm" data-testid="pd-confirm">
              <p className="pd__q">Check what WebWatcher just read from the page.</p>
              <dl className="pd__read">
                <dt>Live read</dt>
                <dd data-testid="pd-live" aria-live="polite">
                  {reading ? <span className="pd__reading">Reading the page…</span> : <b>{done.value}</b>}
                </dd>
                <dt>Watching</dt><dd>{done.strategy} · {done.label}</dd>
                <dt>Selector</dt><dd><code>{done.selector}</code></dd>
                <dt>Checks every</dt><dd>2 minutes</dd>
              </dl>
              <div className="pd__actions">
                <button type="button" className="pd__btn pd__btn--primary" data-testid="pd-add" disabled={reading || added} onClick={() => setAdded(true)}>
                  <Check size={16} aria-hidden /> {added ? "Watcher added" : "Add watcher"}
                </button>
                <button type="button" className="pd__link" data-testid="pd-back" onClick={() => goStep(2)}>Back to the elements</button>
                {added && (
                  <button type="button" className="pd__link" data-testid="pd-restart" onClick={() => { setAdded(false); setChosen(null); setScanned(false); setPicking(false); setSel("badge"); setStep(1); }}>Start over</button>
                )}
              </div>
            </div>
          )}

          <div className="pd__stage">
            {step === 2 && picking && (
              <div className="pd__toolbar" aria-hidden>
                <span className="pd__key"><ArrowUp size={12} /> parent</span>
                <span className="pd__key"><ArrowDown size={12} /> child</span>
                <span className="pd__key"><ArrowLeft size={12} /><ArrowRight size={12} /> siblings</span>
                <span className="pd__key"><CornerDownLeft size={12} /> confirm</span>
                <span className="pd__key"><X size={12} /> esc</span>
              </div>
            )}
            {step === 3 ? (
              <PopoverMock done={done} reading={reading} added={added} />
            ) : (
              <Sketch
                innerRef={sketchRef}
                picking={picking}
                rect={step === 1 ? null : rect}
                lit={step === 1 ? null : lit}
                scanning={scanning}
                onKeyDown={onSketchKey}
                onMove={(t) => { if (picking) setHover(nodeAt(t)); }}
                onLeave={() => setHover(null)}
                onClick={(t) => { if (picking) { const id = nodeAt(t); if (id) { setSel(id); setHover(null); } } }}
              />
            )}
          </div>

          {step === 2 && (
            <div className="pd__panel" data-testid="pd-panel" aria-live="polite">
              <h4>What you’ll watch</h4>
              <dl>
                <dt>Strategy</dt><dd data-testid="pd-strategy">{target.strategy}</dd>
                <dt>Current value</dt><dd data-testid="pd-value"><b>{target.value}</b></dd>
                <dt>Selector</dt><dd data-testid="pd-selector"><code>{target.selector}</code></dd>
              </dl>
              <button type="button" className="pd__btn pd__btn--primary" data-testid="pd-use" onClick={() => confirmElement(picking ? lit : sel)}>
                {picking ? <><CornerDownLeft size={16} aria-hidden /> Confirm this element</> : "Use this element"}
              </button>
            </div>
          )}
        </div>
      )}
    </div>
  );
}

function Sketch({
  innerRef, picking, rect, lit, scanning, onKeyDown, onMove, onLeave, onClick,
}: {
  innerRef: React.RefObject<HTMLDivElement | null>;
  picking: boolean;
  rect: Rect | null;
  lit: NodeId | null;
  scanning: boolean;
  onKeyDown: (e: React.KeyboardEvent) => void;
  onMove: (t: EventTarget | null) => void;
  onLeave: () => void;
  onClick: (t: EventTarget | null) => void;
}) {
  const on = (id: NodeId) => (lit === id ? " is-lit" : "");
  const litNode = lit ? NODES[lit] : null;
  return (
    <div
      ref={innerRef}
      className={`sk${picking ? " is-picking" : ""}${scanning ? " is-scanning" : ""}`}
      data-testid="pd-sketch"
      tabIndex={picking ? 0 : -1}
      role={picking ? "application" : "img"}
      aria-label={picking ? `Page picker. Outlined: ${litNode?.selector}. Arrow keys walk the page, Enter confirms, Escape cancels.` : "Sketch of the Rive Community feed page with the matching element outlined"}
      onKeyDown={onKeyDown}
      onMouseDown={(e) => { if (picking) { e.preventDefault(); e.currentTarget.focus(); } }}
      onMouseMove={(e) => onMove(e.target)}
      onMouseLeave={onLeave}
      onClick={(e) => onClick(e.target)}
    >
      <div className="sk__chrome" aria-hidden>
        <i /><i /><i />
        <span className={`sk__title${on("title")}`} data-node="title">(3) Feed — Rive</span>
      </div>
      <div className="sk__page">
        <header className="sk__topbar" data-node="topbar">
          <a className="sk__brand" data-node="brand">Rive Community</a>
          <a className="sk__inbox" data-node="inbox"><Inbox size={14} aria-hidden /> Inbox (12)</a>
          <div className="sk__bell" data-node="bell" aria-hidden>
            <Bell size={17} />
            <span className="sk__badge" data-node="badge">3</span>
          </div>
        </header>
        <main className="sk__main">
          <h5 aria-hidden>Latest in the community</h5>
          <ul className="sk__feed" data-node="feed">
            <li data-node="item1"><i />Ana: Bones in nested artboards?</li>
            <li data-node="item2"><i />Kofi: Data binding lists</li>
            <li data-node="item3"><i />Mei: Luau pointer events</li>
            <li className="sk__more" aria-hidden>… 45 more</li>
          </ul>
        </main>
      </div>
      {rect && lit && (
        <span
          className="sk__outline"
          data-testid="pd-outline"
          data-lit={lit}
          style={{ left: rect.left - 3, top: rect.top - 3, width: rect.width + 6, height: rect.height + 6 }}
          aria-hidden
        >
          {picking && <em>{NODES[lit].selector}</em>}
        </span>
      )}
    </div>
  );
}

function PopoverMock({ done, reading, added }: { done: (typeof NODES)[NodeId] | null; reading: boolean; added: boolean }) {
  return (
    <div className="pm" data-testid="pd-popover" aria-label="The watcher as it appears in the menu bar popover">
      <div className="pm__head"><strong>Web Watcher</strong><span className="pm__dot" /></div>
      <div className="pm__row"><i className="pm__tog is-on" /><span><strong>Contra Message</strong><small>Nothing new</small></span></div>
      <div className="pm__row"><i className="pm__tog is-on" /><span><strong>GitHub release</strong><small>Nothing new</small></span></div>
      <div className={`pm__row pm__row--new${added ? " is-added" : ""}`} data-testid="pd-newrow">
        <i className={`pm__tog${added ? " is-on" : ""}`} />
        <span>
          <strong>Rive Community · {done?.label.toLowerCase()}</strong>
          <small>{added ? `Watching · ${reading ? "…" : done?.value}` : "Not saved yet · preview"}</small>
        </span>
      </div>
      <div className="pm__foot">
        { }
        <img src={asset("/images/webwatcher-icon.png")} alt="" width={16} height={16} /> Add Watcher
      </div>
    </div>
  );
}
