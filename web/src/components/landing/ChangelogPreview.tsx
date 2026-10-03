import "@/styles/download.css";
import Link from "next/link";
import { asset } from "@/lib/config";
import { getChangelog, summarize, type ChangelogEntry } from "@/lib/changelog";

export default function ChangelogPreview({ entries }: { entries: ChangelogEntry[] }) {
  const latest = getChangelog()[0]?.version;
  return (
    <section id="changelog" className="clx">
      <div className="container">
        <p className="eyebrow"><span className="eyebrow__n">08</span>Recent updates</p>
        <div className="clx__list">
          {entries.map((e, i) => (
            <div className="clx__row" key={e.version}>
              <span className="clx__v">
                {e.version}
                {i === 0 && e.version === latest && <span className="clx__tag">Latest</span>}
              </span>
              <span className="clx__d">{e.date}</span>
              <span className="clx__t">{summarize(e)}</span>
            </div>
          ))}
        </div>
        <Link className="clx__more" href={asset("/changelog")}>
          Full changelog ↗
        </Link>
      </div>
    </section>
  );
}
