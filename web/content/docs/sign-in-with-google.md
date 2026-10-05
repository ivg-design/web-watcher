Connecting a Google account lets WebWatcher check your Gmail Inbox for new mail from the senders you choose, and lets the notification buttons Mark as Read, Archive, Delete and Spam act on that mail. This page explains what access you grant, how to connect, reconnect and remove an account, and how to sign in with your own Google OAuth client instead of the one WebWatcher ships with. You need it before you create a [Gmail sender watcher](/docs/sender-and-domain-watchers).

## What connecting an account gives you

WebWatcher asks Google for one permission, the scope `https://www.googleapis.com/auth/gmail.modify`. Google's consent page describes it as permission to read and manage your Gmail. WebWatcher uses it only for the jobs in this table.

| What WebWatcher does with it | Why it needs the permission |
|---|---|
| Lists unread Inbox messages from your watched senders. | To count unread mail per watcher. |
| Reads each message's From, Subject and Date headers, its labels and its short preview text (the snippet). It does not request the message body. | To match the sender and to fill in the notification. |
| Removes the `UNREAD` label, removes the `INBOX` label, or adds the `SPAM` label. | So **Mark as Read**, **Archive** and **Spam** work from the notification. |
| Moves a message to Trash. | So **Delete** works from the notification. |

The narrower read-only scope cannot change labels, so the notification buttons would not work. WebWatcher requests only `gmail.modify`.

Google issues WebWatcher an access token and a refresh token for each account. Both are stored in the macOS Keychain, not in a file, and WebWatcher refreshes the access token when it expires. [Data and privacy](/docs/data-and-privacy) lists everything the app stores.

## Connect a Google account

You can start from Settings or from the email watcher editor. Both run the same sign-in.

1. Click the WebWatcher icon in the menu bar, then **Settings...**.

   **You see:** the Settings window.

2. Scroll to the **Gmail** group and click **Add Gmail Account**.

   ![The Gmail group of Settings with no account: the line No Gmail accounts connected, the Add Gmail Account button and the collapsed Advanced row](/shots/settings-gmail-signin.png "Before you connect, the group reads \"No Gmail accounts connected\". **Add Gmail Account** starts the sign-in.")

   **You see:** your default browser opens Google's sign-in page.

3. Choose your Google account and allow the access WebWatcher asks for.

   **You see:** a page titled "Gmail Account Connected" that says "You can close this tab and return to Web Watcher."

4. Close the browser tab and return to WebWatcher.

   **You see:** the account listed under **Accounts** with the status "Monitoring", or the unread count such as "3 unread".

   ![The Gmail group of Settings with one connected account showing 3 unread, the Add Gmail Account button, the Poll interval picker and the collapsed Advanced row](/shots/settings-gmail.png "After sign-in the account appears under **Accounts** with a green dot and its unread count.")

The sign-in must finish within 120 seconds of the browser opening, or WebWatcher stops waiting. While it waits, WebWatcher listens on a temporary port on your own Mac (`127.0.0.1`) so Google can send the result back to it.

To start from the editor instead, open **Add Watcher**, choose the **Gmail sender** tab and click **Sign in with Google**. The button appears when no account is connected yet. Once one is, the editor shows **Connect another account…** for adding more.

![The Add Email Watcher window before an account is connected: a Sign in with Google button under Gmail account, with the Senders field dimmed](/shots/gmail-signin.png "**Sign in with Google** takes the place of the account picker until an account is connected. The line under it states the permission WebWatcher asks for.")

