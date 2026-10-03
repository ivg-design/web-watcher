Gmail support is deliberately narrow. These are the edges to know about.

## What is and is not seen

- Only mail that lands in the Inbox is seen. Archived, spam and other-label messages are not watched.
- Gmail accounts only. Other mail providers are not supported.
- Domain watchers (`@company.com`) establish their starting point with a search query that can, in rare cases, miss a message that should have matched. New mail from that domain is still caught going forward.

## Testing mode

If you use your own OAuth client in Testing mode, Google revokes access every 7 days and you need to reconnect the account in Settings.

## Not a mail client

WebWatcher counts, notifies and acts (Mark as Read, Archive, Delete, Spam). Clicking a notification opens the message in Gmail, which is where you read it.
