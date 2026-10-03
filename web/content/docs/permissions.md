WebWatcher needs three permissions. macOS prompts for most of them on first run; the Safari one you switch on yourself. Together they are the whole trust model: the app talks to Safari and to Notification Center, and to nothing else.

## 1. Safari: Allow JavaScript from Apple Events

This is the most important one. Without it WebWatcher cannot read page content.

1. Open Safari.
2. Go to Safari → Settings (Preferences on older macOS).
3. Click the Advanced tab.
4. Check *Show features for web developers*. This enables the Develop menu.
5. Close Settings, then open the Develop menu in the menu bar.
6. Check *Allow JavaScript from Apple Events*.

If you skip this step, watchers fail with: "Enable 'Allow JavaScript from Apple Events' in Safari Settings → Developer".

## 2. Automation: Safari and System Events

macOS shows dialogs asking whether WebWatcher may control Safari and System Events. Click OK on both.

If you clicked Don't Allow by accident:

1. Open System Settings → Privacy & Security → Automation.
2. Find WebWatcher in the list.
3. Enable both Safari and System Events.

## 3. Notifications

macOS asks for notification permission on first run. To change it later:

1. Open System Settings → Notifications.
2. Find WebWatcher.
3. Enable notifications and choose Banners or Alerts as the style.

> **Tip.** If you use [Herald](/docs/herald-delivery), banners come from Herald instead and WebWatcher falls back to macOS notifications only when Herald is not running.