> **Note.** If the button is dimmed, or the editor says "This build has no Google client configured — see Settings → Gmail → Advanced.", your copy of WebWatcher has no Google client. Follow [Use your own Google OAuth client](#use-your-own-google-oauth-client).

## Reconnect or remove an account

Reconnect when an account shows an error such as "Error: Reconnect required", or "Not connected — reconnect in Settings". A **Reconnect** button appears on that account's row.

1. In **Settings > Gmail**, click **Reconnect** on the account's row.

   **You see:** Google's sign-in page in your browser.

2. Sign in with the same Google account and allow access.

   **You see:** the "Gmail Account Connected" page, then the row's error clears.

Signing in with a different account fails with "You signed in as ..., but this account is .... Sign in with ... instead, or add ... as a new account." Your email watchers stay attached to the mailbox they were created for.

To remove an account, click the red remove button on its row. WebWatcher deletes that account's tokens from the Keychain and stops checking it. It does not revoke WebWatcher's access on Google's side. To revoke it, open your Google Account and go to **Security > Third-party access**, then remove WebWatcher.

To pause an account without removing it, turn off the switch on its row.

## Use your own Google OAuth client

WebWatcher signs in to Google with an OAuth client, a registration that identifies the app to Google. You can supply your own client when your copy of WebWatcher has none, when you build from source, or when you prefer to use your own Google Cloud project. The client you import always takes priority over a built-in one. Removing it returns WebWatcher to the built-in client, if the build has one.

### Create the client in Google Cloud Console

1. Open **Google Cloud Console > APIs & Services > Credentials** and select or create a project.

   **You see:** the Credentials page for that project.

2. Click **Create Credentials > OAuth client ID**.

3. Set **Application type** to **Desktop app**, then click **Create**.

   **You see:** a dialog with the client ID and client secret.

4. Click **Download JSON**.

   **You see:** a file named `client_secret_...json` in your Downloads folder.

5. Open **APIs & Services > Library**, find the **Gmail API** and click **Enable**.

6. Open the **OAuth consent screen** and choose the user type from the table below.

| Your account type | Choose | What happens |
|---|---|---|
| The project belongs to a Google Workspace organization. | **Internal** | Everyone in the organization can connect. Google does not expire access. |
| A personal Google account, or a project outside a Workspace organization. | **External**, then add your own address under **Test users** | Only the listed test users can connect. The app stays in Testing mode. |

> **Warning.** While an External app is in Testing mode, Google revokes access every 7 days. The account then reads "Error:" with a **Reconnect** button, and you must reconnect it each week. Publishing the app to production ends the weekly expiry.

WebWatcher accepts only a Desktop app client. A file for a Web application client is rejected with "This is a Web application client. Create a Desktop app client instead."

### Import the client into WebWatcher

1. Open **Settings > Gmail** and expand **Advanced: use your own Google OAuth client**.

   **You see:** a "Google OAuth client" block with a status line, **Import client JSON…** and **Enter manually…**.

2. Click **Import client JSON…** and choose the downloaded file.

   **You see:** the status line reads "Using your imported client" followed by the first 12 characters of the client ID, and a **Remove** link appears.

3. Click **Add Gmail Account** and sign in as described above.

If WebWatcher finds a `client_secret...json` file in your Downloads folder, the block shows "Found" and the file name with an **Import** button. Click it instead of choosing the file yourself. WebWatcher only reads the Downloads folder and never changes it.

To enter the values by hand, click **Enter manually…**, fill in **Client ID** and **Client secret**, and click **Save**. **Save** stays dimmed until the client ID ends in `.apps.googleusercontent.com` and the secret is not empty.

The status line at the top of the block tells you which client **Add Gmail Account** will use.

| Status line | Meaning |
|---|---|
| "Using your imported client (" and the first 12 characters of the client ID | Your client is in use. It overrides any built-in client. |
| "Using WebWatcher's built-in Google client" | You have not imported a client, and this build includes one. |
| "Not configured" | There is no client, so **Add Gmail Account** is dimmed. |

WebWatcher stores an imported client, including its secret, in the Keychain and never in a file. Click **Remove** to delete it and return to the built-in client. The block also has a **How to get a client ID** section that repeats the steps above.

## If it does not work

| What you see | Cause | Fix |
|---|---|---|
| "Google didn't return to WebWatcher. If you're using a personal Google account, add it under OAuth consent screen → Test users for this client, then try again." | The consent screen blocked the sign-in, or you did not finish within 120 seconds. | Add your address under **Test users**, then connect again. |
| "Your Google Workspace admin has blocked WebWatcher for this account. Ask your admin to allow it in the Admin console, or connect a personal Google account instead." | A Workspace administrator restricts the client. | Ask the administrator to allow it, or use another account. |
| "That sign-in expired or was already used — try connecting again." | The sign-in code expired or was reused. | Click **Add Gmail Account** again. |
| "Google rejected the OAuth client. Re-import the client JSON." | Google does not accept the client ID or secret. | Download the JSON again and import it. |
| "Google revoked access (this happens after 7 days for apps in Testing). Reconnect the account." | Your own client is in Testing mode, or you removed WebWatcher from your Google Account. | Click **Reconnect**. Publish the app to avoid the weekly expiry. |
| "Google did not send a refresh token. Remove WebWatcher under Google Account → Security → Third-party access, then connect again." | Google reused an earlier grant and sent no refresh token. | Remove WebWatcher in your Google Account, then connect again. |
| "... is already connected." | The account is already in the list. | Use the existing row, or add a different account. |
| "Signed in, but Gmail did not return the account profile: ..." | Google accepted the sign-in but the Gmail API call failed. | Check that the Gmail API is enabled for the project, then try again. |
