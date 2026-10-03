"use client";

import "@/styles/download.css";
import { useEffect, useRef, useState } from "react";
import { Check, Copy, Download } from "lucide-react";
import { RELEASES_URL, asset } from "@/lib/config";
import type { LatestRelease } from "@/lib/release";

export default function DownloadBox({ release }: { release: LatestRelease }) {
  const [copied, setCopied] = useState(false);
  const [starting, setStarting] = useState(false);
  const t = useRef<number>(0);
  const s = useRef<number>(0);
  useEffect(() => () => { window.clearTimeout(t.current); window.clearTimeout(s.current); }, []);

  const onCopy = async () => {
    if (!release.sha) return;
    try {
      await navigator.clipboard.writeText(release.sha);
    } catch {
      // Clipboard API refused (insecure context or no permission): fall back to a selection copy.
      const ta = document.createElement("textarea");
      ta.value = release.sha;
      ta.setAttribute("readonly", "");
      ta.style.cssText = "position:fixed;opacity:0;top:0;left:0";
      document.body.appendChild(ta);
      ta.select();
      const done = document.execCommand("copy");
      ta.remove();
      if (!done) return;
    }
    setCopied(true);
    window.clearTimeout(t.current);
    t.current = window.setTimeout(() => setCopied(false), 1600);
  };
  const onStart = () => {
    setStarting(true);
    window.clearTimeout(s.current);
    s.current = window.setTimeout(() => setStarting(false), 1200);
  };

  return (
    <div className="dlx__box">
      <img src={asset("/images/webwatcher-icon.png")} alt="" width={44} height={44} />
      <div className="dlx__ver">
        WebWatcher {release.version} · Build {release.build} · {release.monthYear}
      </div>
      <a className="dlx__btn" href={release.dmgUrl} data-forge-action="download_intent" data-testid="dl-btn" onClick={onStart}>
        <Download size={18} aria-hidden="true" />
        <span aria-live="polite">{starting ? "Starting download…" : `Download for Mac · DMG · ${release.sizeMb}`}</span>
      </a>
      <p className="dlx__fine">Apple Silicon (arm64) only · macOS 13 or later</p>
      <div className="dlx__links">
        {release.sha ? (
          <button type="button" className="dlx__sha" data-testid="dl-sha" onClick={onCopy} title={release.sha}>
            {copied ? <Check size={16} aria-hidden="true" className="dlx__ok" /> : <Copy size={16} aria-hidden="true" />}
            {copied ? "Copied" : "Copy SHA-256 checksum"}
          </button>
        ) : (
          <a href={release.shaUrl} target="_blank" rel="noopener noreferrer">SHA-256 checksum</a>
        )}
        <a href={RELEASES_URL} target="_blank" rel="noopener noreferrer">All releases on GitHub ↗</a>
        <a href={asset("/docs/building-from-source")}>Build from source: swift build / Xcode</a>
      </div>
    </div>
  );
}
