"use client";

import { useEffect, useRef, useState } from "react";
import { Check, Copy, Download } from "lucide-react";
import { RELEASES_URL, asset } from "@/lib/config";
import type { LatestRelease } from "@/lib/release";

export default function DownloadBox({ release }: { release: LatestRelease }) {
  const [starting, setStarting] = useState(false);
  const [copied, setCopied] = useState(false);
  const t1 = useRef<number>(0);
  const t2 = useRef<number>(0);
  useEffect(() => () => { window.clearTimeout(t1.current); window.clearTimeout(t2.current); }, []);

  const onDownload = () => {
    setStarting(true);
    window.clearTimeout(t1.current);
    t1.current = window.setTimeout(() => setStarting(false), 1200);
  };
  const onCopy = async () => {
    if (!release.sha) return;
    try {
      await navigator.clipboard.writeText(release.sha);
    } catch {
      return;
    }
    setCopied(true);
    window.clearTimeout(t2.current);
    t2.current = window.setTimeout(() => setCopied(false), 1600);
  };

  return (
    <div className="dl__box">
      <img src={asset("/images/webwatcher-icon.png")} alt="" width={44} height={44} />
      <div className="dl__ver">
        WebWatcher {release.version} · Build {release.build} · {release.monthYear}
      </div>
      <a
        className="btn btn--dark btn--block"
        href={release.dmgUrl}
        data-forge-action="download_intent"
        onClick={onDownload}
      >
        <Download size={18} aria-hidden="true" />
        <span aria-live="polite">
          {starting ? "Starting download…" : `Download for Mac · DMG · ${release.sizeMb}`}
        </span>
      </a>
      <div className="dl__small">
        {release.sha ? (
          <button type="button" className="sha" onClick={onCopy} title={release.sha}>
            SHA-256 checksum
            <span className={`flip${copied ? " is-done" : ""}`} aria-hidden="true">
              <Copy className="off" size={16} />
              <Check className="on" size={16} />
            </span>
            <span className="sr-only" aria-live="polite">{copied ? "Copied" : ""}</span>
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
