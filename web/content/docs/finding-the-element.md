This page is for anyone adding a page watcher. It explains the three steps of the **Which element?** assistant, what each screen means, and what to do when a page is awkward. You never type a selector, because the assistant works one out from what you pick.

## How the assistant works

The **Which element?** assistant is part of the **Add Watcher** and **Edit Watcher** windows. It has three steps, shown as **1 · Page**, **2 · Element** and **3 · Confirm**. A completed step is a link, so you can click it to go back.

| Step | What it is for | You finish it by |
|---|---|---|
| 1 · Page | Finds the Safari tab that shows your page. | Entering a URL. The assistant moves on when it finds the tab. |
| 2 · Element | Chooses the part of the page to watch. | Clicking **Use** on a row, or picking in Safari. |
| 3 · Confirm | Reads the element live and shows what WebWatcher will track. | Checking the reading, then clicking **Save**. |

## Step 1: Page

This step connects the watcher to a tab. Open the page in Safari first, and sign in if it needs a login. WebWatcher reads the tab you already have.

![The Add Watcher window with step 1 Page open: a URL field and a status line under it](/shots/add-watcher-page.png "The URL field and the status line under it belong to **1 · Page**.")

1. Type or paste the URL into the field under **1 · Page**.

   **You see:** "Looking for the page in Safari…", then "Found in Safari: Feed | Rive Community", with the title of your tab. " · background tab" is added when the tab is not the one in front.

2. If the line reads "Not open in Safari", click **Open it**.

   **You see:** "Opening the page in Safari…", then the found line.

The assistant then moves to step 2 by itself. Safari can unload a tab that stays in the background; the tab then shows as `about:blank`. The assistant reports "Tab unloaded — reloading…" and reloads the tab in place before it scans.

## Step 2: Element

This step turns what you see on the page into a selector. You have two helpers, and [Scan or pick](/docs/scan-vs-pick) explains which to prefer. The assistant scans the page for you as soon as the tab is found, and **Rescan** runs the scan again.

![Step 2 Element with the Pick in Safari and Rescan buttons and the candidates in three groups](/shots/add-watcher-element.png "**Pick in Safari** and **Rescan** sit above the list. Each row has an eye button and **Use**.")

### The scan list

The scan groups what it found under three headings.

| Group | What is in it |
|---|---|
| Showing a number now | Elements that show a count today, such as an unread badge or a number in an attribute or label. |
| Could get a badge later | Icons and buttons that show no counter yet, but could get one. |
| Other | Everything that is not a number: a price, text, the page title, or an element that may appear. |

Each row shows the value or label, a line of detail and two controls.

| Control | What it does |
|---|---|
| Eye button | Highlights the element in the Safari tab so you can check it is the right one. |
| Use | Chooses the element. |

If nothing in the page looks like a counter, the list is replaced by a note that suggests **Pick in Safari**.

### Pick in Safari

Use **Pick in Safari** when the scan does not list your element.

1. Click **Pick in Safari**.

   **You see:** "Click the element in Safari — press Esc to cancel."

2. In Safari, point at the element and click it.

   **You see:** an outline on the element and a toolbar at the bottom of the page. The assistant shows "Selected:" and the element's name.

3. If the outline is on the wrong element, move it with the keys in the next table.
4. Press <kbd>⏎</kbd> in Safari, or click **Use this** in WebWatcher.

   **You see:** the assistant moves to step 3.

The pick ends with "No click after 90 seconds — try again" if you do not click.

| Key | What it does |
|---|---|
| <kbd>↑</kbd> | Moves the outline to the parent element. It stops at the page body. |
| <kbd>↓</kbd> | Moves the outline to the first child. |
| <kbd>←</kbd> <kbd>→</kbd> | Moves the outline to the previous or next sibling. |
| <kbd>⏎</kbd> | Uses the outlined element. |
| <kbd>⎋</kbd> | Cancels the pick. |

The toolbar in Safari lists the same keys and has **Use this element** and **Cancel** buttons. **Use this** in WebWatcher always works, even when the page blocks scripted key presses.

### How should WebWatcher watch it?

When an element could be watched in more than one way, a card named "How should WebWatcher watch it?" lists the choices. The first is marked "Recommended". Select one and click **Continue**.

| Choice | What it does |
|---|---|
| Track the number | Notifies when the number changes. |
| A number appears next to it | Starts at zero and notifies when a number shows up. |
| The text changes | Notifies when the text changes. |
| The count changes | Notifies when the number of matching elements changes. |
| It appears or disappears | Notifies when the element shows up or goes away. |
| Anything changes inside it | Notifies on any change inside the element. On some elements the choice reads "Anything changes inside". |

