This page is the reference for every field in the two watcher editors: the one for a web page and the one for a Gmail sender. Read it when you want to change how one watcher behaves, or when a field in the editor is not self-explanatory. To create a watcher for the first time, start with [Your first watcher](/docs/first-watcher) instead.

## Open a watcher's editor

1. Click the WebWatcher icon in the menu bar.
2. Click **Add Watcher** to create a watcher. To edit one, move the pointer over its row and click the pencil button that appears.

   **You see:** a window titled **Add Watcher** or **Edit Watcher**. A new watcher has two tabs at the top, **Web page** and **Gmail sender**. The tab decides which of the two editors below you get.

   ![The Add Watcher window with the Web page and Gmail sender tabs at the top, Web page selected](/shots/add-watcher-page.png "The two tabs at the top appear only for a new watcher.")

3. Change what you need, then click **Save**.

   **You see:** the window closes and the watcher is checked straight away.

**Cancel** closes the editor without saving. **Delete** appears only when you edit an existing watcher, and removes it.

## Web page watcher

A web page watcher reads one element of a page that is open in Safari. The fields run from top to bottom in the order below.

![The Edit Watcher window for a page watcher: Site, Name, the three Which element? steps with the Confirm card, Check Interval, Watch Type, and the collapsed Advanced and Notification sections above Delete and Save](/shots/watcher-editor.png "The editor for a page watcher. **Advanced** and **Notification** are collapsed when the window opens.")

### Main fields

| Field | What it does | Default | When to change it |
|---|---|---|---|
| Site | Chooses a built-in recipe for a known site, or **Custom (choose elements yourself)**. A recipe fills in the selector and the reading strategy for you. | Custom. | Pick your site if it is in the list. See [Site profiles](/docs/site-profiles). |
| Name | Names the watcher in the menu and in its notifications. | Empty. | Give every watcher a name you will recognise in a banner. |
| Which element? | Runs the three steps Page, Element and Confirm that find the element to watch. | | See [Finding the element](/docs/finding-the-element). |
| Check Interval | Sets how often WebWatcher reads the page: 15 or 30 seconds, or 1, 2, 5, 10 or 30 minutes. | 30 seconds. | Lengthen it for pages that change rarely, or when you use **Force refresh before checking**, because each check of a background tab then reloads it. |
| Watch Type | Decides what counts as a change. | Badge/Number. | The Confirm step sets it from the element you picked. See [Watch types](/docs/watch-types). |

### Advanced

Click **Advanced** to expand it. These fields are filled in by the element picker. Change them by hand only when the picker cannot reach the element.

![The Edit Watcher window with Advanced and Notification expanded: Selector Type, CSS Selector with Help, Anchor with Suggest, Strategy with Clear, two checkboxes, Action URL, API Lookup Command, then the Notification controls](/shots/watcher-editor-advanced.png "Both sections expanded. **Advanced** runs from **Selector Type** to **API Lookup Command (optional)**; **Notification** follows it.")

| Field | What it does | Default | When to change it |
|---|---|---|---|
| Selector Type | Switches the selector field between **CSS Selector** and **XPath**. | CSS Selector. | Use XPath when the element can only be found by its text or position. |
| CSS Selector or XPath | Holds the selector that finds the element. **Help** opens a guide to the syntax. | Set by the picker. | Paste a selector you copied from Safari's Web Inspector. |
| Badge Attribute (optional) | Names an attribute to read the number from, instead of the element's text. It is shown only for the Badge/Number watch type. | Empty, which reads the text. | The count is in an attribute, as on sites built with web components. |
| Anchor (recommended) | Holds the selector of an element that is always on the page, next to the badge. With an anchor, a missing badge is read as zero. Without one, WebWatcher cannot tell zero from a page that failed to load. **Suggest** proposes anchors found on the page. It is hidden when a site recipe is selected. | Set by the picker when it can. | The Confirm step reports "No anchor set — a missing badge is ambiguous". |
| Strategy | Shows how the value is read: Accessibility label, Anchor + badge, Tab title (N), Anchor + any number, or Manual. It is read-only. **Clear** resets it to Manual. | Set by the picker. | Clear it only if you typed your own selector and want it used as written. |
| Open the page automatically if no tab is found | Opens the watcher's URL in Safari when no matching tab exists. | On. | Turn it off if you do not want WebWatcher to open tabs for you. The watcher then reports that the tab was not found. |
| Force refresh before checking | Reloads the Safari tab before a check whenever the tab is not the one in front. A tab you are looking at is never reloaded. | Off. | The watcher shows a stale value. See [Force refresh and hidden tabs](/docs/force-refresh). |
| Settle delay | Sets the wait after a reload before reading, from 0.5 to 5.0 seconds in steps of 0.5. It is shown while Force refresh is on. | 2.0 seconds. | Raise it for pages that draw their badge late. |
| Action URL (optional) | Sets the page that opens when you click the notification or the watcher's row. | Empty, which opens the watched URL. | The page you watch is not the page you want to land on. |
| API Lookup Command (optional) | Runs a shell command when you open the watcher, and opens the URL the command prints. | Empty. | The destination is different every time, for example the newest message. See below. |

