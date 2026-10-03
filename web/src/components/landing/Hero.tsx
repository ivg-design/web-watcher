import { Download } from "lucide-react";
import type { LatestRelease } from "@/lib/release";
import { REPO_URL } from "@/lib/config";
import HeroDemo, { HeroWatchLink } from "./HeroDemo";
import Moment from "./hero/Moment";
import "@/styles/sections-a.css";
import "@/styles/hero.css";

const cut = (i: number) => ({ "--i": i } as React.CSSProperties);

export default function Hero({ release }: { release: LatestRelease }) {
  return (
    <section id="hero" className="hero" aria-labelledby="hero-title">
      <div className="container">
        <div className="hero__fold">
          <h1 id="hero-title" className="hero__title t-cond">
            <span className="cut" style={cut(0)}>Stop refreshing.</span>
            <span className="cut" style={cut(1)} id="hero-line2" data-testid="hero-line2" data-lit="0">Start knowing.</span>
          </h1>
          <div className="hero__moment">
            <Moment />
          </div>
          <div className="hero__copy">
            <p className="hero__lede cut" style={cut(4)}>
              <span className="nw">WebWatcher</span> sits in your menu bar and watches the badges, counters and inboxes you keep
              checking by hand, the Rive community bell, a Gmail sender, a forum thread, and tells
              you the moment they change.
            </p>
            <div className="hero__cta cut" style={cut(4)}>
              <a className="btn btn--primary" href={release.dmgUrl} data-forge-action="download_intent" data-testid="hero-download">
                <Download size={20} aria-hidden="true" />
                Download for Mac <span className="hero__ver t-num">{release.version}</span>
              </a>
              <a className="btn btn--ghost" href={REPO_URL} data-testid="hero-github">View on GitHub</a>
            </div>
            <HeroWatchLink className="hero__watch cut" style={cut(4)} />
            <p className="hero__facts t-label cut" style={cut(4)}>
              <span className="nw">Apple Silicon</span> only. <span className="nw">macOS 13</span> or later. <span className="nw">Developer ID</span> signed and notarized. MIT. Nothing leaves your Mac.
            </p>
          </div>
        </div>
        <div className="hero__rec">
          <p className="t-label hero__rec-label">The real app, 15 s</p>
          <div className="hero__media">
            <HeroDemo />
          </div>
        </div>
      </div>
    </section>
  );
}
