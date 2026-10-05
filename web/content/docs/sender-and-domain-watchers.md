A Gmail sender watcher tells you when unread mail arrives in your Inbox from addresses or domains you choose, such as an invoicing system or a client's whole company. It is a list of senders, not a copy of your inbox: WebWatcher keeps a live unread count for that list and notifies you when it grows. This page is for anyone who has [connected a Google account](/docs/sign-in-with-google) and wants a notification for specific mail.

## How a sender watcher works

Each watcher has one Gmail account and one or more senders. On every check, WebWatcher asks Gmail for unread Inbox mail from those senders and counts the messages that match. Reading or archiving a message in Gmail lowers the count at the next check. A notification appears when a new unread message from the list arrives.

Mail that already sits unread in your Inbox when you create the watcher is counted but does not notify you. Only mail that arrives afterwards does.

## Add a sender watcher

1. Click the WebWatcher icon in the menu bar, then **Add Watcher**.

   **You see:** the Add Watcher window with two tabs, **Web page** and **Gmail sender**.

2. Click the **Gmail sender** tab.

   ![The Add Watcher window on the Gmail sender tab: Name, the Gmail account picker, an empty Senders field with Add, Play sound and a dimmed Save](/shots/add-watcher-gmail.png "The **Gmail sender** tab with an account connected. **Save** stays dimmed until at least one sender is listed.")

   **You see:** the Add Email Watcher form. If no account is connected, it shows **Sign in with Google** instead of the account picker. Connect first as described in [Sign in with Google](/docs/sign-in-with-google).

3. Type a name in **Name**. If you leave it empty, the watcher is listed by its sender addresses.

4. Choose the account in the **Gmail account** picker.

5. Type an address or domain in the **Senders** field and click **Add**, or press <kbd>Return</kbd>.

   **You see:** the entry appears in a list under the field. Repeat for each sender.

   ![The Edit Email Watcher window: Name, the Gmail account picker, a Senders field with an address and a domain listed below it, Play sound and the collapsed Notification section](/shots/gmail-sender-editor.png "Each sender you add is listed under the **Senders** field with a button to remove it.")

6. Leave **Play sound** checked if you want a sound with the notification.

7. Click **Save**.

   **You see:** the watcher under **Email** in the menu bar popover.

To change a watcher later, hover its row in the popover and click the pencil button. The same form opens as Edit Email Watcher, with **Delete** at the bottom.

## Sender formats

The **Senders** field takes two kinds of entry. WebWatcher turns what you type into lowercase.

| Format | Example | What it matches |
|---|---|---|
| A full address | `billing@example.com` | Mail from exactly that address. |
| A domain, starting with `@` | `@example.com` | Mail from any address at that domain. |

A domain entry matches the whole domain only. `@example.com` matches `anna@example.com` but not `anna@mail.example.com` or `anna@notexample.com`. Add `@mail.example.com` as a separate entry to cover a subdomain.

You can paste several entries at once. Separate them with commas, semicolons, spaces or new lines. WebWatcher drops duplicates. An address copied as `Name <person@example.com>` is reduced to the address. Text with no `@` is rejected with "Enter an email address or @domain".

## What you see in the menu

Email watchers have their own **Email** group in the menu bar popover.

![The WebWatcher popover after new mail: an Email group with one Gmail watcher, the line 3 unread with the time of the latest message, and a blue badge with 3](/shots/popover-changed.png "Gmail watchers are listed under **Email**. The blue badge is the unread count.")

| Part of the row | What it shows |
|---|---|
| Name | The watcher's name, or its senders if you left the name empty. |
| Status line | "3 unread · latest Today 22:45" when mail is unread, "No unread" when everything is read, "No email yet" before any mail from the senders has been seen, or "Error:" and the reason. |
| Badge | The unread count. |
| Hover buttons | A pencil to edit the watcher and an arrow to open Gmail. |

## The notification

A watcher posts one notification, and each new message updates that same notification instead of adding another. The text comes from your newest unread message and your unread count. You can [change the text with templates](/docs/notification-templates).

| Part | Default content |
|---|---|
| Title | "3 new from Acme Billing", or "Email from Acme Billing" for one unread message. |
| Subtitle | The subject of the newest message. |
| Body | Up to three recent subjects as bullet lines, the start of the newest message (up to 120 characters), then "received" and the time. With more than one Google account connected, the line ends with the account's address. |

### What clicking it opens

| Unread messages | What opens in your browser |
|---|---|
| One | That email in Gmail. |
| More than one | A Gmail search for unread Inbox mail from the watcher's senders. |
| None | Your Gmail Inbox. |

Clicking the watcher's row in the menu bar popover opens the same page.

### The action buttons

The notification carries four buttons. Each acts on every message counted by the watcher, not only the newest one. When the action succeeds, the watcher's unread count resets and the notification is dismissed.

| Button | What it does in Gmail |
|---|---|
| Mark as Read | Removes the unread mark. The message stays in the Inbox. |
| Archive | Removes the message from the Inbox. It stays in All Mail. |
| Delete | Moves the message to Trash. Nothing is deleted permanently, and you can restore the message from Trash in Gmail. |
| Spam | Removes the message from the Inbox and files it as spam. |

## Notify for every new email

An email watcher tells you about mail from the senders you listed. The **Notify for every new email** checkbox widens that for one account: it notifies you about every new Inbox message that no watcher already covers.

1. Open **Settings > Gmail**.

2. Find the account's row and check **Notify for every new email**.

   **You see:** the checkbox is on. It is off by default.

Use it when you want the account to behave like a general mail notifier, for example for a mailbox that receives little mail. Leave it off for a busy mailbox, where it produces a notification for every message. These notifications are per message: the title is the sender's name, the subtitle is the subject, and the body is the start of the message and its Gmail labels. They carry the same four buttons but do not use templates.

## How often mail is checked

WebWatcher checks each connected account every minute by default. The **Poll interval** setting in Settings changes this to 30 seconds, 2, 5 or 10 minutes, for all accounts at once. See [Settings](/docs/settings#gmail). The editor's footer shows the interval in use.

## If it does not work

| What you see | Cause | Fix |
|---|---|---|
| **Save** is dimmed. | No account is chosen, or the sender list is empty. | Pick an account and add at least one sender. |
| The status reads "No email yet" while mail exists. | The mail is not in the Inbox, is more than two years old, or came from an address your entries do not match. | Check the Inbox and compare the sender's exact address with your entry. See [Limitations](/docs/gmail-limitations). |
| The status reads "Error: Reconnect required". | Google ended the session. | Click **Reconnect** under **Settings > Gmail**. |
| The count is lower than you expect. | Only unread Inbox mail counts, and WebWatcher looks at the 25 newest matches. | Read or archive older messages, or narrow the sender entry. |
| A domain entry misses mail. | Gmail's search for a domain also returns unrelated mail that contains the same text, and WebWatcher examines only the 25 newest results. | List the exact addresses you care about. |
