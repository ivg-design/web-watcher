export const STEPS = [
  { title: "Open the page in Safari", short: "Open page", copy: "Keep the tab you already use. WebWatcher talks to Safari through Apple Events. No extension, no proxy, no password handed to anyone." },
  { title: "Point at the element", short: "Point", copy: "Scan page groups what it finds: badges, counters, titles. Or Pick in Safari: click, then nudge with the arrow keys until the outline sits on the right thing." },
  { title: "Get told when it changes", short: "Get told", copy: "Checks run on your interval in a background tab. A change posts one notification with the count; click it to land on the page, or the email." },
] as const;

/** Beat durations in ms. */
export const DURATION = [3200, 4400, 3600] as const;

/** Sub-steps inside a beat: [sub index, start ms]. Sub 0 starts at 0. */
export const SUBS: ReadonlyArray<ReadonlyArray<number>> = [
  [],
  [1300, 2000, 2800], // down, right, enter
  [500, 900],         // badge ticks, notification lands
];

/** Final sub per beat (what reduced-motion shows). */
export const FINAL_SUB = [0, 3, 2] as const;

export const HOLD_MS = 12000;
export const TOOLBAR_TEXT = "← → siblings · ↑ parent · ↓ child · ⏎ use · ⎋ cancel";
