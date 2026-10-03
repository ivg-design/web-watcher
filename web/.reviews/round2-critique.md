# Round 2 critique — does it wow?

## Anti-patterns verdict: pass. It does not look generated; it looks designed by someone who has used the app.

## Overall impression
The "page watches itself" idea is the right one and it lands: the real glyph in the header, the sand,
the badge that ticks when a demo changes something, the real popover. The hero is the real app. The
picker section is the strongest thing on the page — it is the actual flow with the actual toolbar text.
What undermines the wow is *doubling*: the page says the same thing twice (two banners per change,
five identical popover rows, two "Watch the demo" controls, Herald voice claims) and *small*
outcomes (watch-type examples the size of a favicon at 1440, the editor screenshot at 218 px).

## What works
- Hero: real recording, plays in place with sound, honest facts line. No modal.
- Picker: candidate ranking, blue outline hopping with the arrow keys, the real pill toolbar,
  Confirm with a live read. This is the product.
- Privacy diagram: the crossed-out "The internet" box says more than a paragraph. The three
  switches lighting "Ready — add your first watcher →" is a real outcome.
- Herald band: faithful dark banners that persist and stack; Snooze returns.

## Priority issues (ranked)
1. **Every change is announced twice.** Stage banner + site notice, same anatomy, same text, 150 px
   apart. Fix: the site watcher reacts (badge, glance, popover) and explains itself once with a small
   callout pinned to the mark ("Logged. Click the mark."); the stage keeps its banner. → WatchNotices.
2. **The popover does not behave like the popover.** Five rows for one Gmail watcher. Fix: one row per
   watcher, latest value, "just now", unread count on the Email row. → WatchPopover.
3. **Watch types are the weakest section at 1440.** The six rows are a spec table; the "example" cell is
   a 44 px bell. Nothing says "click me". Fix: make the example the hero of each row (≥ 96 px stage,
   1.4× scale), hover lifts the stage and shows "see it change ▸", the whole row is the button, the
   post-change notification uses the real title/body. Rename to the six real types.
4. **Fiction in the mocks.** "Badge went 3 → 5", Open on a Gmail notification, Undo, "All read". The
   owner will spot every one. Fix: real strings from NotificationService; real buttons; demo resets
   named as demo resets ("Put it back"), notification clears at zero.
5. **The Herald voice is the wrong voice.** macOS speechSynthesis. Fix: Kokoro sample on click with a
   visible "playing" state and a waveform/level meter so the click has a visible outcome.
6. **How-it-works stage is 60 % empty.** Two mails in a 420 px window. Fix: four mails, the found
   element row highlighted; beat 3's notification is the only banner.

## Minor
- "Watch the demo" twice at 1440; the on-frame control is enough above 1100 px.
- Hero stage bleeds past the container by 2 px; the clock in the fake menu bar is clipped.
- Recent updates: 1.10.5 under a 1.10.9 download with no explanation.
- Herald Snooze tooltip overlaps the next pill.
- Sender-editor screenshot unreadable at 218 px.

## Questions
- Should the site-level notice exist at all once the popover is right? (Answer taken: once, as a
  callout that teaches the mark; the badge and popover carry the rest.)
- Could the Watch-types notification slot be the *only* banner for that section, with the row's
  example and the banner animating together? (Yes — implemented as the shared slot, now with real text.)
