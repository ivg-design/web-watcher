import "@/styles/download.css";
import Link from "next/link";
import { asset, FORGE_LINKS, REPO_URL } from "@/lib/config";

const col = (title: string, items: { label: string; href: string; ext?: boolean }[]) => (
  <div>
    <p className="footer__t">{title}</p>
    <ul>
      {items.map((i) => (
        <li key={i.label}>
          {i.ext || i.href.startsWith("http") ? (
            <a href={i.href} target="_blank" rel="noopener noreferrer">{i.label}</a>
          ) : (
            <Link href={asset(i.href)}>{i.label}</Link>
          )}
        </li>
      ))}
    </ul>
  </div>
);

export default function Footer() {
  return (
    <footer className="footer paper">
      <div className="container footer__grid">
        <div className="footer__brand">
          <img src={asset("/images/webwatcher-icon.png")} alt="" aria-hidden="true" width={28} height={28} />
          <strong className="nw">WebWatcher</strong>
          <p>A menu-bar page watcher for macOS by <span className="nw">IVG Design</span>.</p>
          <p className="footer__facts"><span className="nw">macOS 13+</span> · <span className="nw">Apple Silicon</span> · MIT</p>
          <p style={{ marginTop: 8 }}>© 2026 <span className="nw">IVG Design</span></p>
        </div>
        {col("Product", [
          { label: "How it works", href: "/#how-it-works" },
          { label: "Picker", href: "/#picker" },
          { label: "Watch types", href: "/#watch-types" },
          { label: "Gmail", href: "/#gmail" },
          { label: "Download", href: "/#download" },
          { label: "Changelog", href: "/changelog" },
          { label: "Privacy", href: "/#privacy" },
        ])}
        {col("Help", [
          { label: "Setup & permissions", href: "/docs/permissions" },
          { label: "Finding the element", href: "/docs/finding-the-element" },
          { label: "Example watchers", href: "/docs/example-watchers" },
          { label: "Troubleshooting", href: "/docs/troubleshooting" },
          { label: "Building from source", href: "/docs/building-from-source" },
        ])}
        {col("Resources", [
          { label: "GitHub", href: REPO_URL },
          { label: "Report an issue", href: `${REPO_URL}/issues` },
          { label: "Rive community", href: "https://community.rive.app/" },
        ])}
        {col("More from Forge", FORGE_LINKS.map((l) => ({ label: l.label, href: l.href })))}
      </div>
    </footer>
  );
}
