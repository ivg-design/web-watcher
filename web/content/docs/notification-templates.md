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

A watcher named Rive team with the title template `{count} new from {sender}` shows "3 new from Rive team" and a body such as "Scripting update · Office hours · Release notes, received Today 8:14 PM".

> **Tip.** Use the preview in the editor to check your template. Previews carry a "[Preview]" marker so you can tell them from real mail.
