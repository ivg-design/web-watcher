import type { Metadata } from "next";
import Footer from "@/components/Footer";
import SiteHeader from "@/components/SiteHeader";
import { RELEASES_URL } from "@/lib/config";
import { getChangelog } from "@/lib/changelog";
import { renderInline } from "@/lib/markdown";
import { toCanonicalUrl } from "@/lib/seo";
import "@/styles/docs.css";
import "@/styles/download.css";

const description = "Every WebWatcher release, newest first: what was added, changed and fixed in each version and build.";

export const metadata: Metadata = {
  title: "Changelog",
  description,
  alternates: { canonical: toCanonicalUrl("/changelog") },
  openGraph: { title: "Changelog | WebWatcher", description, type: "website", url: toCanonicalUrl("/changelog"), siteName: "WebWatcher" },
};

export default function ChangelogPage() {
  const entries = getChangelog();
  return (
    <>
      <SiteHeader />
      <main id="main" className="paper cl-page">
        <div className="container">
        <header className="page-head">
          <h1 className="page-title">Changelog</h1>
          <p className="doc-lede">
            Every release of WebWatcher, newest first.{" "}
            <a href={RELEASES_URL} target="_blank" rel="noopener noreferrer" className="log__latest">Latest release on GitHub ↗</a>
          </p>
        </header>
        <div className="log">
          {entries.map((e) => (
            <article key={e.version} id={`v${e.version.replace(/\./g, "-")}`} className="log__entry">
              <header>
                <h2 className="log__v">{e.version}</h2>
                <p className="log__d">
                  {e.build ? `Build ${e.build} · ` : ""}
                  <time dateTime={e.date}>{e.date}</time>
                </p>
              </header>
              <div>
                {e.sections.map((s) => (
                  <section key={s.title}>
                    <h3>{s.title}</h3>
                    <ul>
                      {s.items.map((item, i) => (
                        <li key={i} dangerouslySetInnerHTML={{ __html: renderInline(item) }} />
                      ))}
                    </ul>
                  </section>
                ))}
              </div>
            </article>
          ))}
        </div>
        </div>
      </main>
      <Footer />
    </>
  );
}
