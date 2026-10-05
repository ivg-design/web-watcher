Every page watcher can have its own icon, title, body text and sound, so you can tell which watcher fired before you read the banner. Read this page when the default notification does not tell you enough, for example when you run several watchers and want each to look different. Gmail watchers have their own templates, described in [Notification templates](/docs/notification-templates).

## What you can customise

| Part | Default | Why change it |
|---|---|---|
| Icon | None. | A different logo per watcher shows which site pinged you, even in a stack of banners. |
| Title | The watcher's name. | A title such as "3 LinkedIn messages" carries the number without opening the banner. |
| Body | A sentence chosen by the watch type. | Your own wording can say what to do next. |
| Sound | On. | Turn it off for watchers you want to see but not hear. |

All four are set per watcher. Where the notification appears, and in which style, is a delivery setting; see [Herald delivery](/docs/herald-delivery) and [Settings](/docs/settings).

## Open the Notification section

1. Click the WebWatcher icon in the menu bar.
2. To edit a watcher, move the pointer over its row and click the pencil button. To create one, click **Add Watcher**.

   **You see:** the **Edit Watcher** or **Add Watcher** window.

3. Scroll to the bottom of the window and click **Notification**.

   **You see:** the section expands and shows the sound checkbox, the icon, title and body fields, and **Preview Notification**.

   ![The Edit Watcher window with the Notification section expanded at the bottom: Play sound with notification, Custom Icon with Browse, Custom Notification Title, Custom Body Template and Preview Notification](/shots/watcher-editor-advanced.png "The **Notification** section is the last one in the editor. Its five controls are described in the table below.")

4. Fill in the fields you want.
5. Click **Save**.

## The fields

| Field | What it does | Default | When to change it |
|---|---|---|---|
| Play sound with notification | Plays the default notification sound with each banner. | On. | Turn it off for a watcher that fires often. |
| Custom Icon (optional) | Shows your image on the notification. Type a path or click **Browse...** to choose a file. The cross button clears it. | Empty, so no image is attached. | You want to tell watchers apart by logo. |
| Custom Notification Title (optional) | Replaces the title. Placeholders work here. | Empty, so the title is the watcher's name. | You want the value in the title. |
| Custom Body Template (optional) | Replaces the body text. Placeholders work here. | Empty, so the body depends on the watch type. | The default sentence is not specific enough. |

### Custom icon

The icon must be a PNG, JPG or ICNS file. WebWatcher copies the file into its own folder, `~/Library/Application Support/WebWatcher/icons/`, when you save, so moving or deleting the original does not remove the image from later notifications. macOS shows the image as a square, so WebWatcher crops it to the centre. A square image looks best.

## Placeholders

Placeholders are words in curly braces that WebWatcher replaces with real values when it sends the notification. They work in both the title and the body.

| Placeholder | What it becomes |
|---|---|
| `{value}` | The reading that triggered the notification, for example `3`. |
| `{previous}` | The reading before it, or `0` when there was no earlier reading. |
| `{name}` | The watcher's name. |

A minimal template, with the result for a reading of 3:

```text Body template
{value} new messages waiting
```

```text Result
3 new messages waiting
```

A realistic setup for a LinkedIn watcher that went from 2 to 5:

```text Title template
You've got {value} LinkedIn messages
```

```text Body template
{name} went from {previous} to {value}.
```

```text Result
Title: You've got 5 LinkedIn messages
Body: LinkedIn Messages went from 2 to 5.
```

Any other text in braces stays as you typed it. The `{value}` of an Anything Changes Inside watcher is an internal fingerprint, so leave it out of those templates.

## When a watcher notifies

A watcher notifies only when its check succeeds and the reading differs from the last good one. The first reading of a watcher is a baseline and does not notify, except for Element Exists. This table shows the trigger for each watch type and the body you get when **Custom Body Template (optional)** is empty.

| Watch type | It notifies when | Default body |
|---|---|---|
| Badge/Number | The number goes up. | "You have 3 new messages", or "You have 1 new message" for one. A reading that is not a whole number, such as a capped `9+`, gives "New activity detected". |
| Element Count | The count goes up. | "2 new items (7 total)", or "1 new item (7 total)" for one. |
| Text Change | The text changes. | "Content updated". The subtitle holds the first 100 characters of the new text. |
| Element Exists | The element appears. | "Element appeared". |
| Element Disappears | The element goes away. | "Element disappeared". |
| Anything Changes Inside | Anything inside the element changes. | "Something changed inside the watched area". |

A badge that goes from 2 to 3 notifies. A badge that stays at 3 does not. [Watch types](/docs/watch-types) explains each type in full.

> **Note.** A watcher that stops working sends a separate notification whose title is the watcher's name followed by "isn't working". Its text cannot be customised.

## Preview a notification

Preview shows what the notification will look like without waiting for a change.

1. Open the **Notification** section and fill in the icon, title and body.
2. Click **Preview Notification**.

   **You see:** the status line "Sent! Check your notifications." and a notification whose title starts with "[Preview]". The preview uses `3` for `{value}` and `0` for `{previous}`, and it always plays the sound.

If macOS has not allowed notifications for WebWatcher, the status line reads "Permission denied. Enable in System Settings → Notifications".

The preview uses the fields as they are on screen, so you can try a template before you save it.

## If it does not work

| What you see | Cause | Fix |
|---|---|---|
| The title or body shows `{value}` literally. | The placeholder is misspelled or has the wrong braces. | Use `{value}`, `{previous}` or `{name}` exactly. |
| The icon is missing from the notification. | The file is not a PNG, JPG or ICNS image, or it cannot be read. | Choose another file with **Browse...**. |
| The preview says "Permission denied. Enable in System Settings → Notifications". | macOS blocks notifications for WebWatcher. | Open **System Settings > Notifications > WebWatcher** and allow notifications. |
| No notification arrives when the number changes. | The number did not go up, or this was the first reading. | See [Troubleshooting](/docs/troubleshooting). |
