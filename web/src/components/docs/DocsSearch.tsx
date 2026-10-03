"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { CornerDownLeft, Search } from "lucide-react";
import { asset } from "@/lib/config";
import type { SearchItem } from "@/lib/docs";

const MAX = 24;

function rank(index: SearchItem[], query: string): SearchItem[] {
  const tokens = query.toLowerCase().split(/\s+/).filter(Boolean);
  if (!tokens.length) return index.filter((i) => !i.heading).slice(0, 8);
  const scored: { item: SearchItem; score: number }[] = [];
  for (const item of index) {
    const title = item.title.toLowerCase();
    const heading = (item.heading ?? "").toLowerCase();
    const hay = `${title} ${heading} ${item.section.toLowerCase()}`;
    if (!tokens.every((t) => hay.includes(t))) continue;
    let score = 0;
    for (const t of tokens) {
      if (title.includes(t)) score += 10;
      if (title.startsWith(t)) score += 4;
      if (heading.includes(t)) score += 3;
    }
    if (!item.heading) score += 6; // page hits before heading hits
    if (tokens.every((t) => title.includes(t))) score += 20;
    scored.push({ item, score });
  }
  return scored.sort((a, b) => b.score - a.score).slice(0, MAX).map((s) => s.item);
}

export default function DocsSearch({ index, onClose }: { index: SearchItem[]; onClose: () => void }) {
  const router = useRouter();
  const [query, setQuery] = useState("");
  const [active, setActive] = useState(0);
  const inputRef = useRef<HTMLInputElement>(null);
  const listRef = useRef<HTMLUListElement>(null);
  const results = useMemo(() => rank(index, query), [index, query]);

  useEffect(() => {
    const prev = document.activeElement as HTMLElement | null;
    inputRef.current?.focus();
    return () => { prev?.focus?.(); };
  }, []);

  useEffect(() => {
    const prev = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => { document.body.style.overflow = prev; };
  }, []);

  useEffect(() => {
    listRef.current?.children[active]?.scrollIntoView({ block: "nearest" });
  }, [active]);

  const go = (item: SearchItem | undefined) => {
    if (!item) return;
    onClose();
    router.push(asset(`/docs/${item.slug}${item.id ? `#${item.id}` : ""}`));
  };

  const onKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === "Escape") { e.preventDefault(); onClose(); }
    else if (e.key === "ArrowDown") { e.preventDefault(); setActive((a) => (results.length ? (a + 1) % results.length : 0)); }
    else if (e.key === "ArrowUp") { e.preventDefault(); setActive((a) => (results.length ? (a - 1 + results.length) % results.length : 0)); }
    else if (e.key === "Enter") { e.preventDefault(); go(results[active]); }
    else if (e.key === "Tab") { e.preventDefault(); inputRef.current?.focus(); }
  };

  return (
    <div className="search" onMouseDown={(e) => { if (e.target === e.currentTarget) onClose(); }}>
      <div className="search__box paper" role="dialog" aria-modal="true" aria-label="Search documentation" onKeyDown={onKeyDown}>
        <div className="search__input">
          <Search size={18} aria-hidden />
          <input
            ref={inputRef}
            autoFocus
            type="text"
            role="combobox"
            aria-expanded="true"
            aria-controls="docs-search-list"
            aria-activedescendant={results[active] ? `docs-search-${active}` : undefined}
            aria-label="Search docs"
            placeholder="Search docs…"
            autoComplete="off"
            spellCheck={false}
            value={query}
            onChange={(e) => { setQuery(e.target.value); setActive(0); }}
          />
          <kbd className="search__esc">Esc</kbd>
        </div>
        {results.length ? (
          <ul id="docs-search-list" ref={listRef} className="search__list" role="listbox" aria-label="Results">
            {results.map((r, i) => (
              <li
                key={`${r.slug}#${r.id ?? ""}`}
                id={`docs-search-${i}`}
                role="option"
                aria-selected={i === active}
                className="search__item"
                onMouseMove={() => active !== i && setActive(i)}
                onClick={() => go(r)}
              >
                <strong>{r.heading ?? r.title}</strong>
                <small>{r.heading ? `${r.section} › ${r.title}` : r.section}</small>
                {i === active && <CornerDownLeft size={14} aria-hidden className="search__enter" />}
              </li>
            ))}
          </ul>
        ) : (
          <p className="search__empty" role="status">No pages match “{query}”.</p>
        )}
      </div>
    </div>
  );
}
