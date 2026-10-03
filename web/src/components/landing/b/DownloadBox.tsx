"use client";

import "@/styles/download.css";
import { useEffect, useRef, useState } from "react";
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
    <div className="dlx__frame">
      <div className="dlx__box">
        <div className="dlx__head">
          <img src={asset("/images/webwatcher-icon-tile.png")} alt="" aria-hidden="true" width={56} height={56} />
          <div className="dlx__ver">
            <b><span className="nw">WebWatcher</span> <span className="nw">{release.version}</span></b>
            <span><span className="nw">Build {release.build}</span>, {release.monthYear}, DMG, {release.sizeMb}</span>
          </div>
        </div>
        <a className="dlx__btn" href={release.dmgUrl} data-forge-action="download_intent" data-testid="dl-btn" onClick={onStart}>
          <span>{starting ? "Starting download…" : "Download for Mac"}</span>
        </a>
        <span className="sr-only" role="status" data-testid="dl-status">{starting ? "Starting download…" : copied ? "Copied" : ""}</span>
        <p className="dlx__fine"><span className="nw">Apple Silicon</span> (arm64) only. <span className="nw">macOS 13</span> or later.</p>
        <div className="dlx__links">
          {release.sha ? (
            <button type="button" className="dlx__sha" data-testid="dl-sha" onClick={onCopy} title={release.sha}>
              <span className="dlx__mk" aria-hidden="true">{copied ? "✓" : "⧉"}</span>
              <span>{copied ? "Copied" : <>Copy <span className="nw">SHA-256</span> checksum</>}</span>
            </button>
          ) : (
            <a href={release.shaUrl} target="_blank" rel="noopener noreferrer"><span className="nw">SHA-256</span> checksum</a>
          )}
          <a href={RELEASES_URL} target="_blank" rel="noopener noreferrer"><span>All releases on <span className="nw">GitHub</span> ↗</span></a>
          <a href={asset("/docs/building-from-source")}>Build from source: swift build / Xcode</a>
        </div>
      </div>
    </div>
  );
}
