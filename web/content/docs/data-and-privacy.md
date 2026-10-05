This page lists what WebWatcher stores on your Mac, what it connects to, and how to back up or remove its data. It is for anyone deciding whether to trust the app with a signed-in browser or a Gmail account, and everything here is taken from the app's source code. WebWatcher is signed with a Developer ID and notarized by Apple, and its source is on GitHub under a licence that requires attribution (see [Building from source](/docs/building-from-source)).

## What is stored and where

Most files live in `~/Library/Application Support/WebWatcher/`. Open that folder from **Settings > Data > Open Config Folder**.

| Item | What it holds | Sensitive |
|---|---|---|
| `watchers.json` | Your page watchers: name, page address, selector, watch type, check interval, notification text and the last values read. | It lists the pages you watch and the values read from them. It holds no passwords or tokens. |
| `backups/` | Copies of `watchers.json` named `watchers-<stamp>.json`, made each time the app starts. The newest 25 are kept. A file that cannot be read is set aside as `watchers-unreadable-<stamp>.json`. | The same as `watchers.json`. |
| `email_watchers.json` | Your Gmail sender watchers: name, account, sender list, and the state of the last check, which includes subjects and sender addresses of recent mail. | It holds email subjects and sender addresses. It holds no message bodies and no tokens. |
| `gmail_accounts.json` | One entry per connected account: address, display name, poll interval, last check time, last error and unread count. | It holds your email address. Tokens are deliberately not written to it. |
| `site_profiles.json` | Per-site settings for how counts are read, described in [Site profiles](/docs/site-profiles). | No. |
| `icons/` | Copies of the custom notification icons you picked. | No. |
| macOS Keychain | The Google access and refresh token for each connected account, and a Google OAuth client you imported, including its secret. | Yes. The Keychain protects them. |
| macOS preferences | The switches under **Settings > General** and the **Defaults** group. | No. |
| Website data | Cookies and sessions stored by WebWatcher's own web view. | Possibly. **Clear Saved Cookies/Sessions** deletes them. |

## What the app connects to

| Service | When | What is sent |
|---|---|---|
| Safari, through Apple Events | Every check of a page watcher. | WebWatcher runs a small script in a Safari tab you already have open and reads the result. Safari loads the page, not WebWatcher, and your signed-in sessions stay in Safari. |
| Google sign-in, in your browser | When you add or reconnect a Gmail account. | You sign in on Google's own page. WebWatcher listens briefly on `127.0.0.1` to receive the result. |
| `oauth2.googleapis.com` | When you sign in, and when an access token expires. | The OAuth client ID and secret, and the sign-in code or refresh token. |
| `gmail.googleapis.com` | Every check of a connected account, and when you press a notification button. | The access token, a search for your watched senders, requests for message headers and previews, and the label changes or Trash request for a button. |
| `mail.google.com` | When you click a Gmail notification or an email watcher's row. | Your browser opens the link. WebWatcher does not make the request. |
| Herald, at `127.0.0.1` on your Mac | When Herald is your delivery service and is running. | The notification text and its buttons. WebWatcher reads Herald's port and token from `~/Library/Application Support/Herald/`. See [Herald delivery](/docs/herald-delivery). |
| Notification Center | When Herald is not used. | The notification text, on your Mac. |

Nothing is sent to the Google APIs unless you connect a Gmail account. The app's source contains no analytics, no crash reporting and no update checker. A page you watch is fetched by Safari, so the site sees the visit as it sees any other tab you have open.

## The three permissions

macOS asks you to approve Apple Events to Safari, Automation, and Notifications. The reasons and the steps are in [Permissions](/docs/permissions).

## Back up your watchers

1. Open **Settings > Data** and click **Open Config Folder**.

   **You see:** the `WebWatcher` folder in Finder.

2. Copy `watchers.json` and `email_watchers.json` to a safe place.

   **You see:** the copies next to your originals. Restoring means putting them back in the folder while WebWatcher is quit.

Gmail accounts are not part of this backup, because their tokens are in the Keychain. After a restore on another Mac, connect the accounts again.

## Remove all WebWatcher data

1. In **Settings > Gmail**, click the red remove button on each account.

   **You see:** the account disappears and its tokens are deleted from the Keychain. This does not end WebWatcher's access on Google's side. Remove WebWatcher under your Google Account's **Security > Third-party access** as well.

2. If you imported your own OAuth client, expand **Advanced: use your own Google OAuth client** and click **Remove**.

3. In **Settings > Data**, click **Clear Saved Cookies/Sessions**.

4. Quit WebWatcher and delete the `~/Library/Application Support/WebWatcher/` folder.

5. Delete the WebWatcher app.

6. Remove the app's preferences in Terminal.

   ```bash
   defaults delete com.webwatcher.app
   ```

   **You see:** no output. The command prints an error if there are no preferences to delete.
