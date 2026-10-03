Safari suspends background tabs to save resources, and hidden tabs stop repainting. A watcher can therefore read a stale value even though the page is open.

## Force refresh

If a watcher shows stale values, enable *Force refresh before checking* in the watcher settings. This reloads the tab before scraping. Badge watchers already reload the tab before reading it; if a watcher still looks stale, turn on Force refresh under Advanced.

## Settle delay

The Settle delay option, from 0.5 to 5.0 seconds, controls how long to wait after the reload for dynamic JavaScript content to update. Raise it for pages that render the badge late.

## Hidden and unloaded tabs

Tabs macOS has unloaded show as about:blank. The assistant reloads them once, in place, before scanning. Safari also pauses rendering in hidden tabs, so a badge that updates over a WebSocket may not repaint until the tab is visible again. Reloading before reading is what gets around this.

## Check interval

Checks run every 15 seconds to 30 minutes. A shorter interval with Force refresh means more reloads, so choose the longest interval you can live with.
