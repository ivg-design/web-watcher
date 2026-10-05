import { readFileSync } from "node:fs";
import { join } from "node:path";
import { BASE_PATH } from "./config";
import { renderInline, renderMarkdown, type Heading } from "./markdown";

export interface DocMeta { slug: string; title: string; summary: string }
export interface DocSection { title: string; docs: DocMeta[] }

export const DOC_SECTIONS: DocSection[] = [
  { title: "Getting started", docs: [
    { slug: "install", title: "Install", summary: "What your Mac needs, how to install and verify the download, and how to update." },
    { slug: "permissions", title: "Permissions", summary: "The Safari setting and the two macOS permissions: what each is for and how to grant it." },
    { slug: "first-watcher", title: "Your first watcher", summary: "The shortest path from an open Safari page to a watcher that checks on its own." },
  ] },
  { title: "Watching pages", docs: [
    { slug: "finding-the-element", title: "Finding the element", summary: "How the Page, Element and Confirm steps choose what a watcher reads." },
    { slug: "scan-vs-pick", title: "Scan or pick", summary: "When to use the automatic scan list and when to use Pick in Safari." },
    { slug: "watch-types", title: "Watch types", summary: "What counts as a change: a number rising, text changing, an element appearing, or anything changing inside." },
    { slug: "site-profiles", title: "Site profiles", summary: "Built-in recipes for LinkedIn, Reddit, Rive Community and Contra, and a tab-title option for any site." },
    { slug: "force-refresh", title: "Force refresh and hidden tabs", summary: "Why a watcher reads a stale value and how to make WebWatcher reload the tab." },
    { slug: "example-watchers", title: "Example watchers", summary: "Five complete watchers with every field value: Contra, Reddit, LinkedIn, Rive Community and GitHub." },
  ] },
  { title: "Gmail", docs: [
    { slug: "sign-in-with-google", title: "Sign in with Google", summary: "Connect a Google account, what access it grants, and how to use your own OAuth client." },
    { slug: "sender-and-domain-watchers", title: "Sender and domain watchers", summary: "Create a watcher for an address or a domain, and what its notification and buttons do." },
    { slug: "notification-templates", title: "Notification templates", summary: "Placeholders and defaults for the title and body of email notifications." },
    { slug: "gmail-limitations", title: "Gmail limits", summary: "Inbox only, Gmail only, the polling delay, the 25-message window and Testing-mode expiry." },
  ] },
  { title: "Notifications", docs: [
    { slug: "custom-notifications", title: "Custom notifications", summary: "Set an icon, title, body and sound for each page watcher, and preview the result." },
    { slug: "herald-delivery", title: "Herald delivery", summary: "Send notifications to Herald for banners that stay on screen, with action buttons." },
  ] },
  { title: "Reference", docs: [
    { slug: "settings", title: "Settings", summary: "Every control in the Settings window, with its default and when to change it." },
    { slug: "watcher-options", title: "Watcher options", summary: "Every field in the page watcher editor and the Gmail sender editor." },
    { slug: "data-and-privacy", title: "Data and privacy", summary: "Every file and Keychain item WebWatcher stores, and everything it connects to." },
    { slug: "troubleshooting", title: "Troubleshooting", summary: "Every status and error message WebWatcher shows, with its cause and fix." },
    { slug: "building-from-source", title: "Building from source", summary: "Build with Swift Package Manager or Xcode, and embed a Google client for built-in sign-in." },
  ] },
];

export const ALL_DOCS: (DocMeta & { section: string })[] = DOC_SECTIONS.flatMap((s) =>
  s.docs.map((d) => ({ ...d, section: s.title })),
);

export interface RenderedDoc {
  meta: DocMeta & { section: string };
  html: string;
  lede: string;
  headings: Heading[];
  prev: DocMeta | null;
  next: DocMeta | null;
}

export function getDoc(slug: string, basePath = BASE_PATH): RenderedDoc | null {
  const i = ALL_DOCS.findIndex((d) => d.slug === slug);
  if (i < 0) return null;
  const src = readFileSync(join(process.cwd(), "content", "docs", `${slug}.md`), "utf8");
  // A leading plain paragraph is the page lede; the rest is the body.
  const m = src.match(/^\s*([^#>\-*|`\d!\s][^\n]*(?:\n[^\n#>\-*|`!][^\n]*)*)\n\n([\s\S]*)$/);
  const lede = m ? renderInline(m[1]) : "";
  const { html, headings } = renderMarkdown(m ? m[2] : src, basePath);
  return { meta: ALL_DOCS[i], html, lede, headings, prev: ALL_DOCS[i - 1] ?? null, next: ALL_DOCS[i + 1] ?? null };
}

export interface SearchItem { title: string; slug: string; section: string; heading?: string; id?: string }

export function getSearchIndex(): SearchItem[] {
  const out: SearchItem[] = [];
  for (const d of ALL_DOCS) {
    out.push({ title: d.title, slug: d.slug, section: d.section });
    const doc = getDoc(d.slug);
    doc?.headings.forEach((h) => out.push({ title: d.title, slug: d.slug, section: d.section, heading: h.text, id: h.id }));
  }
  return out;
}