#### Selector examples

A minimal CSS selector, valid for any element with the class `badge`:

```css
.badge
```

A realistic one, for a count that a web component keeps in an attribute. Put the selector in **CSS Selector** and the attribute's name, here `data-count`, in **Badge Attribute (optional)**:

```css
nav-badge[data-id="inbox-count"]
```

The same kind of element as XPath:

```xpath
//a[contains(@href, 'messages')]
```

#### API Lookup Command

The command runs when you click the watcher's row or its notification. It must print one URL to standard output. Two placeholders are replaced before it runs.

| Placeholder | Becomes |
|---|---|
| `{url}` | The watcher's URL. |
| `{domain}` | The domain of that URL. |

A minimal command:

```bash
echo https://example.com/inbox
```

A realistic one, which asks a site's API for the address of the newest message:

```bash
curl -s https://api.example.com/messages/latest
```

> **Warning.** The command runs with your user account's rights each time you open the watcher. Only enter a command you wrote or understand.

### Notification

Click **Notification** to expand it. These fields change how this watcher's notification looks and sounds. [Custom notifications](/docs/custom-notifications) explains them with examples.

| Field | What it does | Default |
|---|---|---|
| Play sound with notification | Plays the notification sound when this watcher notifies. | On. |
| Custom Icon (optional) | Shows an image of your choice in the notification. **Browse...** picks a PNG, JPG or ICNS file. | The WebWatcher icon. |
| Custom Notification Title (optional) | Replaces the title. You can use `{value}`, `{previous}` and `{name}`. | The watcher's name. |
| Custom Body Template (optional) | Replaces the body. It accepts the same three placeholders. | A sentence that fits the watch type. |
| Preview Notification | Sends a sample notification now. Its title starts with "[Preview]". | |

### Run Diagnosis

A watcher that uses a site recipe has a **Run Diagnosis** button at the bottom of the editor. It checks the whole chain in order: Safari running, tab found, element found, the reading from the page, and whether zero can be confirmed. For a custom watcher the same report is part of the Confirm step, with **Test again** to repeat it.

## Gmail sender watcher

A Gmail sender watcher counts unread Inbox mail from the senders you list. It needs a connected Google account. See [Sign in with Google](/docs/sign-in-with-google).

![The Edit Email Watcher window: Name, the Gmail account picker with Connect another account, a Senders field with an address and a domain listed, Play sound, the collapsed Notification section, Delete and Save](/shots/gmail-sender-editor.png "Two senders are listed: one address and one domain. The line under **Notification** states how often mail is checked.")

| Field | What it does | Default |
|---|---|---|
| Name | Names the watcher in the menu and in its notifications. | Empty. |
| Gmail account | Chooses which connected account to read. **Connect another account…** adds one without leaving the editor. | The first connected account. |
| Senders | Lists the addresses and domains to watch. Type one, then click **Add**. The ⊗ beside an entry removes it. | Empty. |
| Play sound | Plays the notification sound when this watcher notifies. | On. |
| Notification | Expands to the icon, title and body fields. See [Notification templates](/docs/notification-templates). | Collapsed. |

A sender is written in one of two forms.

| Form | Example | Matches |
|---|---|---|
| An address | `billing@example.com` | Mail from that address only. |
| A domain | `@example.com` | Mail from anyone at that domain. |

How often Gmail is checked is not set here. It is the **Poll interval** in [Settings](/docs/settings#gmail), and it applies to every Gmail watcher.

## If it does not work

| What you see | Cause | Fix |
|---|---|---|
| **Save** is dimmed. | **Name**, the URL or the selector is empty. | Fill in **Name**, then finish the Page, Element and Confirm steps or type a selector under **Advanced**. |
| The watcher reads a value once and never changes. | Safari has stopped updating the background tab. | Turn on **Force refresh before checking**. |
| A badge watcher reports an error whenever the count is zero. | No anchor is set, so a missing badge cannot be told apart from a missing page. | Fill in **Anchor (recommended)**, or click **Suggest**. |
| The Gmail editor shows **Sign in with Google** instead of the fields. | No Google account is connected. | Sign in. The fields appear when the account is connected. |

For error messages, see [Troubleshooting](/docs/troubleshooting).
