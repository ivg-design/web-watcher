import "@/styles/sections-b.css";
import Link from "next/link";
import { asset } from "@/lib/config";
import { summarize, type ChangelogEntry } from "@/lib/changelog";

export default function ChangelogPreview({ entries }: { entries: ChangelogEntry[] }) {
  return (
    <section id="changelog" className="section">
      <div className="container">
        <div className="eyebrow">Recent updates</div>
        <div className="cl">
          {entries.map((e) => (
            <div className="cl__row" key={e.version}>
              <span className="cl__v">{e.version}</span>
              <span className="cl__d">{e.date}</span>
              <span className="cl__t">{summarize(e)}</span>
            </div>
          ))}
        </div>
        <Link className="cl__more" href={asset("/changelog")}>
          Full changelog ↗
        </Link>
      </div>
    </section>
  );
}
