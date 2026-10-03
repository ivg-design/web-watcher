WebWatcher's settings are few. This page lists what is there and where each option lives.

![The Settings window, General section](/shots/settings-general.png)

## General

- **Launch at login.** Starts WebWatcher with your Mac so watchers keep running.
- **Show badge in menu bar.** Shows the unread count as a badge on the menu bar icon.
- **Reuse existing browser tab by domain.** When a watcher's page is opened, switches to an existing Safari tab on the same domain instead of creating a new one.

## Defaults

- **Default check interval.** The interval new watchers start with.
- **Page load delay.** How long to wait after a page loads before reading it. Increase it for pages that rely on heavy JavaScript.

## Data

- **Config location.** `~/Library/Application Support/WebWatcher/`, with a button to open the folder.
- **Clear Saved Cookies/Sessions.** Removes saved web data.

## Per watcher

- **Interval.** How often to check, from 15 seconds to 30 minutes.
- **Force refresh before checking.** Reloads the tab before reading. See [Force refresh](/docs/force-refresh).
- **Settle delay.** 0.5 to 5.0 seconds of wait after a reload.
- **Selector.** Under Advanced: the CSS selector or XPath, if you want to type it yourself.
- **Notification.** Icon, title and body.

## Gmail

- **Connected accounts.** Add, reconnect or remove a Google account.
- **Notify for every new email.** A toggle per account.
- **Advanced: use your own Google OAuth client.** Import a client JSON. See [Sign in with Google](/docs/sign-in-with-google).

## Notifications

- **Delivery.** Herald when available, or macOS notifications. See [Herald delivery](/docs/herald-delivery).
- **Open System Notification Settings.** Jumps to macOS to change banners, sounds and grouping.
