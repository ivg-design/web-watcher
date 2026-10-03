A site profile is a ready-made recipe for a site: the right strategy, selector and refresh behaviour in one click. Pick the profile in the watcher editor and WebWatcher fills the fields for you.

## Built-in profiles

WebWatcher ships profiles for sites whose badges are known to need special handling:

- **Rive Community** — notifications and messages. The badge node disappears entirely at zero, so the profile uses an anchor plus any number and treats an anchor with no number as a confirmed zero.
- **LinkedIn** — messages and notifications, read from the navigation link's aria-label, which states the count including zero.
- **Reddit** — inbox and chat.
- **Contra** — messages and notifications.
- **Any site with a (N) tab title** — a generic profile that reads the count from the document title and needs no selector.

Profiles match on the tab's host as a suffix, so `www.` and subdomains match, and the most specific match comes first.

## When to use one

If a profile exists for your site, start there: it encodes what already took trial and error. If not, the guided picker works on any page, and the generic tab-title profile covers the many sites that put a count in the title.

## Recipes

A recipe is a profile applied to a watcher. The [Rive Community example](/docs/example-watchers) shows one end to end, including the `anchoredBadge` strategy the built-in recipe already accounts for.
