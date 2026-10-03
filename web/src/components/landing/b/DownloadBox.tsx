"use client";

import { useEffect, useRef, useState } from "react";
import { Check, Copy, Download } from "lucide-react";
import { RELEASES_URL, asset } from "@/lib/config";
import type { LatestRelease } from "@/lib/release";

export default function DownloadBox({ release }: { release: LatestRelease }) {
  const [copied, setCopied] = useState(false);
  const t = useRef<number>(0);
  useEffect(() => () => window.clearTimeout(t.current), []);

  const onCopy = async () => {
    if (!release.sha) return;
    try {
      await navigator.clipboard.writeText(release.sha);
    } catch {
      return;
    }
    setCopied(true);
    window.clearTimeout(t.current);
    t.current = window.setTimeout(() => setCopied(false), 1600);
  };

  return (
    <div className="dl__box">
      <img src={asset("/images/webwatcher-icon.png")} alt="" width={44} height={44} />
      <div className="dl__ver">
        WebWatcher {release.version} · Build {release.build} · {release.monthYear}
      </div>
      <a className="btn btn--dark btn--block" href={release.dmgUrl} data-forge-action="download_intent">
        <Download size={18} aria-hidden="true" />
        {`Download for Mac · DMG · ${release.sizeMb}`}
      </a>
      <p className="dl__fine">Apple Silicon (arm64) only · macOS 13 or later</p>
      <div className="dl__small">
        {release.sha ? (
          <button type="button" className="sha" data-testid="dl-sha" onClick={onCopy} title={release.sha}>
            {copied ? <Check size={16} aria-hidden="true" className="sha__ok" /> : <Copy size={16} aria-hidden="true" />}
            {copied ? "Copied" : "Copy SHA-256 checksum"}
            <span className="sr-only" aria-live="polite">{copied ? "Checksum copied" : ""}</span>
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
