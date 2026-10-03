import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { ChevronRight } from "lucide-react";
import Toc from "@/components/docs/Toc";
import { asset } from "@/lib/config";
import { ALL_DOCS, getDoc } from "@/lib/docs";
import { toCanonicalUrl } from "@/lib/seo";

export const dynamicParams = false;
export function generateStaticParams() {
  return ALL_DOCS.map((d) => ({ slug: d.slug }));
}

type Params = { params: Promise<{ slug: string }> };

export async function generateMetadata({ params }: Params): Promise<Metadata> {
  const { slug } = await params;
  const doc = ALL_DOCS.find((d) => d.slug === slug);
  if (!doc) return {};
  const title = `${doc.title} | WebWatcher Docs`;
  const url = toCanonicalUrl(`/docs/${slug}`);
  return {
    title: { absolute: title },
    description: doc.summary,
    alternates: { canonical: url },
    openGraph: { title, description: doc.summary, type: "article", url, siteName: "WebWatcher" },
  };
}

export default async function DocPage({ params }: Params) {
  const { slug } = await params;
  const doc = getDoc(slug);
  if (!doc) notFound();
  const { meta, html, lede, headings, prev, next } = doc;
  const sectionId = meta.section.toLowerCase().replace(/[^a-z0-9]+/g, "-");
  const jsonLd = {
    "@context": "https://schema.org",
    "@type": "TechArticle",
    headline: meta.title,
    description: meta.summary,
    url: toCanonicalUrl(`/docs/${slug}`),
    inLanguage: "en",
    isPartOf: { "@type": "WebSite", name: "WebWatcher Docs", url: toCanonicalUrl("/docs") },
    author: { "@type": "Organization", name: "IVG Design" },
    publisher: { "@type": "Organization", name: "IVG Design" },
  };

  return (
    <>
      <main className="docs-main" id="main">
        <article className="docs-article">
          <nav className="crumbs" aria-label="Breadcrumb">
            <Link href={asset(`/docs#${sectionId}`)}>{meta.section}</Link>
            <ChevronRight size={13} aria-hidden />
            <span aria-current="page">{meta.title}</span>
          </nav>
          <h1 className="doc-title">{meta.title}</h1>
          <p className="doc-lede" dangerouslySetInnerHTML={{ __html: lede || meta.summary }} />
          {headings.length > 0 && (
            <details className="toc-inline">
              <summary>On this page</summary>
              {headings.map((h) => (
                <a key={h.id} href={`#${h.id}`} style={h.level === 3 ? { paddingLeft: 14 } : undefined}>{h.text}</a>
              ))}
            </details>
          )}
          <div className="prose" dangerouslySetInnerHTML={{ __html: html }} />
          <nav className="pager" aria-label="Previous and next page">
            {prev ? (
              <Link href={asset(`/docs/${prev.slug}`)} rel="prev">
                <small>Previous</small>
                <span>← {prev.title}</span>
              </Link>
            ) : <span />}
            {next ? (
              <Link href={asset(`/docs/${next.slug}`)} rel="next">
                <small>Next</small>
                <span>{next.title} →</span>
              </Link>
            ) : <span />}
          </nav>
        </article>
        <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd).replace(/</g, "\\u003c") }} />
      </main>
      <Toc headings={headings} />
    </>
  );
}
