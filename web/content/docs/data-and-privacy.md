Everything stays on your machine. There are no servers, no analytics and no data collection.

## What is stored, and where

- **Configuration.** Stored locally at `~/Library/Application Support/WebWatcher/watchers.json`.
- **Gmail tokens.** Stored in the macOS Keychain, not in a file.

## What the app talks to

- **Safari**, through AppleScript, to run JavaScript in tabs you already have open. It uses your existing signed-in sessions; WebWatcher never sees a password.
- **Notification Center**, or **Herald** if you chose it.
- **Google**, only if you connect a Gmail account, and only with the `gmail.modify` scope.

Nothing leaves your computer for any other purpose.

## Signed and open

The app is signed with a Developer ID, notarized by Apple, MIT licensed, and the source is on GitHub.

## The three permissions

Safari JavaScript from Apple Events, Automation for Safari and System Events, and Notifications. See [Permissions](/docs/permissions).