Which choices you get depends on the element. For an icon with no counter yet, such as a bell, choose "Anything changes inside it" or "A number appears next to it". [Watch types](/docs/watch-types) describes the resulting types.

## Step 3: Confirm

This step reads the element live before you save, so you find a wrong pick before the first notification.

![Step 3 Confirm with the watched text, the current reading, the list of checks and the Test again and Change element links](/shots/add-watcher-confirm.png "The text under **Editing** says what is watched. The box below it shows each check as passed or failed.")

You see three things in order: the page and a **Change** link that goes back to step 1, a summary of what will be watched, such as "Watching the text "$129.00"", and a box with the reading and the checks.

| Control | What it does |
|---|---|
| Test again | Reads the element again. |
| Change element | Returns to step 2. |
| Save | Saves the watcher and runs the first check. |

### What the Confirm checks mean

The top line of the box is the reading. A green mark shows that the check passed and a red mark that it failed.

| Line | What it means |
|---|---|
| Current reading: 3 | The value WebWatcher read from the element at this moment. |
| Confirmed zero — the anchor is present and there's no badge. | The element is absent and an anchor proves the page loaded, so the count is zero. |
| Snapshot taken — you'll be notified when anything inside changes. | A watcher for changes inside the element recorded its starting state. |
| Safari running | Safari is open. |
| Tab found | A Safari tab matches the URL. The line below it shows the matched URL. |
| Element found | The selector matches an element. The line below shows the selector. |
| Page loaded | The page finished loading. |
| Anchor found | The always-present element next to the badge is on the page. |
| Signed in | No sign-in link is showing, so the page is your signed-in view. |
| Title count | The number was found at the start of the tab title. |
| Count in label | The number was found in the element's accessibility label. |
| Badge present | The number was found in the badge element. |
| Number near anchor | The number was found beside the anchor. |
| Elements matched | The number of elements the selector matches, for a count watcher. |
| Fingerprint | The number of elements inside the watched area, such as "212 elements". |
| Zero can be confirmed | Shown for a Badge/Number watcher. It fails with "No anchor set — a missing badge is ambiguous" when no anchor is set. See below. |
| Read from a background tab | The tab was hidden. The line below tells you whether Force refresh is on. |

Two lines need action.

- **Zero can be confirmed fails.** Without an anchor, WebWatcher cannot tell a badge that is gone from a page that did not load. Set an anchor in **Advanced**, described in [Watcher options](/docs/watcher-options).
- **Fingerprint above 150 elements.** A warning reads "This area has 212 elements — a busy container may notify more often than you want. Consider picking a smaller part (↑/↓ in Safari)." Go back and pick a smaller part.

## When there is no badge yet

For a bell or an icon that shows nothing until something happens, pick the icon itself and choose "Anything changes inside it". WebWatcher records the contents of the element and notifies when anything appears inside.

## Enter a selector by hand

Use this only when neither helper reaches the element. The selector goes in the **Advanced** section of the editor.

1. In Safari, choose **Develop > Show Web Inspector**.
2. Click the element picker tool in the Web Inspector, then click the element on the page.
3. Right-click the highlighted node, then choose **Copy > Copy Selector**.
4. In the WebWatcher editor, click **Advanced** to expand it.
5. If **Strategy** shows a value, click **Clear** next to it.
6. Paste the selector into **CSS Selector**.

   **You see:** the selector in the field. Click **Save**, and the watcher is checked at once.

## If it does not work

| What you see | Cause | Fix |
|---|---|---|
| "That element is inside an embedded frame WebWatcher can't reach — pick something outside it." | The element is in a cross-origin iframe, which Safari does not let a page script enter. | Pick an element outside the frame. |
| The element is in the page but never listed or outlined. | It sits inside a closed shadow root, which no script can read. | Pick the element that holds it, and choose "Anything changes inside". |
| "The Safari tab changed before you clicked — try again." | You navigated away during the pick. | Click **Pick in Safari** again. |
| "Tab unloaded — reloading…", then "Safari keeps unloading this tab — switch to it in Safari, then try again." | Safari unloaded the tab and it did not come back. | Switch to the tab in Safari, then click **Test again**. |
| "Still loading after 15 seconds — try again." | The page loads slowly or is stuck. | Wait for the page to finish, then try again. |
| "Open example.com in Safari first." | The page is not open and the watcher may not open it itself. | Open the page in Safari. |
