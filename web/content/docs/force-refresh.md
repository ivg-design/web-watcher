This page is for anyone whose watcher shows a value that is out of date, or reads nothing, while the page in Safari looks fine. It explains why Safari causes this, what WebWatcher already does about it, and how to turn on **Force refresh before checking** for the cases it does not cover.

## Why a watcher can read a stale value

WebWatcher reads the page that Safari holds in a tab. Safari saves resources on tabs you are not looking at, in two ways.

- **Hidden tabs stop repainting.** A tab that is behind another tab, or in a window behind other apps, is hidden to the page. Pages that update a badge through animation or rendering do not update it while hidden, so the badge keeps its old value.
- **Unloaded tabs read as blank.** Safari can unload a tab entirely. The tab still shows its real URL to AppleScript, but the page inside it is `about:blank`, so no element exists to read.

WebWatcher reports the second case as "Tab unloaded by Safari". The first case gives no error, only an old number.

## What WebWatcher does about it

| Tab state | What WebWatcher does | Needs Force refresh |
|---|---|---|
| Unloaded (`about:blank`) | Reloads the tab in place, waits for the page to load, then reads it. If that fails, the check retries once with a second reload. | No. |
| Hidden, Force refresh on | Reloads the tab before every check, then waits for the settle delay and reads it. | Yes. |
| Hidden, Force refresh off | Reads the page as it is, which can be stale. Some built-in site recipes, such as LinkedIn and Rive Community, reload hidden tabs by themselves. | Yes, for other sites. |
| Visible | Reads the page as it is and never reloads it. | No. |

Two cases never reload, whatever the setting.

- While the last check found a signed-out page or a bot check, WebWatcher stops reloading, so a sign-in page is not reloaded on a timer.
- While you pick an element in the assistant, WebWatcher reloads only a blank tab, because a reload would end your pick.

## Turn on Force refresh

Do this when a watcher reads an old value and the page in Safari shows the current one.

1. Click the WebWatcher icon in the menu bar.
2. Move the pointer over the watcher's row and click the pencil button, whose help text is "Edit".

   **You see:** the **Edit Watcher** window.

3. Click **Advanced** to expand it.

   ![The Edit Watcher window with Advanced and Notification expanded: Selector Type, CSS Selector, Anchor, Strategy, the Open the page automatically checkbox, Force refresh before checking, Action URL and API Lookup Command](/shots/watcher-editor-advanced.png "**Force refresh before checking** is the second checkbox in **Advanced**. It is off in this capture, so the **Settle delay** slider is hidden.")

   **You see:** the advanced fields, with **Force refresh before checking** below **Strategy**.

4. Switch on **Force refresh before checking**.

   **You see:** a **Settle delay** slider appears under the switch, with the text "Time to wait after page loads for dynamic content to update."

5. Set **Settle delay** if the badge appears late, as described below.
6. Click **Save**.

   **You see:** the window closes and the watcher is checked at once.

## The two settings

Both are in **Advanced** in the watcher editor and apply to that watcher only.

| Setting | What it does | Default | When to change it |
|---|---|---|---|
| Force refresh before checking | Reloads the Safari tab before a check when the tab is hidden. | Off. | The watcher shows a stale value, or a hidden tab never updates its badge. |
| Settle delay | Sets how long WebWatcher waits after a reload before reading, from 0.5 to 5.0 seconds in steps of 0.5. It appears only while Force refresh is on. | 2.0 seconds. | The page draws its badge late, so the reading comes back empty or old. Raise it. |

The settle delay counts only after a reload that succeeded. A page that loads slowly is waited for first, for up to 15 seconds, and then the settle delay starts.

## The cost of reloading

Every reload of a hidden tab loads the page again, so a short check interval multiplies the work. At 15 seconds the tab reloads every 15 seconds. Each reload also adds the load time and the settle delay to the check.

Pick the longest check interval that still catches the change in time. [Watcher options](/docs/watcher-options) lists the intervals, from 15 seconds to 30 minutes. A watcher whose tab you keep visible needs no reload at all.

## If it does not work

| What you see | Cause | Fix |
|---|---|---|
| The value is still old with Force refresh on. | The page draws its badge after the settle delay. | Raise **Settle delay**. |
| The status reads "Tab unloaded by Safari". | Safari unloaded the tab and the reload did not restore it. | Switch to the tab in Safari once. If it keeps happening, keep the page in a visible tab. |
| The status reads "Page still loading" or "Timed out". | The page did not finish loading in time. | Lengthen the check interval and raise **Settle delay**. |
| The watcher reads "Signed out" or "Blocked by bot check". | The page needs you to sign in or clear a prompt, and reloads are paused. | Open the tab, sign in or clear the prompt. |
| Nothing helps. | The element or the selector is wrong. | Use **Test again** in the assistant, described in [Finding the element](/docs/finding-the-element). |
