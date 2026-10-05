This page lists every message WebWatcher shows when it cannot read a page, post a notification or reach Gmail, with the cause and the fix for each. Use it when a watcher row shows a status you do not understand, when no notification arrives, or when a Gmail account shows an error.

## Where the messages appear

| Where | What you see |
|---|---|
| The watcher's row in the menu bar popover | A short status such as "Signed out". Hover over the row to see the fix. |
| A notification titled with the watcher's name followed by "isn't working" | The status and the fix, sent once when a problem has lasted. |
| **Run Diagnosis** in the watcher's editor | A list of checks, a summary line and a `Detail:` line with the technical reason. |
| A Gmail account row in **Settings > Gmail** | "Error:" followed by the reason, and a **Reconnect** button. |

Find your message in the sections below, grouped by area.

While a watcher fails, WebWatcher checks it less often, up to every 30 minutes, so a broken watcher does not hammer Safari. The first check that succeeds restores your interval. **Check All Now** in the popover, and the check button on a row, always check immediately.

WebWatcher sends the "isn't working" notification only when a problem has lasted at least three checks and ten minutes. It does not send it for "Page still loading" or "Timed out", and it repeats it no more than once every six hours. Failures in the first two minutes after the app starts or your Mac wakes are not counted.

## Safari and permissions

### "Enable JS from Apple Events"

**Cause:** Safari blocks WebWatcher from running JavaScript in a page.

**Fix:**

1. In Safari, open **Safari > Settings > Developer**.
2. Tick **Allow JavaScript from Apple Events**.

If there is no **Developer** tab, tick **Show features for web developers** under **Safari > Settings > Advanced** first. [Permissions](/docs/permissions) has the full steps.

### "Automation permission needed"

**Cause:** macOS has not allowed WebWatcher to control Safari.

**Fix:** Open **System Settings > Privacy & Security > Automation** and switch on Safari under WebWatcher. In WebWatcher, **Settings... > Permissions** has an **Open System Automation Settings** button and a **Refresh** button that reads the result.

### "Safari not running"

**Cause:** Safari is closed, and WebWatcher reads pages only from Safari.

**Fix:** Launch Safari.

### "No tab open"

**Cause:** No Safari tab is on the watcher's page, or its domain. The detail "Safari has no window" means Safari is open with no window.

**Fix:** Open the page in a Safari tab, or leave **Open the page automatically if no tab is found** switched on in **Advanced**. WebWatcher then opens the page in a background tab by itself, at most three times a day per watcher and no more than once every ten minutes. A tab counts as a match when its address starts with the watcher's URL, or when it is on the same domain.

### "Tab unloaded by Safari"

**Cause:** Safari freed the memory of a background tab and left it blank.

**Fix:** None is needed at first. WebWatcher reloads the tab by itself, at most once every five minutes. If the message returns, keep the page in a visible tab or turn on **Force refresh before checking** in **Advanced**. See [Force refresh](/docs/force-refresh).

## Reading the page

### "Page still loading"

**Cause:** The tab has not finished loading when the check ran.

**Fix:** None. The next check reads the page. WebWatcher never sends an "isn't working" notification for this status.

### "Signed out"

**Cause:** The site shows its sign-in link instead of the signed-in page.

**Fix:** Sign in to the site in Safari.

### "Blocked by bot check"

**Cause:** The site shows a verification prompt, such as a captcha, in the tab.

**Fix:** Open the tab and complete the site's verification prompt.

### "Page not recognized"

**Cause:** The page loaded, but the anchor element is missing. Either the site changed its layout, or the tab is on a page that does not have the element, such as a page without the navigation bar.

**Fix:**

1. In Safari, open the page where the badge is visible, such as the site's home page.
2. If the status stays, re-pick the element in the watcher's editor. See [Finding the element](/docs/finding-the-element).

### "Can't confirm — no anchor set"

**Cause:** The selector found nothing and the watcher has no anchor, so WebWatcher cannot tell zero from a failed read.

**Fix:** Add an anchor in **Advanced** under **Anchor (recommended)**, or click **Suggest** beside it. See [Watcher options](/docs/watcher-options).

### "Invalid selector"

**Cause:** Safari rejected the selector as malformed.

**Fix:** Correct the selector in **Advanced**, or re-pick the element so the picker writes a valid one. **Help** beside the selector opens a guide to the syntax.

### "Check failed"

**Cause:** The script that reads the page failed. The reason is in the `Detail:` line of **Run Diagnosis**.

**Fix:** Click **Run Diagnosis** in the editor and read the detail. If it persists, re-pick the element, and include the detail when you report the problem.

### "Timed out"

**Cause:** The page did not answer within the time WebWatcher allows.

**Fix:** None at first, because the next check tries again. If it repeats, click **Run Diagnosis** in the editor to see which step fails.

### "Unreadable response"

**Cause:** The page returned an empty or malformed answer. This happens when a script in the page throws an error while WebWatcher reads it.

**Fix:** Reload the tab, then click **Run Diagnosis**. If the status stays, re-pick the element.

### "Not checked yet"

**Cause:** No check has finished for this watcher.

**Fix:** Click **Check All Now** in the popover and wait for the row to update.

### "Error:" followed by a reason

**Cause:** The check failed with a message that has no short status, and the watcher has never had a good reading.

**Fix:** Click **Run Diagnosis** in the editor. The summary and the `Detail:` line name the failure.

### The value is stale or never changes

**Cause:** Safari does not repaint a tab that is in the background, so a badge that updates live can show an old number.

**Fix:** Turn on **Force refresh before checking** in **Advanced**, or keep the page in a visible tab. See [Force refresh](/docs/force-refresh).

## Notifications

### No notification arrives

