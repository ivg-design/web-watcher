"use client";

import { useEffect, useRef, useState } from "react";
import { asset } from "@/lib/config";

type Item = { id: number; text: string; read: boolean };
const INITIAL = ["Scripting update", "Office hours", "Release notes"]; // newest first
const FRESH = [
  "Beta invite: Rive 0.9",
  "Community call tomorrow",
  "New tutorial: state machines",
  "Changelog: data binding",
  "Reminder: office hours",
];
const MAX_VISIBLE = 4;
const seed = (): Item[] => INITIAL.map((text, id) => ({ id, text, read: false }));

type Gone = null | "archived" | "trashed";

/** Grouped notification whose buttons do what the app does, inside the mock. */
export default function GmailCard() {
  const [items, setItems] = useState<Item[]>(seed);
  const [gone, setGone] = useState<Gone>(null);
  const [leaving, setLeaving] = useState<Gone>(null);
  const [toast, setToast] = useState(false);
  const [fresh, setFresh] = useState(0);
  const timers = useRef<number[]>([]);
  const nextId = useRef(100);
  useEffect(() => () => timers.current.forEach(window.clearTimeout), []);
  const later = (fn: () => void, ms: number) => {
    const id = window.setTimeout(fn, ms);
    timers.current.push(id);
    return id;
  };

  const unread = items.filter((i) => !i.read).length;
  const label = unread === 0 ? "All read — Rive team" : `${unread} new from Rive team`;
  const shown = items.slice(0, MAX_VISIBLE);
  const more = items.length - shown.length;

  const markRead = () =>
    setItems((cur) => {
      const idx = cur.findIndex((i) => !i.read);
      return idx < 0 ? cur : cur.map((it, k) => (k === idx ? { ...it, read: true } : it));
    });
  const dismiss = (kind: "archived" | "trashed") => {
    setLeaving(kind);
    later(() => {
      setGone(kind);
      setLeaving(null);
    }, 280);
  };
  const restore = () => {
    setItems(seed());
    setGone(null);
    setLeaving(null);
    setFresh(0);
  };
  const open = () => {
    setToast(true);
    later(() => setToast(false), 2500);
  };
  const newMail = () => {
    const text = FRESH[fresh % FRESH.length];
    setFresh((n) => n + 1);
    setGone(null);
    setLeaving(null);
    setItems((cur) => [{ id: nextId.current++, text, read: false }, ...cur]);
  };

  return (
    <div className="gm">
      {gone ? (
        <p className="gm__undo" role="status">
          {gone === "archived" ? "Notification archived" : "Moved to Trash"} ·{" "}
          <button type="button" className="gm__link" data-testid="gm-restore" onClick={restore}>Restore</button>
        </p>
      ) : (
        <>
          <div className={`gwrap${leaving ? " is-leaving" : ""}`}>
            <div className="gwrap__in">
              <div className="gnotif" data-testid="gm-notif" role="group" aria-label="Example grouped notification">
                <img src={asset("/images/webwatcher-icon.png")} alt="" width={36} height={36} />
                <div className="gnotif__t">
                  <strong aria-live="polite">{label}</strong>
                  <span className="subjects" data-testid="gm-subjects">
                    {shown.map((s, i) => (
                      <span key={s.id}>
                        {i > 0 ? <span aria-hidden="true">{"· "}</span> : null}
                        <span className={`subj${s.read ? " is-read" : ""}`}>{s.text}</span>
                        {i < shown.length - 1 ? " " : ""}
                      </span>
                    ))}
                    {more > 0 ? <span className="subj__more"> +{more} more</span> : null}
                  </span>
                  <span>received Today 8:14 PM</span>
                </div>
                <span className="count roll" data-testid="gm-count" aria-label={`${unread} unread`} hidden={unread === 0}>
                  <span key={unread} className="roll__d">{unread}</span>
                </span>
              </div>
            </div>
          </div>
          <div className="pillrow">
            <button type="button" className="pill" data-testid="gm-open" onClick={open}>Open</button>
            <button type="button" className="pill" data-testid="gm-markread" disabled={unread === 0} onClick={markRead}>Mark as Read</button>
            <button type="button" className="pill" data-testid="gm-archive" onClick={() => dismiss("archived")}>Archive</button>
            <button type="button" className="pill" data-testid="gm-delete" onClick={() => dismiss("trashed")}>Delete</button>
          </div>
        </>
      )}
      <div className="gm__toast" role="status">
        {toast ? <span data-testid="gm-toast">Opens the email in Gmail</span> : null}
      </div>
      <div className="pillrow">
        <button type="button" className="pill pill--sim" data-testid="gm-newmail" onClick={newMail}>
          Simulate new mail from Rive team
        </button>
      </div>
    </div>
  );
}
