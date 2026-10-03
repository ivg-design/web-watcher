"use client";

/** The app's own popover, listing what the page watcher has seen. Anchored under the mark; a bottom sheet on mobile. */
import { useEffect, useRef, useState } from "react";
import { createPortal } from "react-dom";
import { AnimatePresence, motion, useReducedMotion } from "framer-motion";
import { Info, Mail, Plus, Power, RefreshCw, Settings } from "lucide-react";
import type { WatchChange } from "./WatchContext";
import { asset } from "@/lib/config";
import { CHECK_EVENT, WINK_EVENT } from "./events";
import { relTime } from "./relTime";
import "@/styles/watch.css";

export interface Anchor { top: number; right: number; sheet: boolean }
interface Props {
  anchor: Anchor | null;
  changes: WatchChange[];
  lastCheck: number;
  onClose: (refocus?: boolean) => void;
  triggerRef: React.RefObject<HTMLButtonElement | null>;
}

const EASE = [0.22, 1, 0.36, 1] as const;

function Row({ c, now }: { c: WatchChange; now: number }) {
  const gmail = c.source === "gmail";
  const line = c.value ? `Last: ${c.value}` : c.title;
  return (
    <li className="ww-pop__row" data-testid="watch-row">
      <span className="ww-pop__toggle" aria-hidden><i /></span>
      <span className="ww-pop__txt">
        <b>{c.name}</b>
        <small>{line} · {relTime(c.at, now)}</small>
      </span>
      {gmail && <span className="ww-pop__count">{c.value && /^\d+$/.test(c.value) ? c.value : 1}</span>}
    </li>
  );
}

export default function WatchPopover({ anchor, changes, lastCheck, onClose, triggerRef }: Props) {
  const panel = useRef<HTMLDivElement>(null);
  const reduce = useReducedMotion();
  const [now, setNow] = useState(() => Date.now());
  const open = !!anchor;

  useEffect(() => {
    if (!open) return;
    panel.current?.focus({ preventScroll: true });
    const t0 = window.setTimeout(() => setNow(Date.now()), 0);
    const iv = window.setInterval(() => setNow(Date.now()), 5000);
    const onKey = (e: KeyboardEvent) => { if (e.key === "Escape") { e.preventDefault(); onClose(); } };
    const onDown = (e: PointerEvent) => {
      const t = e.target as Node;
      if (panel.current?.contains(t) || triggerRef.current?.contains(t)) return;
      onClose();
    };
    document.addEventListener("keydown", onKey);
    document.addEventListener("pointerdown", onDown);
    return () => { window.clearTimeout(t0); window.clearInterval(iv); document.removeEventListener("keydown", onKey); document.removeEventListener("pointerdown", onDown); };
  }, [open, onClose, triggerRef]);

  if (typeof document === "undefined") return null;
  const rows = changes.slice(0, 6);
  const plain = rows.filter((c) => c.source !== "gmail");
  const mail = rows.filter((c) => c.source === "gmail");
  const sheet = anchor?.sheet ?? false;
  
  const ago = Math.max(1, Math.round((now - lastCheck) / 1000));

  return createPortal(
    <AnimatePresence>
      {anchor && (
        <motion.div
          key="pop"
          ref={panel}
          tabIndex={-1}
          role="dialog"
          aria-label="WebWatcher popover"
          data-testid="watch-popover"
          className={`ww-pop${sheet ? " ww-pop--sheet" : ""}`}
          style={sheet ? undefined : { top: anchor.top, right: anchor.right }}
          initial={reduce ? { opacity: 0 } : { opacity: 0, y: sheet ? 48 : -8 }}
          animate={{ opacity: 1, y: 0, transition: { duration: 0.24, ease: EASE } }}
          exit={{ opacity: 0, y: reduce ? 0 : sheet ? 36 : -6, transition: { duration: 0.18, ease: EASE } }}
        >
          <div className="ww-pop__head">
            <b>Web Watcher</b><span>v1.10.9 (34)</span>
            <Info size={14} aria-hidden className="ww-pop__info" />
            <i className="ww-pop__dot" aria-hidden />
          </div>
          <hr />
          {rows.length === 0 ? (
            <p className="ww-pop__empty" data-testid="watch-empty">Nothing watched yet — try the demos below</p>
          ) : (
            <>
              <ul>{plain.map((c) => <Row key={c.id} c={c} now={now} />)}</ul>
              {mail.length > 0 && (
                <>
                  {plain.length > 0 && <hr />}
                  <p className="ww-pop__sect"><Mail size={14} aria-hidden /> Email</p>
                  <ul>{mail.map((c) => <Row key={c.id} c={c} now={now} />)}</ul>
                </>
              )}
            </>
          )}
          <hr />
          <a
            className="ww-pop__item"
            data-testid="watch-add"
            href={`${asset("/")}#picker`}
            onClick={(e) => {
              const el = document.getElementById("picker");
              if (!el) { onClose(false); return; }
              e.preventDefault();
              el.scrollIntoView({ behavior: reduce ? "auto" : "smooth", block: "start" });
              history.replaceState(null, "", "#picker");
              onClose(false);
            }}
          ><Plus size={16} aria-hidden /> Add Watcher</a>
          <button type="button" className="ww-pop__item" data-testid="watch-check" onClick={() => window.dispatchEvent(new Event(CHECK_EVENT))}>
            <RefreshCw size={16} aria-hidden /> Check All Now
          </button>
          <p className="ww-pop__last">Last check: {ago} second{ago === 1 ? "" : "s"} ago</p>
          <hr />
          <a className="ww-pop__item" data-testid="watch-settings" href={asset("/docs/settings")} onClick={() => onClose(false)}><Settings size={16} aria-hidden /> Settings…</a>
          <button type="button" className="ww-pop__item" data-testid="watch-quit" onClick={() => { onClose(); window.dispatchEvent(new Event(WINK_EVENT)); }}><Power size={16} aria-hidden /> Quit</button>
        </motion.div>
      )}
    </AnimatePresence>,
    document.body,
  );
}
