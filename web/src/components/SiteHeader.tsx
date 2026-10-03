"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { ArrowUpRight, Menu, X } from "lucide-react";
import { asset, REPO_URL } from "@/lib/config";
import WatchMark from "@/components/watch/WatchMark";
import TickLine from "@/components/watch/TickLine";
import "@/styles/header.css";

const LINKS = [
  { label: "How it works", href: "/#how-it-works" },
  { label: "Picker", href: "/#picker" },
  { label: "Gmail", href: "/#gmail" },
  { label: "Herald", href: "/#herald" },
  { label: "Download", href: "/#download" },
  { label: "Changelog", href: "/#changelog" },
  { label: "Docs", href: "/docs" },
];

const fmt = new Intl.DateTimeFormat("en-US", { weekday: "short", hour: "numeric", minute: "2-digit", hour12: true });
function clockText(d: Date): string {
  const p = Object.fromEntries(fmt.formatToParts(d).map((x) => [x.type, x.value]));
  return `${p.weekday} ${p.hour}:${p.minute} ${String(p.dayPeriod).toUpperCase()}`;
}

/** Live local time like the macOS menu bar; client-only, ticks at the minute boundary. */
function Clock() {
  const [t, setT] = useState("");
  useEffect(() => {
    let id = 0;
    const tick = () => {
      const n = new Date();
      setT(clockText(n));
      id = window.setTimeout(tick, 60000 - (n.getSeconds() * 1000 + n.getMilliseconds()) + 20);
    };
    tick();
    return () => window.clearTimeout(id);
  }, []);
  return (
    <time className="menubar-clock" data-testid="menubar-clock" suppressHydrationWarning title="Local time. The hourglass sits next to it in your menu bar.">{t}</time>
  );
}

export default function SiteHeader() {
  const [open, setOpen] = useState(false);
  return (
    <header className="site-header">
      <div className="container site-header__row">
        <Link
          href={asset("/")}
          className="brand"
          data-testid="brand-home"
          onClick={(e) => {
            setOpen(false);
            // Already on the landing page: the router treats "/" as a no-op (or scrolls only until the page segment is in view),
            // so go to the very top ourselves and drop any #section from the address.
            const here = window.location.pathname.replace(/\/$/, "");
            const home = asset("/").replace(/\/$/, "");
            if (here === home && !e.metaKey && !e.ctrlKey && !e.shiftKey && !e.altKey) {
              e.preventDefault();
              window.history.replaceState(null, "", window.location.pathname + window.location.search);
              window.scrollTo({ top: 0, behavior: window.matchMedia("(prefers-reduced-motion: reduce)").matches ? "auto" : "smooth" });
            }
          }}
        >
          { }
          <img src={asset("/images/webwatcher-icon-tile.png")} alt="" aria-hidden="true" width={54} height={54} />
          <span>WebWatcher</span>
        </Link>
        <nav className="nav" aria-label="Primary">
          {LINKS.map((l) => (
            <Link key={l.label} href={asset(l.href)}>{l.label}</Link>
          ))}
        </nav>
        <div className="site-header__end">
          <a className="gh-link" href={REPO_URL} target="_blank" rel="noopener noreferrer">
            GitHub <ArrowUpRight size={14} aria-hidden />
          </a>
          <WatchMark />
          <Clock />
          <Link className="btn btn--primary btn--sm" href={asset("/#download")}>Download for Mac</Link>
          <button
            className="menu-btn"
            aria-label={open ? "Close menu" : "Open menu"}
            aria-expanded={open}
            aria-controls="mobile-nav"
            onClick={() => setOpen((v) => !v)}
          >
            {open ? <X size={20} aria-hidden /> : <Menu size={20} aria-hidden />}
          </button>
        </div>
      </div>
      <TickLine />
      {open && (
        <nav id="mobile-nav" className="mobile-nav" aria-label="Mobile">
          {LINKS.map((l) => (
            <Link key={l.label} href={asset(l.href)} onClick={() => setOpen(false)}>{l.label}</Link>
          ))}
          <a href={REPO_URL} target="_blank" rel="noopener noreferrer">GitHub</a>
        </nav>
      )}
    </header>
  );
}
