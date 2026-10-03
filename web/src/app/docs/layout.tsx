import type { Metadata } from "next";
import DocsChrome from "@/components/docs/DocsChrome";
import { DOC_SECTIONS, getSearchIndex } from "@/lib/docs";
import "@/styles/docs.css";

export const metadata: Metadata = {
  title: { default: "Docs | WebWatcher", template: "%s" },
};

export default function DocsLayout({ children }: { children: React.ReactNode }) {
  const sections = DOC_SECTIONS.map((s) => ({ title: s.title, docs: s.docs.map((d) => ({ slug: d.slug, title: d.title })) }));
  return (
    <DocsChrome sections={sections} index={getSearchIndex()}>
      {children}
    </DocsChrome>
  );
}
