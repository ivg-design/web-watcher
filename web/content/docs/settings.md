This page describes every control in the WebWatcher Settings window: what it does, its default, and when to change it. Settings apply to the whole app. Options that belong to one watcher, such as its check interval or its notification text, are in the [watcher options reference](/docs/watcher-options).

## Open Settings

1. Click the WebWatcher icon in the menu bar.

   **You see:** the popover with your watchers, **Add Watcher**, **Check All Now**, **Settings...** and **Quit**.

2. Click **Settings...**.

   **You see:** the Settings window. It is one scrolling list of groups: General, Permissions, Defaults, Notifications, Gmail, Data and About.

A change takes effect as soon as you make it. **Done** closes the window; there is no separate save step.

## General

The General group controls how WebWatcher starts and how it opens pages.

![The top of the Settings window: the General group with three checkboxes, then Permissions and Defaults](/shots/settings-general.png "The **General** group is the first three checkboxes. **Permissions** and **Defaults** follow it.")

| Setting | What it does | Default | When to change it |
|---|---|---|---|
| Launch at login | Registers WebWatcher as a login item so it starts with your Mac. | Off. | Turn it on if you rely on watchers every day. Watchers only run while the app is running. |
| Show badge in menu bar | Stores your preference for a count on the menu bar icon. | On. | See the note below. |
| Reuse existing browser tab by domain | When you open a watcher's page, WebWatcher switches to a tab that is already on the same domain instead of opening a new tab. | On. | Turn it off if you keep several tabs of one site open and want the watcher's exact page in a tab of its own. |

> **Note.** The current build saves **Show badge in menu bar**, **Default check interval** and **Page load delay**, but no part of the app reads them. The menu bar icon does not change, a new watcher always starts at 30 seconds, and the wait after a reload is the watcher's own **Settle delay**. Set the interval and the delay per watcher in the [watcher options](/docs/watcher-options).

## Permissions

The Permissions group shows whether macOS lets WebWatcher do its job, and gives you a button to fix each permission. For what each one is for and how to grant it, see [Permissions](/docs/permissions).

![The Permissions group with three rows marked Granted, each with an Open button, above the Defaults and Notifications groups](/shots/permissions.png "Each row has a status dot and the word **Granted** when the permission is in place.")

| Control | What it does |
|---|---|
| Open System Automation Settings | Opens the Automation list in System Settings, where you allow WebWatcher to control Safari. |
| Refresh | Reads the three permissions again. Use it after you change something in System Settings. |
| Notifications | Shows whether macOS allows WebWatcher to post notifications. The button reads **Fix** when it does not and **Open** when it does. |
| Safari Automation | Shows whether WebWatcher may send Apple Events to Safari. The button reads **Check** until the permission is granted. |
| Default browser Automation | The same check for your default browser, named in the row. If Safari is your default browser, this row also reads **Safari Automation**. |

## Defaults

The Defaults group holds two pickers.

| Setting | Options | Default |
|---|---|---|
| Default check interval | 15 seconds, 30 seconds, 1 minute, 2 minutes, 5 minutes, 10 minutes or 30 minutes. | 30 seconds. |
| Page load delay | 2, 3, 5, 10 or 15 seconds. | 2 seconds. |

Both values are saved but not applied by the current build, as the note under General explains.

## Notifications

The Notifications group chooses which service shows your notifications.

![The Notifications group: the Deliver notifications via picker set to Herald when available, a Herald status line, and the Open System Notification Settings button](/shots/settings-notifications.png "**Deliver notifications via** is the picker. The line under it reports whether Herald is running.")

### Deliver notifications via

| Option | What it does | Choose it when |
|---|---|---|
| Herald when available | Sends each notification to Herald while Herald is running, and to macOS when it is not. This is the default. | You use Herald, or you might later. Without Herald the result is the same as the other option. |
| macOS notifications | Always uses Notification Center, even while Herald is running. | You want WebWatcher's banners to stay in Notification Center. |

