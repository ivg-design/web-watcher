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
struct Watcher: Identifiable, Codable {
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
        notificationBodyTemplate: String? = nil
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
            return value == "0" ? "No new" : "\(value) new"
        case .elementCount:
            return "\(value) items"
        case .textChange:
            return "Last: \(value.prefix(30))..."
        case .elementExists:
            return value == "true" ? "Present" : "Not found"
        case .elementDisappears:
            return value == "true" ? "Still there" : "Gone"
        }
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
