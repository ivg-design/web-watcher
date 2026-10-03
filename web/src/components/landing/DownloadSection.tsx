import "@/styles/download.css";
import { Check } from "lucide-react";
import Reveal from "@/components/motion/Reveal";
import type { LatestRelease } from "@/lib/release";
import DownloadBox from "./b/DownloadBox";

const REQS = [
  "macOS 13 Ventura or later · Apple Silicon only (arm64 build)",
  "Safari (the page you watch stays open in a tab)",
  "Optional: a Google account for Gmail · Herald for persistent banners",
];

export default function DownloadSection({ release }: { release: LatestRelease }) {
  return (
    <section id="download" className="dlx">
      <div className="container dlx__grid">
        <Reveal>
          <p className="eyebrow" style={{ color: "#cfdcff" }}><span className="eyebrow__n" style={{ color: "#cfdcff" }}>07</span>Download</p>
          <h2 className="dlx__h" style={{ marginTop: 16 }}>Stop refreshing today.</h2>
          <p className="dlx__p">
            Free, open source, no account. Drag to Applications, flip three switches, add your first watcher in under a
            minute.
          </p>
          <ul className="dlx__list">
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
