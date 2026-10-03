import Link from "next/link";
import SiteHeader from "@/components/SiteHeader";
import { asset } from "@/lib/config";

export const metadata = { title: "Nothing to watch here" };

/** 404 in the page's own terms: the count that never changed. */
export default function NotFound() {
  return (
    <>
      <SiteHeader />
      <main className="night" style={{ minHeight: "calc(100dvh - 64px)", display: "grid", alignItems: "center" }}>
        <div className="container" style={{ paddingBlock: "clamp(64px, 10vw, 120px)" }}>
          <p className="t-wide t-num" aria-hidden="true" style={{ fontSize: "clamp(120px, 26vw, 340px)", color: "var(--n-ink)", opacity: 0.5, marginLeft: "-0.04em" }}>(0)</p>
          <h1 className="h2-v3" style={{ marginTop: 8 }}>Nothing to watch here.</h1>
          <p style={{ marginTop: 20, fontSize: 20, lineHeight: 1.45, color: "var(--n-ink-2)", maxWidth: "34em" }}>
            This page does not exist, so its count will never change. <span className="nw">WebWatcher</span> would tell you the same thing.
          </p>
          <p style={{ marginTop: 32, display: "flex", gap: 12, flexWrap: "wrap" }}>
            <Link className="btn btn--primary" href={asset("/")}>Back to the start</Link>
            <Link className="btn btn--ghost" href={asset("/docs")}>Read the docs</Link>
          </p>
        </div>
      </main>
    </>
  );
}
