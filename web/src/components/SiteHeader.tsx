"use client";

import { useState } from "react";
import Link from "next/link";
import { ArrowUpRight, Menu, X } from "lucide-react";
import { asset, REPO_URL } from "@/lib/config";
import WatchMark from "@/components/watch/WatchMark";
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

export default function SiteHeader() {
  const [open, setOpen] = useState(false);
  return (
    <header className="site-header">
      <div className="container site-header__row">
        <Link href={asset("/")} className="brand" onClick={() => setOpen(false)}>
          { }
          <img src={asset("/images/webwatcher-icon.png")} alt="" width={66} height={66} />
          WebWatcher
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
          <Link className="btn btn--dark btn--sm" href={asset("/#download")}>Download for Mac</Link>
          <button
            className="menu-btn"
            aria-label={open ? "Close menu" : "Open menu"}
            aria-expanded={open}
            aria-controls="mobile-nav"
            onClick={() => setOpen((v) => !v)}
          >
            {open ? <X size={20} /> : <Menu size={20} />}
          </button>
        </div>
      </div>
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
