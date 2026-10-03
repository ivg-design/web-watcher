Five watchers that work today, with the exact fields. Selectors on third-party sites can change; if one stops working, re-pick the element with the guided picker.

## Contra messages

- URL: `https://contra.com/messages`
- Selector: `[data-sentry-component='Messages'] [class*='badge']`
- Watch type: Badge/Number

## Reddit notifications

- URL: `https://www.reddit.com/`
- Selector: `dynamic-badge[data-id="notification-count-element"]`
- Watch type: Badge/Number
- Badge attribute: `initial-count`

Reddit uses web components with Shadow DOM, so the badge value is in an attribute rather than in text.

## LinkedIn notifications

- URL: `https://www.linkedin.com/feed/`
- Selector: `.notification-badge__count`
- Watch type: Badge/Number

## Rive Community

- URL: `https://community.rive.app/`
- Selector: `.notification-indicator, [class*='notification'] [class*='count']`
- Watch type: Badge/Number

This is a built-in recipe. Pick the Rive site profile in the editor and WebWatcher fills these fields for you, including the `anchoredBadge` strategy: the badge node disappears entirely at zero, which the recipe already accounts for.

## GitHub pull-request reviews

- URL: `https://github.com/notifications`
- Selector: `.notification-indicator`
- Watch type: Element Exists
