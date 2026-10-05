This page is for anyone installing WebWatcher for the first time or updating it. It lists what your Mac needs, walks through the install, shows how to check the download, and explains how to update without losing your watchers.

## Requirements

WebWatcher is a menu bar app. It reads pages from Safari tabs you already have open, so Safari and a few macOS permissions are part of the setup.

| Requirement | Why WebWatcher needs it | Required or optional |
|---|---|---|
| macOS 13 or later. | The app is built for macOS 13 and does not start on an earlier system. | Required. |
| Safari. | WebWatcher reads the page in your own Safari tab, so there is no separate login and no browser extension. | Required for page watchers. |
| **Allow JavaScript from Apple Events** switched on in Safari. | This is how WebWatcher reads the page. See [Permissions](/docs/permissions). | Required for page watchers. |
| Automation permission for Safari. | macOS asks before one app may control another. See [Permissions](/docs/permissions). | Required for page watchers. |
| Notification permission. | Without it, macOS shows no banners. | Optional, recommended. |
| A Google account. | It is the only way to watch a Gmail sender. See [Sign in with Google](/docs/sign-in-with-google). | Optional. |
| [Herald](/docs/herald-delivery). | It shows banners that stay on screen until you act on them. | Optional. |

## Install

1. Download the latest DMG from the [download section](/#download) or from GitHub Releases.

   **You see:** a file named like `WebWatcher-<version>-macOS.dmg`, about 3 MB. It is signed and notarized by Apple, so macOS opens it without a warning.

2. Open the DMG, then drag `WebWatcher.app` into the **Applications** folder.

   **You see:** `WebWatcher.app` in Applications.

3. Open `WebWatcher.app` from Applications.

   **You see:** a small hourglass icon with an eye in the menu bar. WebWatcher has no Dock icon and no window until you click the menu bar icon.

4. Allow notifications when macOS asks.

   **You see:** a macOS prompt to allow notifications from WebWatcher. If you decline, WebWatcher shows an alert named "Configure Notifications" with an **Open Notification Settings** button.

5. Click the menu bar icon.

   ![The WebWatcher popover before any watcher exists: No watchers configured, Add Watcher, a dimmed Check All Now, Settings and Quit](/shots/popover-empty.png "On a new install the list reads \"No watchers configured\". **Add Watcher** is the next step; **Settings...** shows the state of every permission.")

   **You see:** the popover. It has no watchers yet.

6. Set up Safari and grant Automation access as described in [Permissions](/docs/permissions), then add a watcher as described in [Your first watcher](/docs/first-watcher).

## Verify the download

Each release publishes a checksum file next to the DMG, named like `WebWatcher-<version>-macOS.dmg.sha256`. Compare it with the checksum of the file you downloaded when you want to be sure the download is intact.

1. Open Terminal and go to the folder that holds the DMG.
2. Print the checksum of the DMG and of the published file:

   ```bash
   shasum -a 256 WebWatcher-*.dmg
   cat WebWatcher-*.dmg.sha256
   ```

   **You see:** two lines that each start with a 64-character value.

3. Compare the two values.

   **You see:** identical values when the download is intact. The file name after the value can differ, because it is the path on the build machine.

## Update WebWatcher

Your watchers and settings are stored outside the app, in `~/Library/Application Support/WebWatcher/`, so replacing the app does not touch them.

1. Quit WebWatcher: click the menu bar icon, then **Quit**.
2. Download the latest DMG from the [download section](/#download).
3. Open the DMG and drag `WebWatcher.app` into **Applications**. Choose **Replace** when Finder asks.

   **You see:** the copy in Applications is now the one from the DMG.

4. Open `WebWatcher.app`.

   **You see:** the menu bar icon, with your watchers in the popover as you left them. **Settings...** shows the installed version in the About group.

## If it does not work

| What you see | Cause | Fix |
|---|---|---|
| The menu bar icon does not appear. | The app is not running, or the menu bar is full and hides it. | Open `WebWatcher.app` again, and close other menu bar apps if your Mac has no room. |
| macOS refuses to open the app. | The file is not the signed release, or the download was cut short. | Download it again from the [download section](/#download) and [verify the download](#verify-the-download). |
| There are no banners. | Notifications are off for WebWatcher. | Follow the notifications steps in [Permissions](/docs/permissions). |
| Watchers report "Automation permission needed" or "Enable JS from Apple Events". | A Safari permission is missing. | Follow [Permissions](/docs/permissions). |
