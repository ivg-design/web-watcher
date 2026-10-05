This page is for anyone setting up WebWatcher or fixing a watcher that reports a permission error. WebWatcher needs one Safari setting and two macOS permissions, and each is switched on in a different place. Each section below says what the permission is for, how to grant it and how to check it.

## What WebWatcher needs

WebWatcher reads pages from your own Safari tabs, so macOS makes you approve the connection. It sends Apple Events to Safari, posts banners through Notification Center or [Herald](/docs/herald-delivery), and contacts Google only if you connect a Gmail account.

| Permission | What it allows | What breaks without it |
|---|---|---|
| Safari: Allow JavaScript from Apple Events | WebWatcher runs a short script in the watched tab to read the element. | Every page watcher fails with the status "Enable JS from Apple Events". |
| Automation for Safari | WebWatcher sends Apple Events to Safari to find, reload and read tabs. | Page watchers fail with "Automation permission needed". |
| Automation for your default browser | WebWatcher opens a watched page in your default browser and switches to a tab you already have open. | Clicking a watcher row cannot open or reveal its page. |
| Notifications | WebWatcher posts a banner when a watcher finds a change. | Watchers still run, but you see no banner. |

The Settings window shows three of the four permissions in one place: Notifications, Safari Automation and Automation for your default browser. The Safari setting is not shown there, because it lives inside Safari.

## Allow JavaScript from Apple Events in Safari

This is the setting that lets WebWatcher read the content of a page. Without it WebWatcher can open Safari but cannot see any element.

1. Open Safari, then choose **Safari > Settings**.
2. Click the **Advanced** tab.
3. Check **Show features for web developers**.

   **You see:** a **Develop** menu in the menu bar and a **Developer** tab in Settings.

4. Choose **Develop > Allow JavaScript from Apple Events**, or open the **Developer** tab in Settings and check **Allow JavaScript from Apple Events**.

   **You see:** a check mark next to the item.

Check it by adding or testing a watcher. If it is still off, the watcher's status reads "Enable JS from Apple Events" and its advice reads "Enable Safari → Settings → Developer → Allow JavaScript from Apple Events."

## Automation

Automation is the macOS permission that lets one app control another. WebWatcher asks for it for Safari and for your default browser. If Safari is your default browser, the two are the same permission.

macOS asks when WebWatcher first talks to the browser, with this text: "WebWatcher needs permission to control Safari or your default browser to monitor pages and reuse existing tabs."

Click **OK** when the prompt appears. The prompt closes and watchers start reading Safari.

If you clicked **Don't Allow**, or no prompt appears, switch it on by hand.

1. Open **System Settings > Privacy & Security > Automation**.
2. Find **WebWatcher** in the list.
3. Switch on **Safari**, and your default browser if it is a different app.

   **You see:** the switches are on. A watcher that was failing recovers at its next check.

WebWatcher can also open this pane for you. When Automation is missing it shows an alert named "Enable Browser Automation" with three buttons.

![The Enable Browser Automation alert: WebWatcher can't read open tabs in Safari yet, the Privacy and Security path, and the buttons OK, Reset Automation Permission and Open Automation Settings](/shots/permission-automation.png "The alert names the pane to open and offers **Reset Automation Permission** for the case where Safari is not listed.")

| Button | What it does |
|---|---|
| Open Automation Settings | Opens **System Settings > Privacy & Security > Automation**. |
| Reset Automation Permission | Clears WebWatcher's Automation choices so macOS asks again. Use it when WebWatcher is not listed in the pane. |
| OK | Closes the alert. |

After **Reset Automation Permission**, click **Check All Now** in the popover while Safari is open. macOS then shows the prompt again. The alert appears at most once every 30 seconds.

## Notifications

macOS asks for notification permission the first time WebWatcher starts. To change it later, or when you declined:

![The Configure Notifications dialog with five numbered steps for System Settings and the buttons Open Notification Settings and Later](/shots/permission-notifications.png "If you declined the macOS prompt, WebWatcher shows this dialog. **Open Notification Settings** takes you to the pane used in the steps below.")

1. Open **System Settings > Notifications**.
2. Select **WebWatcher** in the list.
3. Switch on **Allow Notifications**.
4. Set the alert style to **Banners** or **Alerts**.

   **You see:** banners from WebWatcher appear in the corner of the screen. The style **None** shows nothing.

> **Tip.** If you use Herald, banners come from Herald and WebWatcher falls back to macOS notifications only while Herald is not running. The macOS permission still matters for that fallback. See [Herald delivery](/docs/herald-delivery).

## Check the permissions in WebWatcher

The Settings window reports each permission with a coloured dot, so you can see what is missing without leaving WebWatcher.

1. Click the menu bar icon, then **Settings...**.
2. Scroll to the **Permissions** group.

   ![The Permissions group in Settings: Open System Automation Settings and Refresh, then Notifications, Safari Automation and Google Chrome Automation, each marked Granted with an Open button](/shots/settings-permissions.png "Each row shows a status, here **Granted**, and a button. The last row is named after your default browser, which is Google Chrome in this capture.")

   **You see:** three rows, **Notifications**, **Safari Automation** and a row named after your default browser, such as **Google Chrome Automation**.

3. Read the status under each name.

| Status | Dot | What it means | What to do |
|---|---|---|---|
| Granted | Green | macOS allows it. | Nothing. |
| Not granted | Red | macOS denied it. | Click the row's button, then switch it on in System Settings. |
| Not yet confirmed — click Check | Orange | macOS has not revealed the answer without showing a prompt. | Click **Check** and answer the prompt. |

The button on each row depends on the state. The **Notifications** button reads **Fix** when it is not granted and **Open** when it is. The Automation buttons read **Check** until granted and **Open** after that. **Open System Automation Settings** at the top opens the Automation pane, and **Refresh** reads all three again after you change something in System Settings. Every control in the group is also described in [Settings](/docs/settings).

## If it does not work

| What you see | Cause | Fix |
|---|---|---|
| A watcher reads "Enable JS from Apple Events". | The Safari setting is off. | Follow [Allow JavaScript from Apple Events in Safari](#allow-javascript-from-apple-events-in-safari). |
| A watcher reads "Automation permission needed". | WebWatcher may not control Safari. | Follow [Automation](#automation). |
| WebWatcher is missing from the Automation list. | macOS has no record of a request yet. | Use **Reset Automation Permission** in the alert, then click **Check All Now** with Safari open. |
| A row still reads **Not granted** after you allowed it. | The window read the status before the change. | Click **Refresh**. |
| No banners appear. | Notifications are off, or the style is **None**. | Follow [Notifications](#notifications). |
