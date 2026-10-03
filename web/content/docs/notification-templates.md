Each email watcher has a Notification section where you set a custom icon, title and body. Templates can use placeholders that are filled in when the notification is built.

## Placeholders

| Placeholder | Becomes |
|-------------|---------|
| `{count}` | The number of unread messages counted |
| `{sender}` | The sender |
| `{address}` | The sender's address |
| `{subject}` | The subject |
| `{time}` | When the newest message arrived |
| `{name}` | The watcher's name |

## Defaults

The default title is `{count} new from {sender}`, or `Email from {sender}` for a single message. The default body is the latest subjects followed by `received {time}`.

## An example

With the default title template, three unread messages from Acme Billing produce "3 new from Acme Billing". The body lists the latest subjects, followed by "received" and the time the newest one arrived.

> **Tip.** Use the preview in the editor to check your template. Previews carry a "[Preview]" marker so you can tell them from real mail.
