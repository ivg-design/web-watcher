import Foundation
import WebKit

/// Service that loads web pages and extracts content using CSS selectors or XPath
class WebScraperActor {
    static let shared = WebScraperActor()

    /// Check a watcher and return the result
    func check(_ watcher: Watcher) async -> WatchResult {
        await withCheckedContinuation { continuation in
            Task { @MainActor in
                let scraper = WebScraperWorker(watcher: watcher) { result in
                    continuation.resume(returning: result)
                }
                scraper.start()
            }
        }
    }
}

/// Worker class that handles a single web scraping operation
@MainActor
class WebScraperWorker: NSObject, WKNavigationDelegate {
    private var webView: WKWebView?
    private var completion: ((WatchResult) -> Void)?
    private let watcher: Watcher
    private var hasCompleted = false
    private let timeout: TimeInterval = 30
    private var timeoutTask: Task<Void, Never>?

    init(watcher: Watcher, completion: @escaping (WatchResult) -> Void) {
        self.watcher = watcher
        self.completion = completion
        super.init()
    }

    func start() {
        guard let url = URL(string: watcher.url) else {
            complete(value: nil, error: "Invalid URL")
            return
        }

        // Configure WebView
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        self.webView = webView

        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeout)
        webView.load(request)

        // Start timeout
        timeoutTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            if !Task.isCancelled {
                self.complete(value: nil, error: "Request timed out")
            }
        }
    }

    private func complete(value: String?, error: String?) {
        guard !hasCompleted else { return }
        hasCompleted = true

        timeoutTask?.cancel()
        webView?.stopLoading()
        webView?.navigationDelegate = nil
        webView = nil

        let hasChanged = value != nil && watcher.lastValue != nil && watcher.lastValue != value
        let result = WatchResult(
            watcherId: watcher.id,
            value: value,
            error: error,
            hasChanged: hasChanged,
            timestamp: Date()
        )

        completion?(result)
        completion = nil
    }

    private func extractContent() {
        guard let webView = webView else {
            complete(value: nil, error: "WebView not available")
            return
        }

        let js = generateJavaScript(for: watcher.watchType, selector: watcher.selector, selectorType: watcher.selectorType)

        webView.evaluateJavaScript(js) { [weak self] result, error in
            guard let self = self else { return }

            if let error = error {
                self.complete(value: nil, error: error.localizedDescription)
            } else if let value = result as? String {
                self.complete(value: value, error: nil)
            } else if let value = result as? Int {
                self.complete(value: String(value), error: nil)
            } else if let value = result as? Bool {
                self.complete(value: String(value), error: nil)
            } else {
                self.complete(value: "", error: nil)
            }
        }
    }

    private func generateJavaScript(for watchType: WatchType, selector: String, selectorType: SelectorType) -> String {
        let escapedSelector = selector
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")

        let getElementJS: String
        let getElementsJS: String

        switch selectorType {
        case .css:
            getElementJS = "document.querySelector('\(escapedSelector)')"
            getElementsJS = "document.querySelectorAll('\(escapedSelector)')"
        case .xpath:
            getElementJS = """
                (function() {
                    const result = document.evaluate('\(escapedSelector)', document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null);
                    return result.singleNodeValue;
                })()
                """
            getElementsJS = """
                (function() {
                    const result = document.evaluate('\(escapedSelector)', document, null, XPathResult.ORDERED_NODE_SNAPSHOT_TYPE, null);
                    const nodes = [];
                    for (let i = 0; i < result.snapshotLength; i++) {
                        nodes.push(result.snapshotItem(i));
                    }
                    return nodes;
                })()
                """
        }

        switch watchType {
        case .badgeNumber:
            return """
            (function() {
                const el = \(getElementJS);
                if (!el) return '0';
                const text = el.innerText || el.textContent || '';
                const match = text.match(/\\d+/);
                return match ? match[0] : '0';
            })()
            """

        case .elementCount:
            return """
            (function() {
                const els = \(getElementsJS);
                return (els.length !== undefined ? els.length : els.snapshotLength || 0).toString();
            })()
            """

        case .textChange:
            return """
            (function() {
                const el = \(getElementJS);
                if (!el) return '';
                return (el.innerText || el.textContent || '').trim();
            })()
            """

        case .elementExists:
            return """
            (function() {
                const el = \(getElementJS);
                return el !== null ? 'true' : 'false';
            })()
            """

        case .elementDisappears:
            return """
            (function() {
                const el = \(getElementJS);
                return el !== null ? 'true' : 'false';
            })()
            """
        }
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Wait for JavaScript to execute
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            if !hasCompleted {
                extractContent()
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        complete(value: nil, error: error.localizedDescription)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        complete(value: nil, error: error.localizedDescription)
    }
}

// MARK: - Legacy interface for compatibility

class WebScraper: NSObject {
    func check(_ watcher: Watcher) async -> WatchResult {
        await WebScraperActor.shared.check(watcher)
    }
}
