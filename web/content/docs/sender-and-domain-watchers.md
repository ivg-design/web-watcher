A Gmail watcher is a sender pattern, not an inbox. You tell WebWatcher which addresses matter and it counts what is unread from them.

![The Gmail sender watcher editor](/shots/gmail-sender-editor.png)

## Senders and domains

In the Gmail sender editor, the Senders field takes one or more addresses or `@domain.com` patterns, for example `hello@rive.app, @rive.app`. A pattern with a domain matches everyone at that domain.

## A live unread count

Each email watcher keeps a live unread count. Every check asks Gmail for unread Inbox mail from the watched senders, so reading a message in Gmail lowers the count on the next check. The menu shows the count next to the watcher.

## One notification per watcher

New mail produces one notification per watcher, and it is replaced in place rather than stacking: "2 new from Acme Billing", the latest subjects, and when the newest one arrived.

Clicking it opens the email itself when there is one unread message, or a Gmail search for the unread mail from those senders when there are several. Mark as Read, Archive, Delete and Spam act on all counted messages. Delete moves the messages to Trash once; nothing is removed permanently.

## Notify for every new email

Each connected account also has a *Notify for every new email* toggle in Settings. Turn it on to be told about every Inbox message from that account, not only the senders you have set up watchers for.
