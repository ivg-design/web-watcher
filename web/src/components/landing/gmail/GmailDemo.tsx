"use client";

import { useEffect, useRef, useState } from "react";
import { asset } from "@/lib/config";
import { useWatch } from "@/components/watch/WatchContext";
import Roll from "@/components/landing/hero/Roll";
import "@/styles/gmail.css";

type Mail = {
  id: number;
  rive: boolean;
  sender: string;
  subject: string;
  snippet: string;
  time: string;
  unread: boolean;
  fx?: "in" | "out" | "struck";
};
type Notif = "shown" | "dismissed";
type Undo = { kind: "archived" | "trashed" | "spam"; rows: Mail[] };

const SEED: Mail[] = [
  { id: 2, rive: false, sender: "Linear", subject: "Your weekly digest", snippet: "12 issues closed, 4 new in Backlog", time: "Mon", unread: false },
  { id: 1, rive: false, sender: "Figma", subject: "Dev Mode is now generally available", snippet: "Inspect, copy and ship straight from your files", time: "Sep 28", unread: false },
];
const RIVE: [string, string][] = [
  ["Scripting update", "Luau scripting lands in the editor with a new debugger"],
  ["Office hours", "Join the team Thursday for live Q&A on data binding"],
  ["Release notes", "Rive 0.9: layouts, feathering and faster state machines"],
  ["Beta invite: Rive 0.9", "You are in. Here is how to opt in to the beta"],
  ["Community call tomorrow", "Bring your files, we will review them live"],
];
const MAX_ROWS = 7;

const mkRive = (n: number, id: number): Mail => ({
  id,
  rive: true,
  sender: "Rive team",
  subject: RIVE[n % RIVE.length][0],
  snippet: RIVE[n % RIVE.length][1],
  time: "8:14 PM",
  unread: true,
  fx: "in",
});

