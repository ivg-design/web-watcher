Every watcher can have its own icon, title and body, so you know which platform pinged you before you read a word.

## Custom icon

Set a different icon for each watcher. A notification with the Rive logo and one with the Contra logo are different at a glance, even in a stack of banners.

## Title and body

For page watchers the title defaults to the watcher's name and the body says what changed: a badge watcher reads "You have 3 new messages", a text watcher shows the new text, and an Anything Changes Inside watcher says something changed inside the watched area. Set your own title and body to override these. Templates for page watchers can use `{value}` (the new reading), `{previous}` (the one before) and `{name}` (the watcher's name).

For Gmail watchers, the title and body come from templates. See [Notification templates](/docs/notification-templates) for the placeholders.

## Smart filtering

WebWatcher only notifies when the value changes. A badge that went 2 → 3 produces a notification; a badge that is still 3 stays silent. The notification reaches Notification Center with a sound, or Herald if it is running.

## Where to change them

Open the watcher in the editor and use the Notification section. System-wide delivery is chosen under Settings → Notifications → Delivery. See [Herald delivery](/docs/herald-delivery).
