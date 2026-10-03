WebWatcher can also watch for new mail from specific senders or domains arriving in the Inbox, and notify you the moment it lands. It starts with a normal Google sign-in.

![Settings, Gmail account section](/shots/settings-gmail.png)

## Sign in

Click *Add Gmail Account*, or *Sign in with Google* in the Gmail sender editor, sign in, and allow access. That is all. WebWatcher uses its own built-in Google OAuth client, so there is no console or JSON step for most people.

Access uses the smallest scope that can do the job, `gmail.modify`, so that Mark as Read, Archive, Delete and Spam can work. Tokens are stored in the macOS Keychain.

## Add a sender watcher

Choose Add Watcher → Gmail sender, pick the connected account, add one or more sender addresses or `@domain.com` patterns, and save. See [Sender & domain watchers](/docs/sender-and-domain-watchers).

## Advanced: use your own Google OAuth client

If you would rather not rely on WebWatcher's built-in client, or you are building from source without one bundled, import your own:

1. Open Google Cloud Console → APIs & Services → Credentials.
2. Create Credentials → OAuth client ID → Application type: Desktop app → Create → Download JSON.
3. Enable the Gmail API for that project.
4. On the OAuth consent screen: if your project belongs to a Google Workspace organization, choose Internal. Otherwise choose External and add yourself under Test users. While the app is in Testing, Google revokes access every 7 days and you will need to reconnect the account in Settings.
5. In WebWatcher, go to Settings → Gmail → Advanced: use your own Google OAuth client and import the JSON file.

An imported client always takes priority over the built-in one. Remove it from the same panel to go back.
