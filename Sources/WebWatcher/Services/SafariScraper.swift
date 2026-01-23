import Foundation

/// Scrapes web content from Safari using AppleScript
/// This approach uses Safari's authenticated session and doesn't steal focus
class SafariScraper {
    static let shared = SafariScraper()

    /// Check a watcher by reading from Safari
    /// Safari must have the URL open in a tab
    func check(_ watcher: Watcher) async -> WatchResult {
        // Find the tab with the matching URL and execute JavaScript
        let script = generateAppleScript(for: watcher)

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let result = self.executeAppleScript(script)

                let watchResult: WatchResult
                if let error = result.error {
                    watchResult = WatchResult(
                        watcherId: watcher.id,
                        value: nil,
                        error: error,
                        hasChanged: false,
                        timestamp: Date()
                    )
                } else {
                    let hasChanged = result.value != nil && watcher.lastValue != nil && watcher.lastValue != result.value
                    watchResult = WatchResult(
                        watcherId: watcher.id,
                        value: result.value,
                        error: nil,
                        hasChanged: hasChanged,
                        timestamp: Date()
                    )
                }

                continuation.resume(returning: watchResult)
            }
        }
    }

    private func generateAppleScript(for watcher: Watcher) -> String {
        let escapedURL = watcher.url.replacingOccurrences(of: "\"", with: "\\\"")
        let js = generateJavaScript(for: watcher)
        let escapedJS = js.replacingOccurrences(of: "\"", with: "\\\"")

        // Optional reload block - forces Safari to refresh stale tabs
        let reloadBlock: String
        if watcher.forceRefresh {
            let settleDelay = watcher.refreshDelay
            reloadBlock = """

            -- Reload the tab to get fresh content (Safari suspends background tabs)
            tell foundTab
                set currentURL to URL of foundTab
                set URL of foundTab to currentURL
            end tell

            -- Wait for page to finish loading (up to 15 seconds)
            set maxWait to 15
            set waitCount to 0
            repeat while waitCount < maxWait
                delay 0.5
                set waitCount to waitCount + 0.5
                try
                    tell foundTab
                        set loadState to do JavaScript "document.readyState"
                        if loadState is "complete" then exit repeat
                    end tell
                end try
            end repeat

            -- Additional settle time for dynamic content (configurable)
            delay \(settleDelay)
"""
        } else {
            reloadBlock = ""
        }

        // AppleScript that finds the tab by URL and executes JavaScript
        // Saves and restores frontmost app to prevent Safari from stealing focus
        return """
        -- Save the current frontmost app
        tell application "System Events"
            set frontApp to name of first application process whose frontmost is true
        end tell

        set jsResult to ""
        tell application "Safari"
            set targetURL to "\(escapedURL)"
            set foundTab to missing value
            set foundWindow to missing value

            -- Search all windows and tabs for matching URL
            repeat with w in windows
                repeat with t in tabs of w
                    if URL of t starts with targetURL or targetURL starts with URL of t then
                        set foundTab to t
                        set foundWindow to w
                        exit repeat
                    end if
                end repeat
                if foundTab is not missing value then exit repeat
            end repeat

            if foundTab is missing value then
                return "ERROR:Tab not found. Open \(escapedURL) in Safari."
            end if
        \(reloadBlock)
            -- Execute JavaScript in the found tab
            tell foundTab
                set jsResult to do JavaScript "\(escapedJS)"
            end tell
        end tell

        -- Restore the frontmost app
        tell application "System Events"
            set frontmost of process frontApp to true
        end tell

        return jsResult
        """
    }

    private func generateJavaScript(for watcher: Watcher) -> String {
        let escapedSelector = watcher.selector
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")

        let getElementJS: String
        switch watcher.selectorType {
        case .css:
            getElementJS = "document.querySelector('\(escapedSelector)')"
        case .xpath:
            getElementJS = "(function() { var result = document.evaluate('\(escapedSelector)', document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null); return result.singleNodeValue; })()"
        }

        switch watcher.watchType {
        case .badgeNumber:
            // For badge numbers, missing element = no badge = 0 notifications
            return """
            (function() {
                var el = \(getElementJS);
                if (!el) return '0';
                var text = el.innerText || el.textContent || '';
                var trimmed = text.trim();
                if (trimmed === '') return '0';
                var match = trimmed.match(/\\\\d+/);
                return match ? match[0] : 'NO_NUMBER:' + trimmed.substring(0, 50);
            })()
            """

        case .elementCount:
            let getElementsJS: String
            switch watcher.selectorType {
            case .css:
                getElementsJS = "document.querySelectorAll('\(escapedSelector)')"
            case .xpath:
                getElementsJS = "(function() { var result = document.evaluate('\(escapedSelector)', document, null, XPathResult.ORDERED_NODE_SNAPSHOT_TYPE, null); return { length: result.snapshotLength }; })()"
            }
            return """
            (function() {
                var els = \(getElementsJS);
                return String(els.length || 0);
            })()
            """

        case .textChange:
            return """
            (function() {
                var el = \(getElementJS);
                if (!el) return '';
                return (el.innerText || el.textContent || '').trim();
            })()
            """

        case .elementExists:
            return """
            (function() {
                var el = \(getElementJS);
                return el !== null ? 'true' : 'false';
            })()
            """

        case .elementDisappears:
            return """
            (function() {
                var el = \(getElementJS);
                return el !== null ? 'true' : 'false';
            })()
            """
        }
    }

    private func executeAppleScript(_ script: String) -> (value: String?, error: String?) {
        var error: NSDictionary?
        let appleScript = NSAppleScript(source: script)
        let result = appleScript?.executeAndReturnError(&error)

        if let error = error {
            let errorMessage = error[NSAppleScript.errorMessage] as? String ?? "Unknown AppleScript error"

            // Check for common errors
            if errorMessage.contains("Allow JavaScript from Apple Events") {
                return (nil, "Enable 'Allow JavaScript from Apple Events' in Safari Settings → Developer")
            }

            return (nil, errorMessage)
        }

        guard let stringResult = result?.stringValue else {
            return (nil, "No result from AppleScript")
        }

        // Check for our custom error prefix
        if stringResult.hasPrefix("ERROR:") {
            return (nil, String(stringResult.dropFirst(6)))
        }

        return (stringResult, nil)
    }
}
