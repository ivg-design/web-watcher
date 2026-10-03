export type NodeId =
  | "title" | "topbar" | "brand" | "inbox" | "bell" | "badge"
  | "feed" | "item1" | "item2" | "item3";

export interface PageNode {
  id: NodeId;
  label: string;
  selector: string;
  strategy: "Badge count" | "Text change" | "Subtree change" | "Document title";
  value: string;
  parent: NodeId | null;
  children: NodeId[];
}

const n = (
  id: NodeId, label: string, selector: string, strategy: PageNode["strategy"], value: string,
  parent: NodeId | null, children: NodeId[] = [],
): PageNode => ({ id, label, selector, strategy, value, parent, children });

/** The simulated page's element tree (title lives outside the DOM tree: it is document.title). */
export const NODES: Record<NodeId, PageNode> = {
  title: n("title", "Page title", "document.title", "Document title", "(3) Feed — Rive", null),
  topbar: n("topbar", "Top bar", "header.topbar", "Subtree change", "4 children", null, ["brand", "inbox", "bell"]),
  brand: n("brand", "Site name", "header.topbar › a.brand", "Text change", "Rive Community", "topbar"),
  inbox: n("inbox", "Inbox link", "a[href='/inbox']", "Text change", "Inbox (12)", "topbar"),
  bell: n("bell", "Notifications bell", "button.nav-bell", "Subtree change", "2 children", "topbar", ["badge"]),
  badge: n("badge", "Bell badge", "button.nav-bell › span.badge", "Badge count", "3", "bell"),
  feed: n("feed", "Feed list", "main › ul.feed", "Subtree change", "48 items", null, ["item1", "item2", "item3"]),
  item1: n("item1", "Newest post", "ul.feed › li:nth-child(1)", "Text change", "Ana: Bones in nested artboards?", "feed"),
  item2: n("item2", "Second post", "ul.feed › li:nth-child(2)", "Text change", "Kofi: Data binding lists", "feed"),
  item3: n("item3", "Third post", "ul.feed › li:nth-child(3)", "Text change", "Mei: Luau pointer events", "feed"),
};

/** What Scan page finds, ranked. The badge is the best match. */
export const CANDIDATES: { id: NodeId; title: string; chip: string; best?: boolean }[] = [
  { id: "badge", title: "Notifications bell · badge “3”", chip: "badge count", best: true },
  { id: "inbox", title: "Inbox link · “Inbox (12)”", chip: "text with number" },
  { id: "title", title: "Page title · “(3) Feed — Rive”", chip: "document title" },
  { id: "feed", title: "Feed list · 48 children", chip: "subtree change" },
];

/** Nodes that can be walked to in the in-page picker (everything inside the page DOM). */
export const DOM_ROOTS: NodeId[] = ["topbar", "feed"];

export function siblings(id: NodeId): NodeId[] {
  const p = NODES[id].parent;
  return p ? NODES[p].children : DOM_ROOTS;
}
