The assistant walks you Page → Element → Confirm. You never type a selector; this page explains what each step does and what to do when a page is awkward.

## 1. Page

Open the page in Safari first and sign in if it needs it. WebWatcher lists the open tabs that match the URL and reads the one you choose. Tabs that macOS has unloaded show as about:blank; the assistant reloads them once, in place, before scanning.

## 2. Element

Scan page groups what it finds — badge counts, counters in text, the document title, ARIA counts, lists that change — and ranks the likely one. Pick in Safari draws an outline in the page instead: click the thing, then refine the selection without leaving Safari.

### Keyboard refinement

Once you have clicked an element, the keys move the outline.

<div class="keys"><span class="key">↑ parent</span><span class="key">↓ child</span><span class="key">← → siblings</span><span class="key">⏎ confirm</span><span class="key">⎋ cancel</span></div>

A toolbar in Safari shows the same shortcuts. The app's own Use this button always works, even if the page blocks scripted keys. If the element shows a number, WebWatcher recommends tracking it. If it shows nothing yet, it offers "a number appears next to it" or "anything changes inside it".

## 3. Confirm

The assistant reads the element live and shows the value it will track, the strategy it chose (badge count, text, subtree) and whether the page needs a refresh before each check. You also get the live diagnosis — current reading, confirmed zero, background tab — and buttons to test again or change the element. Save, and the first check runs immediately.

![The Element step with ranked candidates](/shots/add-watcher.png)

## No badge yet?

> **No badge yet?** Pick the bell itself and choose Subtree change. WebWatcher fingerprints its children and tells you when anything appears inside.

If neither helper finds what you need, the manual fallback is under Advanced: open Safari → Develop → Show Web Inspector, click the element inspector tool, click the element, right-click it → Copy → Copy Selector, and paste the result into the Selector field.
