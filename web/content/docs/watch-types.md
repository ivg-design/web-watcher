A watch type says what counts as a change. The picker chooses one for you from what it sees, and you can change it by hand.

## The types

| Type | What it does |
|------|--------------|
| Badge/Number | Extracts a numeric value, such as an unread count or notification badge. Notifies when it rises and shows the count. |
| Element Count | Counts how many elements match the selector. |
| Text Change | Notifies when the text content changes and shows old → new. |
| Element Exists | Notifies when an element appears. |
| Element Disappears | Notifies when an element is removed. |
| Anything Changes Inside | Notifies when anything inside the element changes: a badge appears, text updates, items are added. |

## Subtree change

Anything Changes Inside is the watch type for elements that show no count at all: a bell icon with no badge, a status area, anything where "something happened" is all you need. It fingerprints the element's subtree and notifies when that fingerprint changes.

A busy container (lots of descendants, frequently updating timestamps, live counters unrelated to what you care about) can notify more often than you want. WebWatcher warns you in the Confirm step when the picked area has a large number of elements, and picking a smaller part, with ↑ and ↓ while picking, usually fixes it.

## Reading strategies

Under the hood a badge watcher reads the value in one of four ways. Site profiles preselect the right one.

- **Accessibility label.** Reads the number from the element's aria-label. Most reliable when the site provides it, because zero is stated explicitly.
- **Anchor + badge.** Watches a badge next to an always-present anchor. Anchor present and badge absent is a confirmed zero.
- **Tab title (N).** Reads the `(3)` prefix most sites put in the tab title. Needs no selector and survives redesigns.
- **Anchor + any number.** Watches for any number that appears next to the anchor. Use it when the badge disappears entirely at zero.
