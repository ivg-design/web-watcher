This page is for anyone at step 2 of the **Which element?** assistant who is deciding between the automatic scan list and **Pick in Safari**. Both end with the same result, a selector and a watch type, so the choice is only about which is quicker for your page. The full walkthrough of the assistant is in [Finding the element](/docs/finding-the-element).

## Compare the two

| Helper | How it works | Choose it when |
|---|---|---|
| Scan | WebWatcher reads the open tab when the page step finishes and lists what looks watchable in three groups. **Rescan** runs it again. | You are not sure what the page offers, or the element is a normal badge or counter. |
| Pick in Safari | You click the element in the page and move the outline with the arrow keys. | The scan does not list your element, it lists the wrong thing first, or you want one item in a list. |

## Scan

The scan needs no input from you. It groups candidates under "Showing a number now", "Could get a badge later" and "Other", and each row has a **Use** button and an eye button that highlights the element in Safari.

Scan looks for notification-style counts. When the page has none, the list is replaced by a note that points to **Pick in Safari**. For a price, a block of text or an element that may appear, use **Pick in Safari**, or look in the **Other** group.

## Pick in Safari

Pick in Safari puts you in control of the exact element. You click it, adjust the outline with <kbd>↑</kbd> <kbd>↓</kbd> <kbd>←</kbd> <kbd>→</kbd>, then press <kbd>⏎</kbd> or click **Use this**. Choose it for a status area, one row of a list, or a value the scan would not call watchable. It also lets you point at an icon that shows no number yet, and then choose "Anything changes inside it".

## Where both stop

Neither helper can reach an element in a cross-origin iframe or inside a closed shadow root. **Pick in Safari** tells you about an iframe with "That element is inside an embedded frame WebWatcher can't reach — pick something outside it." Closed shadow roots give no message: the element is never listed or outlined. The fix for each is in the "If it does not work" table of [Finding the element](/docs/finding-the-element#if-it-does-not-work).
