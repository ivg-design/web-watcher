"use client";

import { useEffect, useState } from "react";
import type { Heading } from "@/lib/markdown";

export default function Toc({ headings }: { headings: Heading[] }) {
  const [active, setActive] = useState(headings[0]?.id ?? "");

  useEffect(() => {
    if (!headings.length) return;
    const els = headings.map((h) => document.getElementById(h.id)).filter(Boolean) as HTMLElement[];
    const visible = new Set<string>();
    const obs = new IntersectionObserver(
      (entries) => {
        for (const e of entries) {
          if (e.isIntersecting) visible.add(e.target.id);
          else visible.delete(e.target.id);
        }
        const first = els.find((el) => visible.has(el.id));
        if (first) setActive(first.id);
      },
      { rootMargin: "-80px 0px -65% 0px", threshold: 0 },
    );
    els.forEach((el) => obs.observe(el));
    return () => obs.disconnect();
  }, [headings]);

  if (!headings.length) return null;
  return (
    <aside className="toc" aria-label="On this page">
      <p className="toc__t">On this page</p>
      {headings.map((h) => (
        <a
          key={h.id}
          href={`#${h.id}`}
          className={`${h.level === 3 ? "sub" : ""} ${active === h.id ? "is-on" : ""}`.trim()}
          aria-current={active === h.id ? "location" : undefined}
          onClick={() => setActive(h.id)}
        >
          {h.text}
        </a>
      ))}
    </aside>
  );
}
