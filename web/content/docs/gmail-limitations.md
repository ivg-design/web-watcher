Gmail support in WebWatcher is deliberately narrow: it watches the Inbox of Gmail accounts and counts, notifies and acts on mail, but it is not a mail client. This page is for anyone deciding whether a Gmail sender watcher fits their mail, or working out why a watcher does not see a message.

## Limits at a glance

| Limit | What it means for you | What to do instead |
|---|---|---|
| Only the Inbox is watched. | Mail filed straight to another label, to Spam or to Trash by a Gmail filter is not counted and does not notify. | Change the Gmail filter so the mail still reaches the Inbox. |
| Gmail accounts only. | Other mail providers cannot be connected. | Forward the mail to a Gmail address and watch that account. |
| Checks run on a timer. | A notification arrives within one poll interval of the mail, which is 1 minute by default and at least 30 seconds. WebWatcher must be running. | Shorten **Poll interval** under **Settings > Gmail**. See [Settings](/docs/settings#gmail). |
| The count covers the 25 newest matching unread messages. | A watcher with more than 25 unread messages shows 25 at most. | Read or archive older mail, or use more specific senders. |
| Mail older than two years is not counted. | Old unread mail from a sender does not appear in the count. | Read it in Gmail. |
| A domain entry covers one exact domain. | `@example.com` does not match `@mail.example.com`. | Add the subdomain as its own entry. |
| Your own client in Testing mode loses access every 7 days. | The account shows an error until you reconnect it. | Publish the OAuth app, or reconnect each week. |
| WebWatcher does not display mail. | The notification shows the sender, subject and the start of the message. Clicking it opens Gmail. | Read the message in Gmail. |

## Domain entries and the 25-message window

WebWatcher finds candidate mail with a Gmail search. Gmail's `from:` search has no way to say "this domain only", so a domain entry such as `@example.com` searches for the text `example.com`. The search can return unrelated messages that contain that text, for example from a sender whose display name mentions it. WebWatcher checks every result against your entry and discards the ones that do not match, but it examines only the 25 newest results. If many unrelated messages crowd the list, a real match can fall outside the 25 and go uncounted until the others are read or archived.

When this affects you, list the exact addresses instead of the domain. An address entry searches for that address and is not affected.

## Testing mode

If you sign in with your own Google OAuth client and its consent screen is External, the app stays in Testing mode until you publish it. In Testing mode Google ends access every 7 days. The account's row in **Settings > Gmail** then shows "Error:" and a **Reconnect** button, and the email watchers on it stop updating until you reconnect. Steps for choosing an account type and reconnecting are in [Sign in with Google](/docs/sign-in-with-google#use-your-own-google-oauth-client).
