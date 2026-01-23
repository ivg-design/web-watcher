import Foundation

/// Selector type - CSS or XPath
enum SelectorType: String, Codable, CaseIterable {
    case css = "CSS Selector"
    case xpath = "XPath"

    var placeholder: String {
        switch self {
        case .css: return "e.g., .badge, [data-count], #notifications"
        case .xpath: return "e.g., //div[@class='badge'], //a[contains(@href, 'messages')]"
        }
    }

    var helpURL: String {
        switch self {
        case .css: return "https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_Selectors"
        case .xpath: return "https://developer.mozilla.org/en-US/docs/Web/XPath"
        }
    }
}

/// Represents what type of change to watch for
enum WatchType: String, Codable, CaseIterable {
    case textChange = "Text Change"
    case elementCount = "Element Count"
    case badgeNumber = "Badge/Number"
    case elementExists = "Element Exists"
    case elementDisappears = "Element Disappears"

    var description: String {
        switch self {
        case .textChange:
            return "Notify when the text content changes"
        case .elementCount:
            return "Notify when the number of matching elements changes"
        case .badgeNumber:
            return "Extract and track a number (e.g., unread count)"
        case .elementExists:
            return "Notify when the element appears"
        case .elementDisappears:
            return "Notify when the element disappears"
        }
    }
}

/// Check interval options
enum CheckInterval: Int, Codable, CaseIterable {
    case seconds15 = 15
    case seconds30 = 30
    case minute1 = 60
    case minutes2 = 120
    case minutes5 = 300
    case minutes10 = 600
    case minutes30 = 1800

    var displayName: String {
        switch self {
        case .seconds15: return "15 seconds"
        case .seconds30: return "30 seconds"
        case .minute1: return "1 minute"
        case .minutes2: return "2 minutes"
        case .minutes5: return "5 minutes"
        case .minutes10: return "10 minutes"
        case .minutes30: return "30 minutes"
        }
    }
}

/// A single watcher configuration
struct Watcher: Identifiable {
    var id: UUID
    var name: String
    var url: String
    var selector: String
    var selectorType: SelectorType
    var watchType: WatchType
    var interval: CheckInterval
    var isEnabled: Bool
    var notificationSound: Bool
    var actionURL: String? // URL to open when notification is clicked

    // Notification customization
    var customIconPath: String? // Path to custom icon image
    var notificationTitle: String? // Custom title (defaults to watcher name)
    var notificationBodyTemplate: String? // Custom body template with {value} placeholder

    // Safari behavior
    var forceRefresh: Bool // Reload tab before checking (fixes Safari suspending background tabs)
    var refreshDelay: Double // Seconds to wait after reload before scraping (default 2.0)

    // State
    var lastValue: String?
    var lastCheck: Date?
    var lastError: String?
    var consecutiveErrors: Int

    init(
        id: UUID = UUID(),
        name: String = "",
        url: String = "",
        selector: String = "",
        selectorType: SelectorType = .css,
        watchType: WatchType = .badgeNumber,
        interval: CheckInterval = .seconds30,
        isEnabled: Bool = true,
        notificationSound: Bool = true,
        actionURL: String? = nil,
        customIconPath: String? = nil,
        notificationTitle: String? = nil,
        notificationBodyTemplate: String? = nil,
        forceRefresh: Bool = false,
        refreshDelay: Double = 2.0
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.selector = selector
        self.selectorType = selectorType
        self.watchType = watchType
        self.interval = interval
        self.isEnabled = isEnabled
        self.notificationSound = notificationSound
        self.actionURL = actionURL
        self.customIconPath = customIconPath
        self.notificationTitle = notificationTitle
        self.notificationBodyTemplate = notificationBodyTemplate
        self.forceRefresh = forceRefresh
        self.refreshDelay = refreshDelay
        self.lastValue = nil
        self.lastCheck = nil
        self.lastError = nil
        self.consecutiveErrors = 0
    }

    /// Display string for the current status
    var statusDisplay: String {
        if let error = lastError {
            return "Error: \(error)"
        }
        guard let value = lastValue else {
            return "Not checked yet"
        }
        switch watchType {
        case .badgeNumber:
            if value == "ELEMENT_NOT_FOUND" || value == "NO_BADGE" || value == "0" || value.hasPrefix("NO_NUMBER:") {
                return "Nothing new"
            } else {
                return "\(value) new"
            }
        case .elementCount:
            if value == "0" {
                return "Nothing new"
            }
            return "\(value) items"
        case .textChange:
            return "Last: \(value.prefix(30))..."
        case .elementExists:
            return value == "true" ? "Present" : "Nothing new"
        case .elementDisappears:
            return value == "true" ? "Still there" : "Gone"
        }
    }

    /// Whether the current value indicates a potential issue with the selector
    var mayHaveIssue: Bool {
        guard let value = lastValue else { return false }
        return value.hasPrefix("NO_NUMBER:")
    }
}

// MARK: - Codable (with backwards compatibility)
extension Watcher: Codable {
    enum CodingKeys: String, CodingKey {
        case id, name, url, selector, selectorType, watchType, interval, isEnabled
        case notificationSound, actionURL, customIconPath, notificationTitle, notificationBodyTemplate
        case forceRefresh, refreshDelay
        case lastValue, lastCheck, lastError, consecutiveErrors
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        url = try container.decode(String.self, forKey: .url)
        selector = try container.decode(String.self, forKey: .selector)
        selectorType = try container.decode(SelectorType.self, forKey: .selectorType)
        watchType = try container.decode(WatchType.self, forKey: .watchType)
        interval = try container.decode(CheckInterval.self, forKey: .interval)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        notificationSound = try container.decode(Bool.self, forKey: .notificationSound)
        actionURL = try container.decodeIfPresent(String.self, forKey: .actionURL)
        customIconPath = try container.decodeIfPresent(String.self, forKey: .customIconPath)
        notificationTitle = try container.decodeIfPresent(String.self, forKey: .notificationTitle)
        notificationBodyTemplate = try container.decodeIfPresent(String.self, forKey: .notificationBodyTemplate)
        // Backwards compatibility: default to false if not present
        forceRefresh = try container.decodeIfPresent(Bool.self, forKey: .forceRefresh) ?? false
        refreshDelay = try container.decodeIfPresent(Double.self, forKey: .refreshDelay) ?? 2.0
        lastValue = try container.decodeIfPresent(String.self, forKey: .lastValue)
        lastCheck = try container.decodeIfPresent(Date.self, forKey: .lastCheck)
        lastError = try container.decodeIfPresent(String.self, forKey: .lastError)
        consecutiveErrors = try container.decodeIfPresent(Int.self, forKey: .consecutiveErrors) ?? 0
    }
}

/// Result from checking a watcher
struct WatchResult {
    let watcherId: UUID
    let value: String?
    let error: String?
    let hasChanged: Bool
    let timestamp: Date
}
