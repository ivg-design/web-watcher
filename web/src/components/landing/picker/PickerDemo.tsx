"use client";

import { useCallback, useEffect, useLayoutEffect, useRef, useState } from "react";
import { Bell, Check, ChevronLeft, ChevronRight, Eye, Inbox, Lock, MessageCircle } from "lucide-react";
import { asset } from "@/lib/config";
import { useWatch } from "@/components/watch/WatchContext";
import { CANDIDATES, GROUPS, NODES, siblings, type NodeId } from "./data";
import "@/styles/picker.css";

type Step = 1 | 2 | 3;
type Rect = { left: number; top: number; width: number; height: number; vw: number };

const DESIGN_W = 520; // the page is laid out at this width and scaled down below it
const DESIGN_H = 360;
const TOOLBAR_TEXT = "\u2190 \u2192 siblings \u00b7 \u2191 parent \u00b7 \u2193 child \u00b7 \u23ce use \u00b7 \u238b cancel";

const TOPICS = [
  { node: "item1" as const, who: "Ana", initial: "A", hue: "#7c5cff", title: "Bones in nested artboards?", cat: "Help", replies: 14 },
  { node: "item2" as const, who: "Kofi", initial: "K", hue: "#e8743b", title: "Data binding lists", cat: "Data binding", replies: 9 },
  { node: "item3" as const, who: "Mei", initial: "M", hue: "#1fa37a", title: "Luau pointer events", cat: "Scripting", replies: 31 },
];

