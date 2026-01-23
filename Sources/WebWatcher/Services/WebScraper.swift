import Foundation
import WebKit

/// Service that loads web pages and extracts content using CSS selectors or XPath
class WebScraper: NSObject {
    private var webView: WKWebView?
    private var completion: ((Result<String, Error>) -> Void)?
    private var watchType: WatchType = .textChange
    private var selector: String = ""
    private var selectorType: SelectorType = .css

    private let timeout: TimeInterval = 30

    override init() {
        super.init()
    }

    /// Check a watcher and return the result
    func check(_ watcher: Watcher) async -> WatchResult {
        let result = await withCheckedContinuation { continuation in
            Task { @MainActor in
                self.performCheck(watcher) { result in
                    continuation.resume(returning: result)
                }
            }
        }
        return result
    }

    @MainActor
    private func performCheck(_ watcher: Watcher, completion: @escaping (WatchResult) -> Void) {
        // Configure WebView with persistent data store (keeps cookies/session)
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default() // Use default store to share Safari cookies

        // Allow JavaScript
        config.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        self.webView = webView
        self.selector = watcher.selector
        self.selectorType = watcher.selectorType
        self.watchType = watcher.watchType

        self.completion = { result in
            let watchResult: WatchResult
            switch result {
            case .success(let value):
                let hasChanged = watcher.lastValue != nil && watcher.lastValue != value
                watchResult = WatchResult(
                    watcherId: watcher.id,
                    value: value,
                    error: nil,
                    hasChanged: hasChanged,
                    timestamp: Date()
                )
            case .failure(let error):
                watchResult = WatchResult(
                    watcherId: watcher.id,
                    value: nil,
                    error: error.localizedDescription,
                    hasChanged: false,
                    timestamp: Date()
                )
            }
            completion(watchResult)
        }

        guard let url = URL(string: watcher.url) else {
            self.completion?(.failure(WebScraperError.invalidURL))
            return
        }

        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeout)
        webView.load(request)

        // Timeout handler
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
            if self?.completion != nil {
                self?.completion?(.failure(WebScraperError.timeout))
                self?.cleanup()
            }
        }
    }

    @MainActor
    private func extractContent() {
        guard let webView = webView else {
            completion?(.failure(WebScraperError.noWebView))
            return
        }

        let js = generateJavaScript(for: watchType, selector: selector, selectorType: selectorType)

        webView.evaluateJavaScript(js) { [weak self] result, error in
            guard let self = self else { return }

            if let error = error {
                self.completion?(.failure(error))
            } else if let value = result as? String {
                self.completion?(.success(value))
            } else if let value = result as? Int {
                self.completion?(.success(String(value)))
            } else if let value = result as? Bool {
                self.completion?(.success(String(value)))
            } else {
                self.completion?(.success(""))
            }

            self.cleanup()
        }
    }

    private func generateJavaScript(for watchType: WatchType, selector: String, selectorType: SelectorType) -> String {
        let escapedSelector = selector
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")

        // Helper function to get element(s) based on selector type
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

    @MainActor
    private func cleanup() {
        webView?.stopLoading()
        webView = nil
        completion = nil
    }
}

// MARK: - WKNavigationDelegate

extension WebScraper: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Wait a bit for JavaScript to execute on the page
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.extractContent()
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        completion?(.failure(error))
        Task { @MainActor in
            cleanup()
        }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        completion?(.failure(error))
        Task { @MainActor in
            cleanup()
        }
    }
}

// MARK: - Errors

enum WebScraperError: LocalizedError {
    case invalidURL
    case timeout
    case noWebView
    case notLoggedIn

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .timeout: return "Request timed out"
        case .noWebView: return "WebView not available"
        case .notLoggedIn: return "Not logged in"
        }
    }
}
