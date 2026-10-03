"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { ArrowUpRight, Menu, Search, X } from "lucide-react";
import { asset, REPO_URL } from "@/lib/config";
import type { SearchItem } from "@/lib/docs";
import DocsSearch from "./DocsSearch";

export interface NavSection { title: string; docs: { slug: string; title: string }[] }

function Tree({ sections, current, onNavigate }: { sections: NavSection[]; current: string | null; onNavigate?: () => void }) {
  return (
    <>
      {sections.map((s) => (
        <div key={s.title} className="docs-group">
          <p className="docs-group__t">{s.title}</p>
          {s.docs.map((d) => (
            <Link
              key={d.slug}
              href={asset(`/docs/${d.slug}`)}
              aria-current={current === d.slug ? "page" : undefined}
              onClick={onNavigate}
            >
              {d.title}
            </Link>
          ))}
        </div>
      ))}
    </>
  );
}

export default function DocsChrome({
  sections,
  index,
  children,
}: {
  sections: NavSection[];
  index: SearchItem[];
  children: React.ReactNode;
}) {
  const pathname = usePathname() ?? "";
  const seg = pathname.replace(/\/+$/, "").split("/");
  const current = seg[seg.length - 2] === "docs" ? seg[seg.length - 1] : null;
  const [drawer, setDrawer] = useState(false);
  const [searchOpen, setSearchOpen] = useState(false);

  const [seenPath, setSeenPath] = useState(pathname);
  if (seenPath !== pathname) { setSeenPath(pathname); setDrawer(false); }

  useEffect(() => {
    if (!drawer) return;
    const prev = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    const onKey = (e: KeyboardEvent) => { if (e.key === "Escape") setDrawer(false); };
    const mq = window.matchMedia("(min-width: 1100px)");
    const onMq = () => { if (mq.matches) setDrawer(false); };
    window.addEventListener("keydown", onKey);
    mq.addEventListener("change", onMq);
    return () => {
      document.body.style.overflow = prev;
      window.removeEventListener("keydown", onKey);
      mq.removeEventListener("change", onMq);
    };
  }, [drawer]);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      const t = e.target as HTMLElement | null;
      const typing = !!t && (t.tagName === "INPUT" || t.tagName === "TEXTAREA" || t.tagName === "SELECT" || t.isContentEditable);
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === "k") {
        e.preventDefault();
        setSearchOpen((o) => !o);
      } else if (e.key === "/" && !typing && !e.metaKey && !e.ctrlKey && !e.altKey) {
        e.preventDefault();
        setSearchOpen(true);
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, []);

  return (
    <>
      <header className="docs-header">
       <div className="docs-header__in">
        <button
          type="button"
          className="docs-menu-btn"
          aria-label={drawer ? "Close navigation" : "Open navigation"}
          aria-expanded={drawer}
          aria-controls="docs-drawer"
          onClick={() => setDrawer((o) => !o)}
        >
          {drawer ? <X size={20} aria-hidden /> : <Menu size={20} aria-hidden />}
        </button>
        <div className="docs-brand">
          <Link href={asset("/")} className="brand" aria-label="WebWatcher home">
            { }
            <img src={asset("/images/webwatcher-icon-tile.png")} alt="" aria-hidden="true" width={54} height={54} />
            WebWatcher
          </Link>
          <Link href={asset("/docs")} className="docs-crumb">/ Docs</Link>
        </div>
        <button type="button" className="search-btn" aria-label="Search docs" aria-keyshortcuts="Control+K Meta+K" onClick={() => setSearchOpen(true)}>
          <Search size={16} aria-hidden />
          <span>Search docs…</span>
          <kbd>⌘K</kbd>
        </button>
        <nav className="docs-header__links" aria-label="Site">
          <Link href={asset("/")}>Home</Link>
          <Link href={asset("/changelog")}>Changelog</Link>
          <a href={REPO_URL} target="_blank" rel="noopener noreferrer">GitHub <ArrowUpRight size={13} aria-hidden style={{ verticalAlign: "-2px" }} /></a>
        </nav>
       </div>
      </header>

      {drawer && (
        <nav id="docs-drawer" className="docs-drawer paper" aria-label="Documentation">
          <Tree sections={sections} current={current} onNavigate={() => setDrawer(false)} />
          <div className="docs-group docs-drawer__site">
            <p className="docs-group__t">WebWatcher</p>
            <Link href={asset("/")}>Home</Link>
            <Link href={asset("/changelog")}>Changelog</Link>
            <a href={REPO_URL} target="_blank" rel="noopener noreferrer">GitHub</a>
          </div>
        </nav>
      )}

      <div className="docs-shell paper">
        <div className="docs-shell__in">
          <nav className="docs-side" aria-label="Documentation">
            <Tree sections={sections} current={current} />
          </nav>
          {children}
        </div>
      </div>

      {searchOpen && <DocsSearch index={index} onClose={() => setSearchOpen(false)} />}
    </>
  );
}