export default function PickerDemo() {
  const { record } = useWatch();
  const [step, setStep] = useState<Step>(1);
  const [scanned, setScanned] = useState(false);
  const [scanning, setScanning] = useState(false);
  const [sel, setSel] = useState<NodeId>("badge");
  const [chosen, setChosen] = useState<NodeId | null>(null);
  const [picking, setPicking] = useState(false);
  const [hover, setHover] = useState<NodeId | null>(null);
  const [selecting, setSelecting] = useState(false);
  const [reading, setReading] = useState(false);
  const [added, setAdded] = useState(false);
  const [rect, setRect] = useState<Rect | null>(null);
  const [scale, setScale] = useState(1);

  const swRef = useRef<HTMLDivElement>(null);
  const viewRef = useRef<HTMLDivElement>(null);
  const radios = useRef<(HTMLButtonElement | null)[]>([]);
  const timers = useRef<number[]>([]);
  useEffect(() => { const t = timers.current; return () => t.forEach(window.clearTimeout); }, []);
  const later = (fn: () => void, ms: number) => { timers.current.push(window.setTimeout(fn, ms)); };

  // While picking the outline follows hover (mouse) or the keyboard cursor; otherwise the selected candidate.
  const lit: NodeId = picking ? (hover ?? sel) : step === 3 && chosen ? chosen : sel;
  const showOutline = step !== 1 && !scanning;

  const measure = useCallback(() => {
    const root = swRef.current;
    const el = root?.querySelector<HTMLElement>(`[data-node="${lit}"]`);
    if (!root || !el) { setRect(null); return; }
    const a = root.getBoundingClientRect();
    const b = el.getBoundingClientRect();
    setRect({ left: b.left - a.left, top: b.top - a.top, width: b.width, height: b.height, vw: a.width });
  }, [lit]);
  useLayoutEffect(() => { measure(); }, [measure, step, scale]);

  useEffect(() => {
    const view = viewRef.current;
    if (!view || typeof ResizeObserver === "undefined") return;
    const fit = () => setScale(Math.min(1, view.clientWidth / DESIGN_W) || 1);
    fit();
    const ro = new ResizeObserver(() => { fit(); measure(); });
    ro.observe(view);
    return () => ro.disconnect();
  }, [measure]);

  const runScan = () => {
    setScanning(true);
    setPicking(false);
    later(() => { setScanning(false); setScanned(true); setStep(2); }, 650);
  };

  const confirmElement = (id: NodeId) => {
    setChosen(id);
    setSel(id);
    setPicking(false);
    setHover(null);
    setSelecting(false);
    setAdded(false);
    setReading(true);
    setStep(3);
    later(() => setReading(false), 700);
  };

  // In pick mode the outline turns green (the real "selected" state) for 300 ms before confirming.
  const commitFromPage = (id: NodeId) => {
    if (selecting) return;
    setSel(id);
    setHover(null);
    setSelecting(true);
    later(() => confirmElement(id), 300);
  };

  const goStep = (s: Step) => {
    if (selecting) return;
    if (s === 1) { setStep(1); setPicking(false); }
    else if (s === 2 && scanned) { setStep(2); setPicking(false); }
    else if (s === 3 && chosen) { setStep(3); setPicking(false); }
  };

  const startPicking = () => {
    setPicking(true);
    setHover(null);
    if (sel === "title") setSel("badge");
    later(() => swRef.current?.focus({ preventScroll: true }), 30);
  };
  const stopPicking = () => {
    if (selecting) return;
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
  }, [picking, selecting]);

  const moveCursor = (to: NodeId | null | undefined) => { if (to) { setSel(to); setHover(null); } };
  const onSketchKey = (e: React.KeyboardEvent) => {
    if (!picking || selecting || e.target !== e.currentTarget) return;
    const node = NODES[sel];
    const sibs = siblings(sel);
    const idx = sibs.indexOf(sel);
    switch (e.key) {
      case "ArrowUp": e.preventDefault(); moveCursor(node.parent); break;
      case "ArrowDown": e.preventDefault(); moveCursor(node.children[0]); break;
      case "ArrowRight": e.preventDefault(); moveCursor(sibs[idx + 1]); break;
      case "ArrowLeft": e.preventDefault(); moveCursor(sibs[idx - 1]); break;
      case "Enter": e.preventDefault(); commitFromPage(sel); break;
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
    radios.current[k]?.focus({ preventScroll: true });
  };

  const addWatcher = () => {
    if (added || reading || !chosen) return;
    const d = NODES[chosen];
    setAdded(true);
    record({
      source: "picker",
      name: "Rive Community · " + d.label,
      title: "Watcher added",
      body: `${d.strategy} · ${d.selector}`,
      value: d.value,
    });
  };

  const target = NODES[picking ? lit : sel];
  const done = chosen ? NODES[chosen] : null;
  const state = selecting || (step === 3 && !picking) ? "selected" : "hover";

  return (
    <div className="pd" data-testid="pd" data-step={step} data-picking={picking ? "1" : "0"}>
      {/* RIGHT on desktop, first on mobile: the Safari window */}
      <div className="pd__safari">
        <div
          ref={swRef}
          className={`sw${picking ? " is-picking" : ""}${scanning ? " is-scanning" : ""}`}
          data-testid="pd-sketch"
          tabIndex={picking ? 0 : -1}
          role={picking ? "application" : "img"}
          aria-label={picking ? `Page picker. Outlined: ${NODES[lit].selector}. Arrow keys walk the page, Enter confirms, Escape cancels.` : "Safari showing the Rive Community feed with the matching element outlined"}
          onKeyDown={onSketchKey}
          onMouseDown={(e) => { if (picking && e.target === e.currentTarget) { e.preventDefault(); e.currentTarget.focus({ preventScroll: true }); } }}
          onMouseMove={(e) => { if (picking && !selecting) setHover(nodeAt(e.target)); }}
          onMouseLeave={() => setHover(null)}
          onClick={(e) => { if (picking && !selecting) { const id = nodeAt(e.target); if (id) { setSel(id); setHover(null); swRef.current?.focus({ preventScroll: true }); } } }}
        >
          <div className="sw__chrome" aria-hidden>
            <div className="sw__bar">
              <span className="sw__lights"><i /><i /><i /></span>
              <span className="sw__nav"><ChevronLeft size={14} /><ChevronRight size={14} /></span>
              <span className="sw__url"><Lock size={10} />community.rive.app/feed</span>
            </div>
            <div className="sw__tabs">
              <span className="sw__tab" data-node="title">
                <span className="sw__fav" />
                (3) Feed — Rive
              </span>
            </div>
          </div>

          <div className="sw__view" ref={viewRef} style={{ height: DESIGN_H * scale }}>
            <div className="sw__page" style={{ width: `${100 / scale}%`, height: DESIGN_H, transform: `scale(${scale})` }} aria-hidden>
              <header className="rc-top" data-node="topbar">
                <a className="rc-brand" data-node="brand">Rive Community</a>
                <a className="rc-inbox" data-node="inbox">Inbox (12)</a>
                <div className="rc-bell" data-node="bell">
                  <Bell size={18} />
                  <span className="rc-badge" data-node="badge">3</span>
                </div>
              </header>
              <main className="rc-main">
                <h5>Latest topics</h5>
                <ul className="rc-feed" data-node="feed">
                  {TOPICS.map((t) => (
                    <li key={t.node} data-node={t.node}>
                      <span className="rc-av" style={{ background: t.hue }}>{t.initial}</span>
                      <span className="rc-t"><b>{t.who}: {t.title}</b><em>{t.cat}</em></span>
                      <span className="rc-r"><MessageCircle size={13} />{t.replies}</span>
                    </li>
                  ))}
                  <li className="rc-more">… 45 more</li>
                </ul>
              </main>
            </div>
          </div>

          {scanning && <span className="sw__sweep" aria-hidden />}

          {showOutline && rect && (
            <>
              <span
                className="sw__outline"
                data-testid="pd-outline"
                data-lit={lit}
                data-state={state}
                style={{ transform: `translate(${rect.left}px, ${rect.top}px)`, width: rect.width, height: rect.height }}
                aria-hidden
              />
              {picking && !selecting && (
                <span
                  className="sw__tip"
                  data-testid="pd-tip"
                  style={{
                    transform: `translate(${Math.max(4, Math.min(rect.left, rect.vw - 260))}px, ${rect.top < 34 ? rect.top + rect.height + 6 : rect.top - 28}px)`,
                  }}
                  aria-hidden
                >
                  {NODES[lit].selector}
                </span>
              )}
            </>
          )}

          {picking && (
            <div className="sw__toolbar" data-testid="pd-toolbar">
              <span data-testid="pd-tb-text">{TOOLBAR_TEXT}</span>
              <button type="button" data-testid="pd-tb-use" className="sw__tb-use" onClick={(e) => { e.stopPropagation(); commitFromPage(lit); }}>Use this element</button>
              <button type="button" data-testid="pd-tb-cancel" className="sw__tb-cancel" onClick={(e) => { e.stopPropagation(); stopPicking(); }}>Cancel</button>
            </div>
          )}
        </div>
      </div>

      {/* LEFT on desktop: the Add Watcher sheet */}
      <div className="pd__sheet">
        <div className="sh__title" aria-hidden><span className="sh__lights"><i /><i /><i /></span><span>Add Watcher</span></div>
        <div className="sh__seg" aria-hidden><span className="is-on">Web page</span><span>Gmail sender</span></div>
        <div className="sh__body">
          <p className="sh__label">Which element?</p>
          <ol className="pd__steps" aria-label="Add Watcher steps">
            {([["1", "Page"], ["2", "Element"], ["3", "Confirm"]] as const).map(([k, label]) => {
              const s = Number(k) as Step;
              const enabled = s === 1 || (s === 2 && scanned) || (s === 3 && !!chosen);
              const doneStep = (s === 1 && scanned) || (s === 2 && !!chosen);
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
                    <span className={`pd__dot${doneStep ? " is-done" : ""}`} aria-hidden>{doneStep && <Check size={10} strokeWidth={3.5} />}</span>
                    {k} · {label}
                  </button>
                  {step === s && s === 1 && (
                    <div className="sh__box" data-testid="pd-page">
                      <div className="sh__field"><Lock size={12} aria-hidden /><code>community.rive.app/feed</code></div>
                      <p className="sh__found"><Check size={13} aria-hidden /> Found in Safari: Feed | Rive Community</p>
                      <div className="sh__btns">
                        <button type="button" className="sh__btn sh__btn--primary" data-testid="pd-scan" onClick={runScan} disabled={scanning}>
                          {scanning ? "Scanning the page…" : "Scan page"}
                        </button>
                      </div>
                      <p className="sh__hint">Scan page reads the tab through Apple Events and lists what looks watchable.</p>
                    </div>
                  )}
                  {step === s && s === 2 && (
                    <div className="sh__box" data-testid="pd-list">
                      <div className="sh__btns">
                        {!picking ? (
                          <button type="button" className="sh__btn" data-testid="pd-pick" onClick={startPicking}>Pick in Safari</button>
                        ) : (
                          <button type="button" className="sh__btn" data-testid="pd-cancel" onClick={stopPicking}>Back to the list</button>
                        )}
                        <button type="button" className="sh__btn" data-testid="pd-rescan" onClick={runScan} disabled={picking || scanning}>Rescan</button>
                      </div>
                      {picking && <p className="sh__hint" role="status">Pointing at the page. Move the mouse over it, or use the arrow keys.</p>}
                      {scanning ? (
                        <p className="sh__hint" role="status">Scanning the page…</p>
                      ) : (
                        <div role="radiogroup" aria-label="Candidate elements" className={`sh__groups${picking ? " is-dim" : ""}`}>
                          {GROUPS.map((g) => {
                            const items = CANDIDATES.map((c, i) => ({ c, i })).filter(({ c }) => c.group === g.id);
                            if (!items.length) return null;
                            return (
                              <div key={g.id} className="sh__group">
                                <p className="sh__gt">{g.title}</p>
                                {items.map(({ c, i }) => (
                                  <div key={c.id} className={`pd__row${sel === c.id && !picking ? " is-on" : ""}`} style={{ "--i": i } as React.CSSProperties}>
                                    <button
                                      ref={(el) => { radios.current[i] = el; }}
                                      type="button"
                                      role="radio"
                                      data-testid={`pd-cand-${c.id}`}
                                      aria-checked={sel === c.id && !picking}
                                      tabIndex={sel === c.id || (i === 0 && !CANDIDATES.some((x) => x.id === sel)) ? 0 : -1}
                                      disabled={picking}
                                      className="pd__rmain"
                                      onClick={() => setSel(c.id)}
                                      onKeyDown={(e) => onRadioKey(e, i)}
                                    >
                                      <code className="pd__chip">{c.chip}</code>
                                      <span className="pd__rt">
                                        <strong>{c.title}{c.best && <span className="pd__best">best match</span>}</strong>
                                        <small>{c.detail}</small>
                                      </span>
                                    </button>
                                    <Eye size={15} className="pd__eye" aria-hidden />
                                    <button type="button" className="pd__use" data-testid={`pd-cand-use-${c.id}`} disabled={picking} onClick={() => confirmElement(c.id)}>Use</button>
                                  </div>
                                ))}
                              </div>
                            );
                          })}
                        </div>
                      )}
                      <div className="pd__panel" data-testid="pd-panel" aria-live="polite">
                        <dl>
                          <dt>Strategy</dt><dd data-testid="pd-strategy">{target.strategy}</dd>
                          <dt>Current value</dt><dd data-testid="pd-value"><b>{target.value}</b></dd>
                          <dt>Selector</dt><dd data-testid="pd-selector"><code>{target.selector}</code></dd>
                        </dl>
                        <button type="button" className="sh__btn sh__btn--primary" data-testid="pd-use" onClick={() => (picking ? commitFromPage(lit) : confirmElement(sel))}>
                          {picking ? "Confirm this element" : "Use this element"}
                        </button>
                      </div>
                    </div>
                  )}
                  {step === s && s === 3 && done && (
                    <div className="sh__box" data-testid="pd-confirm">
                      <dl className="pd__read">
                        <dt>Live read</dt>
                        <dd data-testid="pd-live" aria-live="polite">
                          {reading ? <span className="pd__reading">Reading the page…</span> : <b>{done.value}</b>}
                        </dd>
                        <dt>Watching</dt><dd>{done.strategy} · {done.label}</dd>
                        <dt>Selector</dt><dd><code>{done.selector}</code></dd>
                        <dt>Check interval</dt><dd>2 minutes</dd>
                      </dl>
                      <div className="sh__btns">
                        <button type="button" className="sh__btn sh__btn--primary" data-testid="pd-add" disabled={reading || added} onClick={addWatcher}>
                          <Check size={14} aria-hidden /> {added ? "Watcher added" : "Add watcher"}
                        </button>
                        <button type="button" className="sh__btn" data-testid="pd-back" onClick={() => goStep(2)}>Change element</button>
                        {added && (
                          <button type="button" className="sh__btn" data-testid="pd-restart" onClick={() => { setAdded(false); setChosen(null); setScanned(false); setPicking(false); setSel("badge"); setStep(1); }}>Start over</button>
                        )}
                      </div>
                    </div>
                  )}
                </li>
              );
            })}
          </ol>
        </div>
      </div>

      {step === 3 && <PopoverMock done={done} reading={reading} added={added} />}
    </div>
  );
}

