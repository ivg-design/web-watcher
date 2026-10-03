import type { Metadata } from "next";
import Link from "next/link";
import { asset } from "@/lib/config";
import { DOC_SECTIONS } from "@/lib/docs";
import { toCanonicalUrl } from "@/lib/seo";

const description =
  "How to install WebWatcher, pick the element to watch in Safari, watch Gmail senders, customise notifications and fix common problems.";

export const metadata: Metadata = {
  title: "WebWatcher Docs",
  description,
  alternates: { canonical: toCanonicalUrl("/docs") },
  openGraph: { title: "WebWatcher Docs", description, type: "website", url: toCanonicalUrl("/docs"), siteName: "WebWatcher" },
};

export default function DocsIndex() {
  return (
    <main className="docs-main docs-main--wide" id="main">
      <div className="docs-article docs-article--index">
        <p className="crumbs">Documentation</p>
        <h1 className="doc-title">WebWatcher Docs</h1>
        <p className="doc-lede">
          WebWatcher is a macOS menu bar app that watches a badge, a counter or a Gmail sender and tells you when it
          changes. Start with the install and your first watcher, then read how the element picker works.
        </p>
        <div className="docs-index">
          {DOC_SECTIONS.map((s) => (
            <section key={s.title} id={s.title.toLowerCase().replace(/[^a-z0-9]+/g, "-")}>
              <h2>{s.title}</h2>
              {s.docs.map((d) => (
                <Link key={d.slug} href={asset(`/docs/${d.slug}`)}>
                  <strong>{d.title}</strong>
                  <span>{d.summary}</span>
                </Link>
              ))}
            </section>
          ))}
        </div>
      </div>
    </main>
  );
}