The status line under the picker tells you which path is in use right now:

| Status line | Meaning |
|---|---|
| "Herald: running (port 47321)" | Herald answered. The port number is the one Herald listens on and can differ on your Mac. |
| "Herald not running — using macOS notifications" | Herald did not answer, so notifications go to macOS. |

See [Herald delivery](/docs/herald-delivery) for what Herald adds.

### Open System Notification Settings

This button opens the Notifications pane of System Settings. Banner style, sounds and grouping for macOS notifications are set there, not in WebWatcher.

## Gmail

The Gmail group lists the Google accounts WebWatcher can read and how often it asks Gmail for new mail. You need it only if you use [Gmail sender watchers](/docs/sender-and-domain-watchers).

![The Gmail group with one connected account, the Add Gmail Account button, the Poll interval picker and the collapsed Advanced row, above the Data and About groups](/shots/settings-gmail.png "One connected account. The switch pauses it, the red × removes it.")

### Accounts

Each connected account is one row.

| Control | What it does | Default |
|---|---|---|
| Status line | Shows "Monitoring", the unread count such as "3 unread", "Not connected — reconnect in Settings", or "Error:" followed by the reason. | |
| Switch | Pauses or resumes checking this account without removing it. | On. |
| × button | Removes the account from WebWatcher. | |
| Notify for every new email | Notifies you about every message that reaches this account's Inbox, not only mail from the senders you set up watchers for. | Off. |
| Reconnect | Appears only when the account has an error. It runs the Google sign-in again for the same account. | |

### Add Gmail Account and Poll interval

| Control | What it does | Default |
|---|---|---|
| Add Gmail Account | Opens Google's sign-in page in your browser. See [Sign in with Google](/docs/sign-in-with-google). | |
| Poll interval | Sets how often WebWatcher asks Gmail for new mail: 30 seconds, 1, 2, 5 or 10 minutes. One value applies to every account. The picker appears once an account is connected. | 1 minute. |

### Advanced: use your own Google OAuth client

This row expands to show which Google OAuth client WebWatcher signs in with. Most people never open it. Use it if you build WebWatcher yourself, or if you prefer your own Google Cloud project. The steps are in [Sign in with Google](/docs/sign-in-with-google).

| Control | What it does |
|---|---|
| Import client JSON… | Reads the client file you downloaded from Google Cloud Console. |
| Enter manually… | Opens a sheet with **Client ID** and **Client secret** fields, for when you have the values but not the file. |
| Import | Appears when WebWatcher finds a client file in your Downloads folder, and imports that file. |
| Remove | Deletes your client so WebWatcher goes back to its built-in one. |

## Data

| Control | What it does |
|---|---|
| Config location | Shows the folder that holds your watchers: `~/Library/Application Support/WebWatcher/`. |
| Open Config Folder | Opens that folder in Finder. Copy `watchers.json` from it to back up your watchers. |
| Clear Saved Cookies/Sessions | Deletes the website data stored by WebWatcher's own web view. It does not sign you out of anything in Safari, and it does not delete watchers. |

[Data and privacy](/docs/data-and-privacy) lists every file the app writes.

## About

The About group shows the app's name and its version. Quote that version when you report a problem.

## If it does not work

| What you see | Cause | Fix |
|---|---|---|
| A Permissions row does not read **Granted** after you allowed it. | The window read the status before you changed it. | Click **Refresh**. |
| The status line reads "Herald not running — using macOS notifications". | Herald is not open. | Open Herald. WebWatcher uses it from the next notification. |
| **Add Gmail Account** is dimmed, with "This build has no Google client configured — see Advanced below." | You are running a build without a Google OAuth client. | Import one under **Advanced: use your own Google OAuth client**. |
| An account reads "Error:" and a **Reconnect** button appears. | Google ended the session. This happens every 7 days if your own OAuth client is in Testing mode. | Click **Reconnect** and sign in again. |
