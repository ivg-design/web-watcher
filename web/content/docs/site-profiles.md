A site profile is a built-in recipe for one counter on one site, such as LinkedIn Notifications. It fills in the page address, the selector and the way the number is read, so you skip the element picker. Read this page if you watch one of the listed sites, or if you want to know what the **Site** picker in the watcher editor does.

## What a profile is for

Some badges are hard to read. LinkedIn states its count in an accessibility label. Rive Community removes the badge from the page when the count is zero. Contra draws its numbers as an animated odometer. Each built-in profile was captured from the live, signed-in page and stores what works for that site, so you do not have to find it by trial and error.

A profile fills in these watcher fields:

| Field | What the profile sets |
|---|---|
| URL | The page WebWatcher opens when no tab is open. |
| Name | The profile's name, if you have not typed one. |
| Reading strategy | How the number is read, shown in **Advanced** under **Strategy**. See [Watch types](/docs/watch-types). |
| Selector and anchor | The elements that hold the badge and the always-present element beside it. |
| Force refresh before checking | On for LinkedIn, Rive Community and Reddit, off for Contra and the tab title profile. See [Force refresh](/docs/force-refresh). |
| Action URL | The page that opens when you click the notification, if you have not set one. |
| Watch Type | Badge/Number. |

## Use a profile

1. Click the WebWatcher icon in the menu bar, then **Add Watcher**.

   **You see:** the Add Watcher window on its **Web page** tab.

2. Open the **Site** picker at the top of the window and choose your site, for example **LinkedIn Notifications**.

   **You see:** a line under the picker that explains how this profile reads the count, and a **URL to Monitor (must be open in Safari)** field already filled in. **Which element?** reads "Using the built-in recipe for LinkedIn Notifications." with a **Set up manually instead** link.

3. Change **Name** or **Check Interval** if you want to.

4. Open the site in a Safari tab and sign in.

5. Back in the editor, click **Run Diagnosis**.

   **You see:** a list of checks and a summary such as "Reading: 3" or "Confirmed zero — the anchor is present and there's no badge."

6. Click **Save**.

   **You see:** the window closes and the watcher is checked straight away.

To leave a profile and set the watcher up by hand, click **Set up manually instead**. The profile is dropped and the guided picker steps appear.

> **Note.** A profile reads the page in an open Safari tab, so you must be signed in to the site in Safari. If you are signed out, the watcher row shows "Signed out" or "Page not recognized" instead of reporting zero.

## Built-in profiles

The **Site** picker lists these profiles after **Custom (choose elements yourself)**.

| Profile | What it watches | How it reads the count |
|---|---|---|
| LinkedIn Messages | The unread count on the Messaging link. | Accessibility label. |
| LinkedIn Notifications | The unread count on the Notifications link. | Accessibility label. |
| Rive Community Notifications | The notification bell on community.rive.app. | Anchor + badge. |
| Rive Community Direct Messages | The direct messages button on community.rive.app. | Anchor + badge. |
| Reddit Inbox | The inbox count in the Reddit header. | Anchor + badge. |
| Reddit Chat | The chat count in the Reddit header. | Anchor + badge. |
| Contra Messages | The Messages link in the Contra side navigation. | Anchor + badge. |
| Contra Notifications | The Notifications button in the Contra side navigation. | Anchor + badge. |
| Any site — tab title (N) | The `(3)` at the start of the Safari tab title. | Tab title (N). |

Anchor + badge means the profile looks for a badge beside a button that is always on the page. When the button is there and the badge is not, WebWatcher reads a confirmed zero.

**Any site — tab title (N)** is the one profile that is not tied to a site. It needs no selector, so it works on any page that puts the count in its title, such as an inbox tab reading "(3) Inbox". Type the page address into **URL to Monitor (must be open in Safari)**.

## How the profile finds your tab

A profile does not look at which site you are on. You choose it, and it then decides which Safari tab to read:

- WebWatcher first looks for a tab whose address starts with the profile's page address, for example `https://www.linkedin.com/feed/`.
- If none matches, it looks for a tab on the profile's domain. The domain `linkedin.com` matches `linkedin.com`, `www.linkedin.com` and any subdomain of it.
- If several tabs match, visible tabs come first.

The page address matters because some pages of a site do not contain the badge. LinkedIn's notifications page has no navigation bar, so a tab sitting there cannot report a count. When the tab found is on another page of the site and **Open the page automatically if no tab is found** is on, WebWatcher opens the profile's page in a background tab and reads that one.

## When your site is not listed

1. In the **Site** picker, leave **Custom (choose elements yourself)** selected.
2. Use the guided picker to find the badge. [Finding the element](/docs/finding-the-element) describes the three steps.
3. If the page shows the count in its tab title, choose **Any site — tab title (N)** instead. It needs no selector.

For worked examples of custom watchers, see [Example watchers](/docs/example-watchers).

## If it does not work

| What you see | Cause | Fix |
|---|---|---|
| The row shows "Page not recognized". | The site changed its layout, or the tab is on a page without the navigation the profile needs. | Open the profile's home page in Safari. If the row stays the same, choose **Set up manually instead** and pick the element again. |
| The row shows "Signed out". | You are not signed in to the site in Safari. | Sign in to the site in Safari. |
| The row shows "No tab open". | No Safari tab matches the profile's domain. | Open the site in Safari, or leave **Open the page automatically if no tab is found** on. |

[Troubleshooting](/docs/troubleshooting) covers every message a watcher row can show.
