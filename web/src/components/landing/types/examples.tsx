import { Bell } from "lucide-react";
import Flip from "./Flip";

type P = { on: boolean };

export function BadgeEx({ on }: P) {
  return (
    <span className="wt-bell">
      <Bell size={26} aria-hidden="true" />
      <span className="wt-badge" data-testid="wt-ex-badge"><Flip text={on ? "5" : "3"} testid="wt-val-badge" /></span>
    </span>
  );
}

export function TextEx({ on }: P) {
  return (
    <span className={`wt-chip${on ? " is-closed" : ""}`} data-testid="wt-ex-text">
      <i aria-hidden="true" />
      <Flip text={on ? "Closed" : "Open"} testid="wt-val-text" />
    </span>
  );
}

const ROWS = ["Re: cutout shapes", "Bone constraint tips", "Nested artboards?", "Trigger on hover"];
export function CountEx({ on }: P) {
  return (
    <span className="wt-list" data-testid="wt-ex-count">
      <span className="wt-list__rows">
        {ROWS.map((r, i) => (
          <span key={r} className={`wt-list__r${i === 3 ? " is-new" : ""}${i === 3 && on ? " is-on" : ""}`}>{r}</span>
        ))}
      </span>
      <span className="wt-list__n"><Flip text={on ? "4 items" : "3 items"} testid="wt-val-count" /></span>
    </span>
  );
}

export function AppearsEx({ on }: P) {
  return (
    <span className="wt-prod" data-testid="wt-ex-appears">
      <span className="wt-prod__img" aria-hidden="true" />
      <span className="wt-prod__t">Studio headphones</span>
      <span className={`wt-tag${on ? " is-on" : ""}`} data-testid="wt-soldout" data-on={on ? "1" : "0"} aria-hidden={!on}>Sold out</span>
    </span>
  );
}

export function TitleEx({ on }: P) {
  return (
    <span className="wt-tab" data-testid="wt-ex-title">
      <span className="wt-tab__dots" aria-hidden="true"><i /><i /><i /></span>
      <span className="wt-tab__pill">
        <i aria-hidden="true" />
        <Flip text={on ? "(3) Inbox" : "(0) Inbox"} testid="wt-val-title" />
      </span>
    </span>
  );
}

export function SubtreeEx({ on }: P) {
  return (
    <span className="wt-bell" data-testid="wt-ex-subtree">
      <Bell size={26} aria-hidden="true" />
      <span className={`wt-badge wt-badge--pop${on ? " is-on" : ""}`} data-testid="wt-val-subtree" data-on={on ? "1" : "0"}>1</span>
    </span>
  );
}
