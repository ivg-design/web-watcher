A watch type tells WebWatcher what counts as a change in the element you picked: a number going up, text changing, an element appearing, or anything at all happening inside an area. Read this page when the picker chose a type you do not want, or when a watcher notifies too often or not at all.

The element picker sets the watch type for you at the **Confirm** step, from what it found on the page. You can change it afterwards in the watcher's editor.

## Choose a watch type

Open the watcher's editor (see [Watcher options](/docs/watcher-options)) and find **Watch Type**. The line under the picker describes the selected type.

![The Edit Watcher window for a price watcher: Check Interval set to 5 minutes and Watch Type set to Text Change with the line Notify when the text content changes](/shots/watcher-editor.png "**Watch Type** is below **Check Interval**. The line under it explains what the selected type does.")

| Type | What it reads | It notifies when | Choose it when |
|---|---|---|---|
| Badge/Number | A number from the element, such as an unread count. | The number goes up. | You want to know about new messages or notifications. |
| Element Count | How many elements match the selector. | The count goes up. | You watch a list that grows, such as rows in a table. |
| Text Change | The text inside the element. | The text differs from the last check. | The element shows a status or a headline, not a number. |
| Element Exists | Whether the element is on the page. | The element appears. | A banner, a button or an indicator shows up when something happens. |
| Element Disappears | Whether the element is on the page. | The element goes away. | The thing you wait for is the end of something, such as a "Processing" notice. |
| Anything Changes Inside | A fingerprint of everything inside the element. | The fingerprint changes. | The element shows no number, such as a bell icon with no badge. |

Two rules apply to every type:

- The first reading is a baseline. A Badge/Number, Element Count, Text Change or Anything Changes Inside watcher does not notify on its first successful check, so you are not alerted about what was on the page before.
- A check that cannot run never counts as a change. A watcher that cannot read the page keeps its last good reading and notifies only when a later check succeeds and differs. See [Troubleshooting](/docs/troubleshooting).

At the **Confirm** step the picker offers only the choices that fit the element. [Finding the element](/docs/finding-the-element#how-should-webwatcher-watch-it) lists them. The choice **It appears or disappears** sets Element Exists. Element Disappears is available only from the **Watch Type** picker.

### Badge/Number

Badge/Number extracts a number from the element and compares it with the last reading. Thousands separators such as `1,281` are read as one number.

![The Edit Watcher window for a forum bell: the Confirm card reads Watching 0, zero confirmed by anchor, and Watch Type is Badge/Number](/shots/watcher-editor-badge.png "A Badge/Number watcher that reads zero. The Confirm card says the zero is confirmed by the anchor.")

- When the site shows a capped badge such as `9+`, WebWatcher treats it as "at least 9". A reading that stays at `9+` does not notify, because the site is not showing a change.
- A reading of zero is stored like any other number. The watcher notifies when the number rises above its previous value, for example from 0 to 2.

### Element Count

Element Count counts every element that matches the selector and notifies when the total rises. A drop in the count does not notify. Use it for lists, search results or any set where "more than before" is the event.

### Text Change

Text Change compares the element's text with the previous reading. The row in the menu shows the first 30 characters of the current text, and the notification shows up to 100 characters of it as its subtitle.

### Element Exists and Element Disappears

Both types read whether the element is on the page. Element Exists notifies on the first check that finds the element, and again each time it comes back after being absent. Element Disappears notifies only when the element was present on one check and absent on the next.

### Anything Changes Inside

Anything Changes Inside is for elements that never show a count: a bell icon with no badge, a status area, a feed. WebWatcher takes a fingerprint of the whole element, including its text and the elements within it, and notifies when the fingerprint changes. You are told that something changed, not what.

![The Edit Watcher window for a bell with no number: the Confirm card reads Watching for any change inside .header-bell and Watch Type is Anything Changes Inside](/shots/watcher-editor-anything-changes.png "With **Anything Changes Inside** the Confirm card names the area that is watched instead of a value.")

The type has one weakness. A busy container, one with many descendants, timestamps that tick or counters you do not care about, changes its fingerprint all the time and notifies more often than you want.

To fix a noisy watcher:

1. Open the watcher's editor and re-pick the element in the **Which element?** section.
2. Scan the page or pick in Safari, then at the **Confirm** step choose **Anything changes inside**.

   **You see:** a warning such as "This area has 212 elements — a busy container may notify more often than you want." The warning appears when the area holds more than 150 elements.

3. While you pick in Safari, press <kbd>↑</kbd> or <kbd>↓</kbd> to select a smaller area, then confirm it.

A smaller area, such as the bell button alone instead of the whole header, changes only when the thing you care about changes. [Finding the element](/docs/finding-the-element) explains the picker keys.

## Reading strategies

A Badge/Number watcher reads its number with one of four strategies. The strategy decides how the page is searched and how WebWatcher tells a real zero from a page that failed to load.

You see the strategy in the editor. Expand **Advanced** and find the **Strategy** row. It shows the strategy's name, or "Manual" when none is set, and it is read-only. **Clear** resets it to "Manual", which makes WebWatcher use your selector exactly as typed.

| Strategy | How it reads the number | The picker chooses it when |
|---|---|---|
| Accessibility label | Reads the number from the element's own accessibility label, for example "Notifications, 4 new notifications". Zero is stated by the site. | The element you picked carries a label that contains the count. |
| Anchor + badge | Looks for a badge next to an element that is always on the page, called the anchor. Anchor present and badge absent is a confirmed zero. | The picker finds a number inside or beside a stable element. |
| Tab title (N) | Reads the `(3)` that many sites put at the start of the Safari tab title. It needs no selector. | The tab title starts with a number in parentheses. |
| Anchor + any number | Looks for any number that appears next to the anchor. Anchor present with no number is a confirmed zero. | You pick a button or link that currently shows no number, because the badge disappears entirely at zero. |

A built-in [site profile](/docs/site-profiles) preselects the right strategy for its site. The other watch types have no strategy, so their **Strategy** row reads "Manual".

> **Tip.** If a Badge/Number watcher reports "Can't confirm — no anchor set", add an anchor in **Advanced** or re-pick the element so the picker sets one. Without an anchor, WebWatcher cannot tell zero from a page that failed to load.

## If it does not work

| What you see | Cause | Fix |
|---|---|---|
| The watcher never notifies. | The first reading is only a baseline, or the value has not risen. | Wait for a change, then check the row's status in the popover. |
| An Anything Changes Inside watcher notifies constantly. | The area is a busy container. | Pick a smaller area, as described above. |
| An Element Count watcher is silent when items disappear. | Element Count notifies only when the count rises. | Use Anything Changes Inside, or Text Change on a summary element. |
| The row shows "Can't confirm — no anchor set". | A Badge/Number watcher has no anchor, so a missing badge is ambiguous. | Add an anchor in **Advanced**, or re-pick the element. |

[Troubleshooting](/docs/troubleshooting) lists every message a watcher row can show.
