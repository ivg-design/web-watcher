Herald is a separate menu-bar app, available from [github.com/ivg-design/herald](https://github.com/ivg-design/herald), that shows notification banners which stay on screen until you deal with them. WebWatcher can send its notifications to Herald instead of Notification Center. Read this page if you miss macOS banners because they vanish after a few seconds, or if you want action buttons such as **Archive** on mail notifications.

## What Herald changes

Herald shows persistent, always-on-top banners, keeps a history per app, stacks banners from the same source, can snooze them, and lets you redesign how a banner looks. WebWatcher keeps working the same way: the checks, the title, the body, the icon and the sound are identical. Only the place where the banner appears changes.

| Aspect | With macOS notifications | With Herald |
|---|---|---|
| Lifetime | The banner follows your macOS notification style. | The banner stays until you act on it or dismiss it. |
| Buttons on a page watcher banner | None. Clicking the banner opens the page. | **Open**. |
| Buttons on a Gmail banner | **Mark as Read**, **Archive**, **Delete** and **Spam** as notification actions. | The same four buttons on the banner. |
| Grouping | By watcher. A new notification from a watcher replaces its earlier one. | By site for page watchers and by sender address for Gmail. |
| Where you set the style | **System Settings > Notifications > WebWatcher**. | In Herald. |

When Herald is running, WebWatcher registers two issuers with it: `webwatcher.web` for page watchers, shown in Herald as "WebWatcher · Web", and `webwatcher.email` for Gmail watchers, shown as "WebWatcher · Email". You can restyle each one in Herald.

## Turn Herald delivery on

Delivery is on by default. Do these steps to check it, or to turn it off.

1. Click the WebWatcher icon in the menu bar, then **Settings...**.
2. Scroll to the **Notifications** group.

   ![The Notifications group in Settings: Deliver notifications via set to Herald when available, the status line Herald: running (port 47321), and the Open System Notification Settings button](/shots/settings-notifications.png "**Deliver notifications via** is the picker. The line under it tells you whether Herald is answering.")

3. Set **Deliver notifications via** to **Herald when available**.

   **You see:** under the picker, "Herald: running (port 47321)" with a green dot when Herald is open. The port number can differ on your Mac.

To go back to Notification Center only, set the picker to **macOS notifications**. Herald is then never used, even while it is running.

## The buttons on a banner

A page watcher banner has one button.

| Button | What it does |
|---|---|
| Open | Opens the watcher's **Action URL (optional)**, or the watched page when none is set. With an **API Lookup Command (optional)**, WebWatcher runs the command and opens the URL it prints. |

A Gmail banner has four buttons. [Sender and domain watchers](/docs/sender-and-domain-watchers) describes what each does to the message.

| Button | What it does to the message |
|---|---|
| Mark as Read | Removes the unread label. |
| Archive | Removes the message from the Inbox. |
| Delete | Moves the message to Trash. |
| Spam | Marks the message as spam and removes it from the Inbox. |

The buttons call back into WebWatcher, and Herald dismisses the banner only after WebWatcher reports that the action worked. If a Gmail action fails, the banner stays and shows the failure. If the action is still running after 4 seconds, Herald asks once more. The Gmail calls can safely be repeated.

## How banners stack

Herald folds banners with the same group into one stack:

| Banner | Group |
|---|---|
| Page watcher | The site of the watched page, such as `linkedin.com`. Two watchers on the same site stack together. |
| "isn't working" notice | The site of the watcher, so it stacks with that watcher's other banners. |
| Gmail | The sender address, so all mail from one sender folds into one stack. |

## When Herald is not running

WebWatcher checks before every notification whether Herald answers. If it does not, or if a send to Herald fails, the notification goes to Notification Center instead. Each notification is delivered once, never to both.

The status line under the picker tells you which path is in use:

| Status line | Meaning |
|---|---|
| "Herald: running (port 47321)" | Herald answers and receives the notifications. |
| "Herald not running — using macOS notifications" | Herald does not answer, so macOS shows the banners. |
| "Checking Herald…" | WebWatcher is asking Herald while the window opens. |

Open Herald and WebWatcher uses it from the next notification.

## If it does not work

| What you see | Cause | Fix |
|---|---|---|
| "Herald not running — using macOS notifications". | Herald is not open, or it is not installed. | Install it from [github.com/ivg-design/herald](https://github.com/ivg-design/herald) and open it. |
| Banners still appear in Notification Center while Herald runs. | **Deliver notifications via** is set to **macOS notifications**. | Set it to **Herald when available**. |
| A Gmail banner stays after you click a button. | The action failed, and Herald keeps the banner with the failure. | Read the failure on the banner, then use **Reconnect** in **Settings > Gmail** if it names the account. |
| No banner appears from either path. | macOS blocks notifications for WebWatcher and Herald is not answering. | See [Troubleshooting](/docs/troubleshooting). |
