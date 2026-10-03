"use client";

import { useEffect, useRef, useState } from "react";
import { asset } from "@/lib/config";

type State = "shown" | "leaving" | "snoozed" | "dismissed";

/** Banner whose buttons behave as in Herald: actions dismiss it, Snooze hides it until later. */
export default function HeraldBanner() {
  const [state, setState] = useState<State>("shown");
  const [back, setBack] = useState(false); // true once it has returned (play slide-in)
  const timers = useRef<number[]>([]);
  useEffect(() => () => timers.current.forEach(window.clearTimeout), []);
  const later = (fn: () => void, ms: number) => timers.current.push(window.setTimeout(fn, ms));

  const leave = (next: "snoozed" | "dismissed") => {
    setState("leaving");
    later(() => {
      setState(next);
      if (next === "snoozed") later(() => { setBack(true); setState("shown"); }, 3000);
    }, 300);
  };
  const showAgain = () => { setBack(true); setState("shown"); };
  const visible = state === "shown" || state === "leaving";

  return (
    <div className="hb">
      {visible && (
        <div className={`banner${state === "leaving" ? " is-leaving" : back ? " is-back" : ""}`} data-testid="hb-banner">
          <div className="banner__top">
            <img src={asset("/images/herald-icon.png")} alt="" width={26} height={26} />
            <div>
              <div className="banner__app">Herald · WebWatcher · Email</div>
              <div className="banner__title">3 new from Rive team</div>
            </div>
            <span className="banner__count">3</span>
          </div>
          <div className="banner__body">Scripting update · Office hours · Release notes</div>
          <div className="banner__btns">
            <button type="button" className="bbtn bbtn--open" data-testid="hb-open" onClick={() => leave("dismissed")}>Open</button>
            <button type="button" className="bbtn" data-testid="hb-read" onClick={() => leave("dismissed")}>Mark as Read</button>
            <button type="button" className="bbtn" data-testid="hb-archive" onClick={() => leave("dismissed")}>Archive</button>
            <button type="button" className="bbtn" data-testid="hb-snooze" onClick={() => leave("snoozed")}>Snooze</button>
          </div>
        </div>
      )}
      <div className="hb__note" role="status">
        {state === "snoozed" && <span data-testid="hb-returns">Snoozed · returns at 9:00</span>}
        {state === "dismissed" && (
          <span>
            Banner dismissed ·{" "}
            <button type="button" className="hb__link" data-testid="hb-show" onClick={showAgain}>Show again</button>
          </span>
        )}
      </div>
    </div>
  );
}
