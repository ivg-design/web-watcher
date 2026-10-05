import { readFileSync } from "node:fs";
import { join } from "node:path";
import { BASE_PATH } from "./config";
import { renderInline, renderMarkdown, type Heading } from "./markdown";

export interface DocMeta { slug: string; title: string; summary: string }
export interface DocSection { title: string; docs: DocMeta[] }

export const DOC_SECTIONS: DocSection[] = [
  { title: "Getting started", docs: [
    { slug: "install", title: "Install", summary: "Download, move to Applications, open from the menu bar." },
    { slug: "permissions", title: "Permissions (3 switches)", summary: "Safari JavaScript from Apple Events, Automation, Notifications." },
    { slug: "first-watcher", title: "Your first watcher", summary: "From open Safari tab to first notification in under a minute." },
  ] },
  { title: "Watching pages", docs: [
    { slug: "finding-the-element", title: "Finding the element", summary: "The assistant walks you Page, Element, Confirm. You never type a selector." },
    { slug: "scan-vs-pick", title: "Scan page vs Pick in Safari", summary: "Two ways to choose what to watch, and when to use each." },
    { slug: "watch-types", title: "Watch types", summary: "Badge number, text change, Anything Changes Inside and the rest." },
    { slug: "site-profiles", title: "Site profiles & recipes", summary: "One click fills in the right strategy, selector and refresh behaviour." },
    { slug: "force-refresh", title: "Force refresh & hidden tabs", summary: "Why Safari background tabs go stale and how WebWatcher handles it." },
    { slug: "example-watchers", title: "Example watchers", summary: "Contra, Reddit, LinkedIn, Rive Community and GitHub, with exact fields." },
  ] },
  { title: "Gmail", docs: [
    { slug: "sign-in-with-google", title: "Sign in with Google", summary: "Built-in OAuth client, smallest scope, tokens in Keychain." },
    { slug: "sender-and-domain-watchers", title: "Sender & domain watchers", summary: "Watch an address, several, or a whole domain with a live unread count." },
    { slug: "notification-templates", title: "Notification templates", summary: "Placeholders for title and body of email notifications." },
    { slug: "gmail-limitations", title: "Limitations", summary: "Inbox only, Gmail only, and a rare domain-watcher edge case." },
  ] },
  { title: "Notifications", docs: [
    { slug: "custom-notifications", title: "Custom icon, title, body", summary: "Make each watcher recognisable at a glance." },
    { slug: "herald-delivery", title: "Herald delivery", summary: "Persistent banners with action buttons through Herald." },
  ] },
  { title: "Reference", docs: [
    { slug: "settings", title: "Settings", summary: "Every control in the Settings window, with its default and when to change it." },
    { slug: "watcher-options", title: "Watcher options", summary: "Every field in the page watcher editor and the Gmail sender editor." },
    { slug: "data-and-privacy", title: "Data & privacy", summary: "What is stored, where, and what the app talks to." },
    { slug: "troubleshooting", title: "Troubleshooting", summary: "Error messages and their fixes." },
    { slug: "building-from-source", title: "Building from source", summary: "swift build, Xcode, and optional Google sign-in." },
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