export default function GmailDemo() {
  const { record } = useWatch();
  const recordRef = useRef(record);
  useEffect(() => {
    recordRef.current = record;
  }, [record]);

  const [mails, setMails] = useState<Mail[]>(SEED);
  const mailsRef = useRef<Mail[]>(SEED);
  const [notif, setNotif] = useState<Notif>("dismissed");
  const [undo, setUndo] = useState<Undo | null>(null);
  const [opened, setOpened] = useState<number | null>(null);
  const [cleared, setCleared] = useState(false);
  const stage = useRef<HTMLDivElement>(null);
  const started = useRef(false);
  const seq = useRef(0);
  const nextId = useRef(10);
  const timers = useRef<number[]>([]);
  const later = (fn: () => void, ms: number) => {
    timers.current.push(window.setTimeout(fn, ms));
  };
  const upd = (fn: (m: Mail[]) => Mail[]) => {
    mailsRef.current = fn(mailsRef.current);
    setMails(mailsRef.current);
  };
  const counted = (m: Mail[]) => m.filter((x) => x.rive && x.unread && x.fx !== "out");
  const reduced = () => typeof window !== "undefined" && window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  const deliver = () => {
    const mail = mkRive(seq.current++, nextId.current++);
    if (reduced()) mail.fx = undefined;
    upd((m) => [mail, ...m]);
    setNotif("shown");
    setUndo(null);
    setOpened(null);
    setCleared(false);
    const count = counted(mailsRef.current).length;
    recordRef.current({
      source: "gmail",
      name: "Gmail · @rive.app",
      title: `${count} new from Rive team`,
      body: mail.subject,
      value: String(count),
    });
  };

  useEffect(() => {
    const el = stage.current;
    if (!el) return;
    // Keyboard users reach the section before it is half in view: focus entering it starts the arrivals too.
    const begin = () => {
      if (started.current) return;
      started.current = true;
      io.disconnect();
      el.removeEventListener("focusin", begin);
      if (reduced()) {
        for (let i = 0; i < 3; i++) deliver();
      } else {
        for (let i = 0; i < 3; i++) later(deliver, 350 + i * 900);
      }
    };
    const io = new IntersectionObserver((es) => { if (es.some((e) => e.isIntersecting)) begin(); }, { threshold: 0.5 });
    io.observe(el);
    el.addEventListener("focusin", begin);
    const t = timers.current;
    return () => {
      io.disconnect();
      el.removeEventListener("focusin", begin);
      t.forEach(window.clearTimeout);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const list = counted(mails);
  const count = list.length;
  const subjects = list.slice(0, 3).map((m) => m.subject).join(" · ");
  const more = list.length - 3;

  // Real behaviour: the notification is removed once the unread count reaches 0, and says nothing else.
  const clearNotif = () => {
    setNotif("dismissed");
    setCleared(true);
    later(() => setCleared(false), 3200);
  };
  const markRead = () => {
    const ids = mailsRef.current.filter((x) => x.rive && x.unread).map((x) => x.id);
    if (!ids.length) return;
    if (reduced()) {
      upd((m) => m.map((x) => (x.rive ? { ...x, unread: false } : x)));
      clearNotif();
      return;
    }
    // 60 ms stagger: rows un-bold one by one, the count rolls down to 0, then the card folds away.
    ids.forEach((id, i) => later(() => upd((m) => m.map((x) => (x.id === id ? { ...x, unread: false } : x))), i * 60));
    later(clearNotif, ids.length * 60 + 220);
  };
  const remove = (kind: Undo["kind"]) => {
    const rows = mailsRef.current.filter((x) => x.rive && x.unread);
    if (!rows.length) return;
    const ids = new Set(rows.map((r) => r.id));
    const quick = reduced();
    upd((m) => m.map((x) => (ids.has(x.id) ? { ...x, fx: kind === "trashed" ? "struck" : "out" } : x)));
    setUndo({ kind, rows: rows.map((r) => ({ ...r, fx: undefined })) });
    clearNotif();
    setOpened(null);
    const finish = () => upd((m) => m.filter((x) => !ids.has(x.id)));
    if (quick) finish();
    else if (kind === "trashed") {
      later(() => upd((m) => m.map((x) => (ids.has(x.id) ? { ...x, fx: "out" } : x))), 260);
      later(finish, 560);
    } else later(finish, 300);
  };
  const open = () => {
    if (!list.length) return;
    const id = list[0].id;
    setOpened(id);
    upd((m) => m.map((x) => (x.id === id ? { ...x, unread: false } : x)));
    setNotif("dismissed");
  };
  const restore = () => {
    if (!undo) return;
    const back = undo.rows;
    upd((m) => [...m.filter((x) => !back.some((b) => b.id === x.id)), ...back].sort((a, b) => b.id - a.id));
    setUndo(null);
    setCleared(false);
    setNotif("shown");
  };

  const reducedNow = typeof window !== "undefined" && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  const undoText = undo ? { archived: "Archived", trashed: "Moved to Trash", spam: "Reported as spam" }[undo.kind] : "";
  const rows = mails.slice(0, MAX_ROWS);

  return (
    <div className="gx" ref={stage} aria-live="off" data-testid="gm-demo">
      <div className="gx__mail">
        <div className="gx__bar">
          <span className="gx__label">Inbox</span>
          <span className={`gx__watch${cleared ? " is-cleared" : ""}`} role="status" data-testid="gm-status">
            {cleared ? "Nothing unread from @rive.app — notification cleared" : "Watching @rive.app"}
          </span>
        </div>
        {undo ? (
          <p className="gx__undo">
            {undoText} ·{" "}
            <button type="button" className="gx__link" data-testid="gm-restore" onClick={restore}>
              Put it back (demo)
            </button>
          </p>
        ) : null}
        <div className="gx__rows" data-testid="gm-inbox">
          {rows.map((m) => (
            <div className={`gx__rw${m.fx ? ` is-${m.fx}` : ""}`} key={m.id}>
              <div
                className={`gx__row${m.unread ? " is-unread" : ""}${opened === m.id ? " is-opened" : ""}`}
                data-testid="gm-row"
                data-rive={m.rive ? "1" : "0"}
                data-unread={m.unread ? "1" : "0"}
              >
                <span className="gx__from">{m.sender}</span>
                <span className="gx__msg">
                  <b>{m.subject}</b>
                  <span> — {m.snippet}</span>
                </span>
                <span className="gx__time">{m.time}</span>
              </div>
            </div>
          ))}
        </div>
      </div>

      <div className={`gx__nw${notif === "dismissed" ? " is-gone" : ""}`} aria-hidden={notif === "dismissed"} inert={notif === "dismissed"}>
        <div className="gx__nwin">
          <div className="gx__notif" data-testid="gm-notif" role="group" aria-label="Grouped notification from WebWatcher">
            <button type="button" className="gx__nhead" data-testid="gm-open" aria-label="Open the newest message" onClick={open}>
              <img src={asset("/images/webwatcher-icon-tile.png")} alt="" aria-hidden="true" width={36} height={36} />
              <span className="gx__nt">
                <strong>{`${count} new from Rive team`}</strong>
                {count > 0 ? (
                  <>
                    <span className="gx__subj" data-testid="gm-subjects">
                      {subjects}
                      {more > 0 ? <em> +{more} more</em> : null}
                    </span>
                    <span>received Today 8:14 PM</span>
                  </>
                ) : null}
              </span>
              <span className="gx__count" data-testid="gm-count">
                <Roll v={count} instant={reducedNow} />
              </span>
            </button>
            <div className="gx__acts">
              <button type="button" data-testid="gm-markread" onClick={markRead}>Mark as Read</button>
              <button type="button" data-testid="gm-archive" onClick={() => remove("archived")}>Archive</button>
              <button type="button" data-testid="gm-delete" onClick={() => remove("trashed")}>Delete</button>
              <button type="button" data-testid="gm-spam" onClick={() => remove("spam")}>Spam</button>
            </div>
          </div>
        </div>
      </div>

      <button type="button" className="gx__more" data-testid="gm-newmail" onClick={deliver}>
        Deliver another
      </button>
    </div>
  );
}
