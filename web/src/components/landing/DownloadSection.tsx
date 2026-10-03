import "@/styles/sections-b.css";
import { Check } from "lucide-react";
import Reveal from "@/components/motion/Reveal";
import type { LatestRelease } from "@/lib/release";
import DownloadBox from "./b/DownloadBox";

const REQS = [
  "macOS 13 Ventura or later · Apple Silicon only (arm64) — the released build does not include an Intel slice",
  "Safari (the page you watch stays open in a tab)",
  "Optional: a Google account for Gmail watchers · Herald for persistent banners",
];

export default function DownloadSection({ release }: { release: LatestRelease }) {
  return (
    <section id="download" className="dl">
      <div className="container dl__grid">
        <Reveal>
          <h2 className="dl__h">Stop refreshing today.</h2>
          <p className="dl__p">
            Free, open source, no account. Drag to Applications, flip three switches, add your first watcher in under a
            minute.
          </p>
          <ul className="dl__list">
            {REQS.map((r) => (
              <li key={r}>
                <Check size={14} aria-hidden="true" />
                {r}
              </li>
            ))}
          </ul>
        </Reveal>
        <Reveal delay={0.1}>
          <DownloadBox release={release} />
        </Reveal>
      </div>
    </section>
  );
}