**Cause:** The value did not rise, this was the watcher's first reading and only sets the baseline, or macOS blocks notifications for WebWatcher.

**Fix:**

1. Look at the watcher's row. If it shows a status such as "Signed out", fix that first.
2. Open **System Settings > Notifications > WebWatcher**, and choose **Banners** or **Alerts**, not **None**.
3. In WebWatcher, open **Settings... > Permissions**. The **Notifications** row reads **Granted** when macOS allows notifications. If it reads **Fix**, click it.
4. Click **Preview Notification** in the watcher's editor to test the path. See [Custom notifications](/docs/custom-notifications).

### "Permission denied. Enable in System Settings → Notifications"

**Cause:** macOS has not allowed notifications for WebWatcher. The message appears under **Preview Notification**.

**Fix:** Open **System Settings > Notifications > WebWatcher** and allow notifications.

### "Herald not running — using macOS notifications"

**Cause:** **Deliver notifications via** is set to **Herald when available** and Herald is not open.

**Fix:** Open Herald, or leave it closed and use macOS banners. See [Herald delivery](/docs/herald-delivery).

## Gmail

### "Not connected — reconnect in Settings"

**Cause:** The account has no saved Google sign-in.

**Fix:** In **Settings... > Gmail**, remove the account and add it again with **Add Gmail Account**. See [Sign in with Google](/docs/sign-in-with-google).

### "Error: Token expired" or "Error: Reconnect required"

**Cause:** Google ended the session, or the account needs to consent to a wider permission. This happens every 7 days when your own Google OAuth client is in Testing mode.

**Fix:** Click **Reconnect** next to the account in **Settings... > Gmail** and sign in with the same Google account.

### "Google revoked access (this happens after 7 days for apps in Testing). Reconnect the account."

**Cause:** Google withdrew the saved sign-in.

**Fix:** Click **Reconnect** and sign in again. To stop the 7-day expiry, publish your Google app, or use an Internal consent screen on a Workspace account.

### "Gmail API is not enabled for this Google Cloud project. Enable it, then try again."

**Cause:** Your own Google Cloud project has the Gmail API switched off.

**Fix:** Enable the Gmail API for the project in Google Cloud Console, then click **Reconnect**.

### "Google rate limit — will retry"

**Cause:** Google asked WebWatcher to slow down.

**Fix:** None. WebWatcher retries on its next poll. A longer **Poll interval** in **Settings... > Gmail** reduces the load.

### "API error" followed by a number, or "Failed to decode API response"

**Cause:** Google returned an error WebWatcher has no special handling for, or an answer it could not read.

**Fix:** Wait for the next poll. If the error stays, click **Reconnect**, and include the number when you report it.

### Messages when you sign in

These appear in red under **Add Gmail Account** or **Reconnect**.

| Message | Cause | Fix |
|---|---|---|
| "Add your Google OAuth client in Settings → Gmail first." | The build has no Google client. | Import one under **Advanced: use your own Google OAuth client**. |
| "You cancelled the Google sign-in." | The sign-in window was closed. | Click **Add Gmail Account** and finish the sign-in. |
| "That sign-in expired or was already used — try connecting again." | The sign-in took too long, or its code was used twice. | Start the sign-in again. |
| "Google rejected the OAuth client. Re-import the client JSON." | The client id or secret is wrong. | Import the client file again. |
| "Google didn't return to WebWatcher. If you're using a personal Google account, add it under OAuth consent screen → Test users for this client, then try again." | The consent screen blocked the sign-in. | Add your address under **Test users** in Google Cloud Console. |
| "Your Google Workspace admin has blocked WebWatcher for this account. Ask your admin to allow it in the Admin console, or connect a personal Google account instead." | A Workspace policy blocks the app. | Ask your admin, or use a personal account. |
| "Google did not send a refresh token. Remove WebWatcher under Google Account → Security → Third-party access, then connect again." | Google did not issue a long-lived sign-in. | Remove WebWatcher in your Google Account, then connect again. |
| "You signed in as you@example.com, but this account is other@example.com. Sign in with other@example.com instead, or add you@example.com as a new account." | **Reconnect** needs the same account. | Sign in with the account that the message names. |
| "you@example.com is already connected." | The account is in the list. | Nothing to do. |
| "Authorization failed:", "Token exchange failed:", "Failed to start OAuth redirect server" or "Signed in, but Gmail did not return the account profile:" | The sign-in broke part way. | Try again. Include the text after the colon when you report it. |

## Known limits

| Limit | What happens | What to do |
|---|---|---|
| Only Safari is read. | A page open in another browser is not seen, and the row shows "No tab open". | Open the page in Safari. |
| Private windows are not told apart from normal ones. | WebWatcher reads the first matching Safari tab, visible tabs first, whichever window it is in. | Keep one tab of the page in a normal window. |
| Elements inside an embedded frame cannot be reached. | The picker says "That element is inside an embedded frame WebWatcher can't reach — pick something outside it." | Pick an element outside the frame. |
| Elements inside a closed shadow root cannot be seen. | The element cannot be found by a selector or by the picker. | Pick the nearest element outside the shadow root. |
| Elements that exist only while a menu is open. | The check cannot find them once the menu closes. | Pick the always-visible button that opens the menu. |
| Background tabs can show old values. | A badge that updates live may not repaint until the tab is visible. | Turn on **Force refresh before checking**. |
| A capped badge such as `9+` hides the real number. | A rise from a lower number to `9+` notifies, but a reading that stays at `9+` does not. | Watch a page that shows the exact count. |
| Watchers run only while WebWatcher is running. | Nothing is checked while the app is closed. | Turn on **Launch at login** in **Settings... > General**. |

Still stuck? Quote the status text, the watcher's **Run Diagnosis** summary and the version shown under **Settings... > About** when you report the problem.
