This page is for anyone who has installed WebWatcher and wants a first working watcher: it follows the shortest path from an open Safari page to a watcher that checks on its own. It assumes Safari and the permissions are set up as described in [Permissions](/docs/permissions).

## Add the watcher

A watcher is one saved element of one page. Before you start, open the page in Safari and sign in if it needs a login. WebWatcher reads the tab you already have, so there is no separate login and no extension. The assistant then finds the page, finds the element and shows you what it reads before you save.

1. Click the WebWatcher icon in the menu bar, then **Add Watcher**.

   **You see:** the **Add Watcher** window with two tabs, **Web page** and **Gmail sender**. **Web page** is selected.

2. In **Which element?**, on step **1 · Page**, type or paste the page's URL.

   ![The Add Watcher window on the Web page tab: Site, Name, the Which element? list with step 1 Page open and a URL in its field, Check Interval, Watch Type, Advanced and Notification](/shots/add-watcher-page.png "The **Which element?** assistant starts on **1 · Page**. The line under the URL field tells you what to do next.")

   **You see:** a line such as "Found in Safari: Feed | Rive Community". If the page is not open, the line reads "Not open in Safari" and an **Open it** link appears. When the tab is found, the assistant moves to step **2 · Element** by itself.

3. On step **2 · Element**, choose the element to watch. Click **Use** on a row of the list, or click **Pick in Safari** and click the element in the page.

   ![Step 2 Element: the Pick in Safari and Rescan buttons above a list of candidates grouped under Showing a number now, Could get a badge later and Other, each row with an eye button and Use](/shots/add-watcher-element.png "The list is the automatic scan of the page. Each row has an eye button that highlights the element in Safari and a **Use** link that chooses it.")

   **You see:** the assistant moves to step **3 · Confirm**. When the element could be watched in more than one way, a card named "How should WebWatcher watch it?" appears first. Keep the choice marked "Recommended" and click **Continue**. [Finding the element](/docs/finding-the-element) explains the lists, the keys and the choices.

4. On step **3 · Confirm**, read the value WebWatcher shows.

   ![Step 3 Confirm: the line Watching the text $129.00, a box with Current reading 129 and a list of checks with green marks, then Test again and Change element](/shots/add-watcher-confirm.png "The line under **Editing** says what will be watched. The box below it shows the reading and each check.")

   **You see:** a line such as "Current reading: 129" above a list of checks. A green mark means the check passed. [Finding the element](/docs/finding-the-element#what-the-confirm-checks-mean) explains each check.

5. Type a **Name** for the watcher.

   **You see:** the name appears in the field. **Save** stays dimmed until the watcher has a name, a URL and an element.

6. Click **Save**.

   **You see:** the window closes and the watcher appears in the menu bar popover. WebWatcher checks it at once.

   ![The WebWatcher popover: four page watchers with switches, an Email group with one Gmail watcher and an unread count, then Add Watcher, Check All Now, Settings and Quit](/shots/popover.png "Each watcher is a row with a switch, its name and its last reading. **Add Watcher**, **Check All Now**, **Settings...** and **Quit** are below them.")

## What happens next

WebWatcher checks the watcher every 30 seconds until you change the interval. It posts a notification when the reading changes in the way the watch type counts as news. The first reading only sets the starting point and never notifies.

| Watch type | When it notifies |
|---|---|
| Badge/Number | When the number goes up, for example from 2 to 3. A number that stays the same or goes down is silent. |
| Element Count | When the number of matching elements goes up. |
| Text Change | When the text is different from the last reading. |
| Anything Changes Inside | When anything inside the element is different from the last reading. |
| Element Exists | When the element appears. |
| Element Disappears | When the element goes away. |

To change how often a watcher checks, open it from the popover: move the pointer over its row and click the pencil button, whose help text is "Edit". The interval choices, from 15 seconds to 30 minutes, are in [Watcher options](/docs/watcher-options). [Watch types](/docs/watch-types) covers each type in detail.

## If it does not work

| What you see | Cause | Fix |
|---|---|---|
| "Not open in Safari" under the URL. | No Safari tab matches the URL. | Click **Open it**, or open the page in Safari yourself. |
| "Tab unloaded — reloading…" and then a failure. | Safari keeps unloading the tab. | Switch to the tab in Safari, then try again. |
| The list reports that no badges or counters were found. | The page has no element that looks like a counter. | Click **Pick in Safari** and click the element yourself. See [Finding the element](/docs/finding-the-element). |
| The checks show "Zero can be confirmed" in red. | No anchor is set, so a missing badge could also mean a page that failed to load. | Continue if you accept that, or see [Watcher options](/docs/watcher-options) for the **Anchor** field. |
| A permission error appears. | Safari or macOS blocks WebWatcher. | See [Permissions](/docs/permissions). |
| The values look stale. | Safari does not repaint hidden tabs. | See [Force refresh and hidden tabs](/docs/force-refresh). |
