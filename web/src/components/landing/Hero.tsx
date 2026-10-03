import { Download } from "lucide-react";
import type { LatestRelease } from "@/lib/release";
import { REPO_URL } from "@/lib/config";
import HeroDemo from "./HeroDemo";
import DemoLink from "./a/DemoLink";
import "@/styles/sections-a.css";

export default function Hero({ release }: { release: LatestRelease }) {
  return (
    <section id="hero" className="hero" aria-labelledby="hero-title">
      <div className="container hero__grid">
        <div className="hero__copy">
          <p className="badge hero-in" style={{ "--i": 0 } as React.CSSProperties}>
            <i aria-hidden="true" />
            Free · Open source · macOS 13+ · Notarized
          </p>
          <h1 id="hero-title" className="hero__title">
            <span className="hero-in" style={{ "--i": 1 } as React.CSSProperties}>Stop refreshing.</span>
            <span className="accent hero-in" style={{ "--i": 2 } as React.CSSProperties}>Start knowing.</span>
          </h1>
          <p className="hero__lede hero-in" style={{ "--i": 3 } as React.CSSProperties}>
            WebWatcher sits in your menu bar and watches the badges, counters and inboxes you keep
            checking by hand — the Rive community bell, a Gmail sender, a forum thread — and tells
            you the moment they change.
          </p>
          <div className="hero__cta hero-in" style={{ "--i": 4 } as React.CSSProperties}>
            <a className="btn btn--primary" href={release.dmgUrl} data-forge-action="download_intent">
              <Download size={20} aria-hidden="true" />
              Download for Mac · {release.version}
            </a>
            <a className="btn btn--ghost" href={REPO_URL}>View on GitHub</a>
          </div>
          <p className="hero__facts hero-in" style={{ "--i": 5 } as React.CSSProperties}>
            Apple Silicon DMG · Developer ID signed and notarized · MIT license · No account, no server, nothing leaves your Mac
          </p>
          <div className="hero-in" style={{ "--i": 6 } as React.CSSProperties}>
            <DemoLink />
          </div>
        </div>
        <div className="hero__media">
          <HeroDemo />
        </div>
      </div>
    </section>
  );
}
