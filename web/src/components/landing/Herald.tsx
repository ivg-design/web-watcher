import "@/styles/sections-b.css";
import "@/styles/herald.css";
import { HERALD_URL, asset } from "@/lib/config";
import HeraldDemo from "./herald/HeraldDemo";

export default function Herald() {
  return (
    <section id="herald" className="herald">
      <HeraldDemo>
        <div className="herald__copy">
          <div className="herald__head">
            <img className="herald__logo" src={asset("/images/herald-logo.png")} alt="Herald" width={64} height={64} />
            <h2 className="h2-v3 herald__title">
              <span className="herald__l">Make it</span> <span className="herald__l">talk back.</span>
            </h2>
          </div>
          <p className="herald__p">
            Herald turns <span className="nw">WebWatcher</span>’s alerts into banners that stay until you deal with them, can
            read themselves aloud, and carry the buttons that matter right on the banner: Archive, Mark as read, Delete. One
            switch in Settings. No Herald, no change.
          </p>
          <div className="herald__cta">
            <a className="btn btn--primary btn--herald" href={HERALD_URL} target="_blank" rel="noopener noreferrer" data-testid="herald-get">
              <img src={asset("/images/herald-icon.png")} alt="" aria-hidden="true" width={24} height={24} />
              Get Herald
            </a>
            <span className="t-label herald__free">free</span>
          </div>
        </div>
      </HeraldDemo>
    </section>
  );
}