function PopoverMock({ done, reading, added }: { done: (typeof NODES)[NodeId] | null; reading: boolean; added: boolean }) {
  return (
    <div className="pm" data-testid="pd-popover" aria-label="The watcher as it appears in the menu bar popover">
      <div className="pm__head"><strong>Web Watcher</strong><small>v1.10.9 (34)</small><span className="pm__dot" /></div>
      <div className="pm__row"><i className="pm__tog is-on" /><span><strong>iPhone 17 Pro price</strong><small>Last: $1,199.00</small></span></div>
      <div className="pm__row"><i className="pm__tog is-on" /><span><strong>WebWatcher releases</strong><small>Last: v1.7.0</small></span></div>
      <div className={`pm__row pm__row--new${added ? " is-added" : ""}`} data-testid="pd-newrow">
        <i className={`pm__tog${added ? " is-on" : ""}`} />
        <span>
          <strong>Rive Community · {done?.label}</strong>
          <small>{added ? `Watching · Last: ${reading ? "…" : done?.value}` : "Not saved yet · preview"}</small>
        </span>
      </div>
      <div className="pm__sec"><Inbox size={12} aria-hidden /> Email</div>
      <div className="pm__row"><i className="pm__tog is-on" /><span><strong>Acme invoices</strong><small>3 unread · latest Today 22:45</small></span><b className="pm__pill">3</b></div>
      <div className="pm__act">
        { }
        <img src={asset("/images/webwatcher-icon.png")} alt="" width={16} height={16} /> Add Watcher
      </div>
      <div className="pm__act">Check All Now</div>
      <div className="pm__last">Last check: 45 seconds ago</div>
    </div>
  );
}
