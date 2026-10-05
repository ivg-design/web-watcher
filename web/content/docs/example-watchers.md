This page shows five complete watchers with the exact value for every field: four for sites that have a built-in profile, and one for a site that does not. Use it when you want a working setup to copy, or to see how a field in the Add Watcher window is meant to be filled in.

## Where the values go

Every value below goes into the **Add Watcher** window. Click the WebWatcher icon in the menu bar, then **Add Watcher**.

![The Add Watcher window on its Web page tab: the Site picker, Name, the Which element? step 1 Page, Check Interval, Watch Type and the collapsed Advanced and Notification sections](/shots/add-watcher-page.png "Each example fills the fields in this order: **Site**, **Name**, the page address under **Which element?**, **Watch Type**, then **Advanced** for selectors.")

| Field | Where it is | What it holds |
|---|---|---|
| Site | Top of the window. | A built-in profile, or **Custom (choose elements yourself)**. |
| Name | Below **Site**. | The label shown in the menu and in notifications. |
| URL | Under **Which element?** in step **1 · Page**. With a profile, it is the field **URL to Monitor (must be open in Safari)**. | The page the watcher reads. |
| Watch Type | Below **Check Interval**. | What counts as a change. See [Watch types](/docs/watch-types). |
| CSS Selector | In **Advanced**, under **Selector Type**. | The element to read. See [Watcher options](/docs/watcher-options). |

When a site has a built-in profile, pick the profile and leave the selector alone. The profile carries a selector and an anchor that were captured from the live page, and it sets **Watch Type**, the reading strategy and **Force refresh before checking** for you. Typing a selector by hand gives a worse result. See [Site profiles](/docs/site-profiles).

> **Note.** Third-party sites change their pages. If a watcher stops reading, run **Run Diagnosis** in its editor, and if it still fails, re-pick the element with the guided picker. See [Finding the element](/docs/finding-the-element).

## Contra messages

Counts unread messages in the Contra side navigation. Choose the profile **Contra Messages**.

| Field | Value |
|---|---|
| Site | Contra Messages |
| Name | Contra Messages |
| URL | `https://contra.com/community/for-you` |
| Watch Type | Badge/Number |

The URL is a page that shows the side navigation. Contra's public profile pages have none, so a watcher on one of them cannot see the badge. Clicking the notification opens `https://contra.com/messages`.

## Reddit inbox

Counts the unread items behind the inbox button in the Reddit header. Choose the profile **Reddit Inbox**.

| Field | Value |
|---|---|
| Site | Reddit Inbox |
| Name | Reddit Inbox |
| URL | `https://www.reddit.com/` |
| Watch Type | Badge/Number |

The profile reads the badge's text, not its `initial-count` attribute. Reddit writes that attribute only when the page loads, so it can show an old number while the badge itself shows the current one. Clicking the notification opens `https://www.reddit.com/notifications`. Reddit's chat badge has its own profile, **Reddit Chat**.

## LinkedIn notifications

Counts the unread notifications on the LinkedIn navigation bar. Choose the profile **LinkedIn Notifications**.

| Field | Value |
|---|---|
| Site | LinkedIn Notifications |
| Name | LinkedIn Notifications |
| URL | `https://www.linkedin.com/feed/` |
| Watch Type | Badge/Number |

LinkedIn writes the count into the accessibility label of the Notifications link, including "0 new notifications". That is why the profile reads the label instead of the badge: zero is stated by the site. Clicking the notification opens `https://www.linkedin.com/notifications/`. For messages, choose **LinkedIn Messages**.

## Rive Community notifications

Counts the unread notifications on the Rive Community bell. Choose the profile **Rive Community Notifications**.

| Field | Value |
|---|---|
| Site | Rive Community Notifications |
| Name | Rive Community Notifications |
| URL | `https://community.rive.app/feed` |
| Watch Type | Badge/Number |

The community site removes the badge from the page when the count is zero. The profile watches the bell button, which is always there, and treats a button with no badge as a confirmed zero. The profile turns **Force refresh before checking** on, because Safari does not repaint a tab that is in the background. Direct messages have their own profile, **Rive Community Direct Messages**.

## GitHub notifications

GitHub has no built-in profile, so this watcher is set up by hand. It notifies when the notification indicator appears.

| Field | Value |
|---|---|
| Site | Custom (choose elements yourself) |
| Name | GitHub notifications |
| URL | `https://github.com/notifications` |
| CSS Selector | `.notification-indicator` |
| Watch Type | Element Exists |

Element Exists fits because the indicator is a dot with no number. It notifies when the dot appears, and again each time it comes back after you clear your notifications.

To enter these values:

1. In the **Add Watcher** window, leave **Site** on **Custom (choose elements yourself)** and type the **Name**.
2. Under **Which element?**, enter the URL in step **1 · Page**.
3. Expand **Advanced**, make sure **Selector Type** is **CSS Selector**, and type the selector into the selector field.
4. Set **Watch Type** to **Element Exists**.
5. Click **Save**.

   **You see:** the window closes and the watcher is checked straight away.

A selector on a third-party site can stop matching when the site changes its markup. The guided picker finds a selector for you; see [Finding the element](/docs/finding-the-element).
