A notification template is text you write for the title or body of an email watcher's notification, with placeholders that WebWatcher fills in from the newest unread message. This page is for anyone who wants the notification to say something other than the default, such as the invoice subject first or the watcher's name in the title. Templates apply to email watchers only. For page watchers, see [Custom icon, title, body](/docs/custom-notifications).

## Where the fields are

The template fields live in the **Notification** section of the email watcher editor. The section is collapsed until you open it.

1. Click the WebWatcher icon in the menu bar. To change an existing watcher, hover its row under **Email** and click the pencil button. To create one, click **Add Watcher** and choose the **Gmail sender** tab.

   **You see:** the email watcher form.

   ![The Edit Email Watcher window with the Notification section collapsed below the Play sound checkbox](/shots/gmail-sender-editor.png "**Notification** is the collapsed row below **Play sound**. Click it to show the template fields.")

2. Click **Notification**.

   **You see:** three fields and a button: **Custom Icon (optional)** with **Browse...**, **Custom Notification Title (optional)**, **Custom Body Template (optional)**, and **Preview Notification**.

3. Type your title in **Custom Notification Title (optional)** and your body in **Custom Body Template (optional)**.

4. Click **Save**.

An empty field uses the default text. A body template replaces the whole default body. The subtitle, which is the subject of the newest message, is not part of the template and always stays.

## Placeholders

A placeholder is a word in braces. WebWatcher replaces it when it builds the notification. Placeholders work in both the title and the body. Anything else you type stays as written, and a placeholder that WebWatcher does not know stays in the text unchanged.

| Placeholder | Becomes | Example value |
|---|---|---|
| `{count}` | The number of unread messages the watcher counts. It is never lower than 1. | 3 |
| `{sender}` | The display name of the newest message's sender, or the address if the message has no name. | Acme Billing |
| `{address}` | The sender's email address. | `billing@example.com` |
| `{subject}` | The subject of the newest message. | Invoice 1042 |
| `{time}` | When the newest message arrived, as "Today", "Yesterday" or a date, followed by the time. | Today 2:14 PM |
| `{name}` | The watcher's name. It is empty if you left **Name** empty. | Acme invoices |

`{sender}`, `{address}`, `{subject}` and `{time}` all describe the newest unread message, even when several are unread.

## Defaults

| Case | Title | Body |
|---|---|---|
| More than one unread message | `{count} new from {sender}` | Up to three recent subjects, each on a line starting with a bullet, then the start of the newest message (up to 120 characters), then `received {time}`. |
| One unread message | `Email from {sender}` | The same layout with one subject. |
| More than one Google account connected | The same as above. | The last line ends with a dash and the account's address. |

## Examples

### A minimal template

This title replaces the default and keeps the body the same.

```text Title template
{name}: {count} unread
```

With a watcher named Acme invoices and three unread messages, the notification title reads:

```text Result
Acme invoices: 3 unread
```

### A realistic template

This pair puts the sender and newest subject in the title, and the count, address and time in the body.

```text Title template
{sender}: {subject}
```

```text Body template
{count} unread from {address}, newest {time}
```

For three unread messages from Acme Billing, the newest being "Invoice 1042" received at 2:14 PM today, the notification reads:

```text Result
Acme Billing: Invoice 1042
3 unread from billing@example.com, newest Today 2:14 PM
```

## Preview a template

**Preview Notification** posts a sample notification built from your current fields, before you save.

1. Fill in the fields under **Notification**.

2. Click **Preview Notification**.

   **You see:** a notification whose title starts with "[Preview]". The editor says "Sent! Check your notifications." If macOS has not yet allowed notifications, the editor first asks for permission and may say "Permission denied. Enable in System Settings → Notifications".

The preview uses sample data: the sender is "Sample Sender", the subject is "Quarterly invoice", the unread count is at least 3, and the recent subjects are "Quarterly invoice", "Meeting notes" and "Welcome aboard". If you entered a full address in **Senders**, the preview uses it for `{address}`. Otherwise `{address}` shows `sender@example.com`. `{name}` is the name you typed, or your senders, or "Preview Watcher" when both are empty. Your own mail is not read or changed.
