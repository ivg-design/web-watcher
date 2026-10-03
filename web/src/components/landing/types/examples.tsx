import Roll from "../hero/Roll";

type P = { on: boolean };

/* Specimens: drawn at poster size for the wall. System font inside macOS mocks, Archivo inside web-page mocks. */

function BellGlyph({ size = 120 }: { size?: number }) {
  return (
    <svg className="wt-bellsvg" width={size} height={size} viewBox="0 0 64 64" aria-hidden="true">
      <path
        fill="currentColor"
        d="M32 5.5c-2.1 0-3.7 1.5-3.7 3.4v1.2C20.5 11.8 16 18.3 16 26.3V37c0 3.1-1.5 5.4-3.8 7.7-1.3 1.3-.4 3.5 1.5 3.5h36.6c1.9 0 2.8-2.2 1.5-3.5C49.5 42.4 48 40.1 48 37V26.3c0-8-4.5-14.5-12.3-16.2V8.9C35.7 7 34.1 5.5 32 5.5Z"
      />
      <path fill="currentColor" d="M25.2 51.5a6.8 6.8 0 0 0 13.6 0Z" />
    </svg>
  );
}

export function BadgeEx({ on }: P) {
  return (
    <span className="wt-bell wt-watched" data-testid="wt-ex-badge">
      <BellGlyph />
      <span className="wt-badge">
        <span data-testid="wt-val-badge"><Roll v={on ? "5" : "3"} /></span>
      </span>
    </span>
  );
}

export function TextEx({ on }: P) {
  return (
    <span className="wt-tk" data-testid="wt-ex-text">
      <span className="wt-tk__h">
        <b>Ticket 482</b>
        <small>Cutout shapes will not export</small>
      </span>
      <span className="wt-tk__row">
        <small>Status</small>
        <span className={`wt-chip wt-watched${on ? " is-closed" : ""}`}>
          <i aria-hidden="true" />
          <span data-testid="wt-val-text"><Roll v={on ? "Closed" : "Open"} /></span>
        </span>
      </span>
    </span>
  );
}

const THREADS: [string, string, string][] = [
  ["Re: cutout shapes", "mia.d", "2m"],
  ["Bone constraint tips", "joaquin", "9m"],
  ["Nested artboards?", "ahmed.k", "21m"],
  ["Trigger on hover", "sana", "now"],
];
export function CountEx({ on }: P) {
  return (
    <span className="wt-list" data-testid="wt-ex-count">
      <span className="wt-list__h"><b>Rive Community</b><small>Latest</small></span>
      <span className="wt-list__rows wt-watched">
        {THREADS.map(([t, who, ago], i) => (i === 3 && !on ? null : (
          <span key={t} className={`wt-list__r${i === 3 ? " is-new is-on" : ""}`}>
            <i aria-hidden="true">{who[0].toUpperCase()}</i>
            <span className="wt-list__t"><b>{t}</b><small>{who}</small></span>
            <small className="wt-list__a">{ago}</small>
          </span>
        )))}
      </span>
      <span className="wt-list__n"><span data-testid="wt-val-count"><Roll v={on ? "4 items" : "3 items"} /></span></span>
    </span>
  );
}

function Headphones() {
  return (
    <svg width="132" height="88" viewBox="0 0 132 88" aria-hidden="true">
      <path d="M26 56V46a40 40 0 0 1 80 0v10" fill="none" stroke="currentColor" strokeWidth="6" strokeLinecap="round" />
      <rect x="16" y="50" width="26" height="34" rx="10" fill="currentColor" />
      <rect x="90" y="50" width="26" height="34" rx="10" fill="currentColor" />
      <rect x="38" y="58" width="6" height="18" rx="3" className="wt-prod__pad" />
      <rect x="88" y="58" width="6" height="18" rx="3" className="wt-prod__pad" />
    </svg>
  );
}

export function ExistsEx({ on }: P) {
  return (
    <span className="wt-prod" data-testid="wt-ex-appears">
      <span className="wt-prod__img">
        <Headphones />
        <span className={`wt-tag${on ? " is-on" : ""}`} data-testid="wt-soldout" data-on={on ? "1" : "0"} aria-hidden={!on}>Sold out</span>
      </span>
      <span className="wt-prod__t">Studio headphones</span>
      <span className="wt-prod__p">$249.00</span>
      <span className="wt-prod__cta">Add to cart</span>
    </span>
  );
}

export function DisappearsEx({ on }: P) {
  return (
    <span className="wt-prod" data-testid="wt-ex-disappears">
      <span className="wt-prod__img">
        <Headphones />
      </span>
      <span className="wt-prod__t">Studio headphones</span>
      <span className="wt-prod__p">$249.00</span>
      <span className={`wt-join${on ? " is-gone" : ""}`} data-testid="wt-joinbtn" data-on={on ? "0" : "1"} aria-hidden={on}>Join waitlist</span>
    </span>
  );
}

export function SubtreeEx({ on }: P) {
  return (
    <span className="wt-bell wt-watched wt-bell--area" data-testid="wt-ex-subtree">
      <BellGlyph />
      <span className={`wt-badge wt-badge--cut${on ? " is-on" : ""}`} data-testid="wt-val-subtree" data-on={on ? "1" : "0"}>1</span>
    </span>
  );
}
