# WebWatcher docs: style guide

One page. Every file in `content/docs/*.md` follows it. The renderer is `src/lib/markdown.ts`, the styles are
at the end of `src/styles/docs.css`.

## What the docs are

The docs describe WebWatcher as it is now, in the present tense. They are not a changelog. No "new in",
"since", "as of", "previously", "used to", "no longer", "replaces", no migration notes and no "what's new"
sections. No version numbers except the system requirement (macOS 13) and a version the reader must type.
History lives on `/changelog`; a page may link to it once. `tests/docs.mjs` fails on these patterns.

## Page shape

1. The first paragraph (it becomes the lede) says what the page covers and who needs it. One paragraph, no heading.
2. Concepts in plain words come before any list of settings: what the thing is, why it exists, when you use it.
3. Then the body in one of the three shapes below. Headings go `##` then `###`, never skipping a level, sentence case.
4. No section holds a single line. Fold it into its neighbour or give it the explanation it lacks.
5. A page that asks the reader to do something ends with `## If it does not work`.

## How-to shape

- A numbered list, one action per step. Every ordered list renders as a step list, so use one only for a procedure.
- Name the exact control in bold: `**Add Watcher**`. A menu or settings path is bold with ` > ` between the
  parts: `**Settings > Notifications > Delivery**`. Keys are `<kbd>↑</kbd>`.
- After a step whose effect is visible, add an indented line that starts with `**You see:**`.
- Close with `## If it does not work`: a table of symptom, cause and fix, or a link to the Troubleshooting section.

```markdown
1. Click the WebWatcher icon in the menu bar, then **Add Watcher**.

   **You see:** the Add Watcher window on its Page step.
```

## Settings and options shape

A table with the columns `Setting | What it does | Default | When to change it`. Every cell is a short full
sentence. When choosing between options, the columns are `Option | What it does | Choose it when`. If one
setting needs more room than a cell, give it a `###` heading with a paragraph and keep the table for the rest.

## Reference shape (selectors, placeholders, files, commands, permissions)

One item per block: a `###` heading, one sentence saying what it is for, a table of its fields, a minimal valid
example in a fenced block, then a realistic example. Never put a list of fields or options in a sentence.

## Callouts

One convention, a blockquote whose first words are the kind in bold:

```markdown
> **Note.** Extra context that is true for everyone.
> **Tip.** A shortcut or a better way.
> **Warning.** Something that loses data, breaks a watcher or surprises the reader.
```

At most two per page. A callout never carries a step or a setting.

## Tables and code

- No horizontal scrolling at 1440, 1280, 1024, 834 and 390 (`tests/docs-no-hscroll.mjs`). Tables have at most
  four columns and restack into labelled cards on phones. Long tokens go in backticks so they can break.
- Every fenced block has a language: `bash` (rendered on graphite with a `$` prompt, so do not type the
  prompt), `json`, `css`, `xpath`, `text`. Words after the language become the block's label: ` ```json watchers.json `.
- Examples are real and valid: a selector that the app accepts, a path that exists, a string the app shows.

## Language

- Plain, grammatical, factual. Say why as well as what. Second person, present tense, active voice.
- No marketing words (simple, powerful, seamless, just, easily), no time or effort estimates, no em dashes.
- Proper nouns exact: WebWatcher, Herald, Safari, Finder, Gmail, IVG Design, Notification Center, System Settings.
- UI strings exactly as the app shows them, in bold for controls and in double quotes for messages. A quoted
  message keeps the app's own punctuation, which is the only place an em dash or an arrow may appear.
- Never a real secret, OAuth client id, email address or personal data. Use `you@example.com`, `@example.com`,
  `YOUR_CLIENT_ID`.

## Truth

Every statement is checked against `Sources/WebWatcher/**`. If the code and the page disagree, the code wins
and the contradiction is recorded in `.reviews/docs-restructure-inventory.md`.

## Figures

A page that describes something the reader sees shows it: each Settings group, the menu bar popover, the Add
Watcher steps, the editors, a notification. The figure comes directly after the sentence that introduces the
thing, and a how-to has one at each step where the screen changes.

```markdown
![Alt text: what the image contains, for someone who cannot see it](/shots/settings-general.png "Caption: what to look at, with **control names** as the image shows them.")
```

- Only the real captures in `public/shots/`, which are made from the current source and arrive framed on a
  gradient with a shadow. `public/shots/manifest.json` lists each one (file, 2x file, size, appearance, a `shows`
  sentence). Never edit, reframe or generate an image. If the manifest has no image for something a page
  describes, the page goes without and the shot goes on the wish-list in `.reviews/docs-restructure-inventory.md`
  (page, sentence, window, state).
- Names in the text match the labels visible in the image, character for character.
- The alt text describes the image; the caption (the quoted title) tells the reader what to look at. They differ.
- The renderer reads the manifest: it sets width and height (no layout shift), serves 1x and 2x, pairs a
  `name-dark.png` with its light twin, lazy-loads, and opens the 2x file in a dialog when the image is clicked.
  The figure adds no background, border or shadow of its own. Do not write `<img>` by hand.
