Both helpers end at the same place — a selector and a watch type — but they start from opposite ends. Scan page starts from the page; Pick in Safari starts from you.

## Scan page

Scan page reads the open tab and groups everything that looks watchable under headings such as "Showing a number now", "Could get a badge later" and "Other". It ranks the likely badge first and marks it as the best match. Click Use on a row and you are done.

Choose Scan page when you are not sure what the page offers, or when the element is a normal badge or counter. It is the quickest route and often the most robust, because it prefers elements the page itself labels.

## Pick in Safari

Pick in Safari draws an outline in the page. Click the thing you care about and nudge the outline with the arrow keys until it sits on the right element. A toolbar in Safari lists the keys and the app has its own Use this button as a fallback.

Choose Pick in Safari when Scan page ranks the wrong thing first, when you want a specific item in a list, or when the element is something a scan would not call watchable, such as a status area.

## Where each one stops

Neither helper can reach an element inside a cross-origin iframe, or one inside a closed shadow root. Pick in Safari tells you when it hits that boundary. See [Troubleshooting](/docs/troubleshooting) for what to do.

## Self-healing

If a page changes its markup later, WebWatcher re-locates the element instead of going quiet, and tells you if it cannot.
