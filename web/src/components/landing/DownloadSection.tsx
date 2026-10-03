import "@/styles/download.css";
import type { LatestRelease } from "@/lib/release";
import DownloadBox from "./b/DownloadBox";

const REQS = [
  <><span className="nw">macOS 13</span> Ventura or later. <span className="nw">Apple Silicon</span> only (arm64 build).</>,
  "Safari. The page you watch stays open in a tab.",
  "Optional: a Google account for Gmail, Herald for persistent banners.",
];

export default function DownloadSection({ release }: { release: LatestRelease }) {
  return (
    <section id="download" className="dlx paper">
      <div className="container dlx__grid">
        <div>
          <h2 className="t-cond dlx__h">Stop refreshing today.</h2>
          <p className="dlx__p">
            Free, open source, no account. Drag to Applications, flip three switches, add your first watcher in under a
            minute.
          </p>
          <ul className="dlx__list">
            {REQS.map((r, i) => (
              <li key={i}>
                <span className="dlx__tick" aria-hidden="true">✓</span>
                <span>{r}</span>
              </li>
            ))}
          </ul>
        </div>
        <DownloadBox release={release} />
      </div>
    </section>
  );
}
