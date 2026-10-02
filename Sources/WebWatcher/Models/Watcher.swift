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
    /// G2: fingerprint of an element's subtree; notifies when it changes. Makes a bell
    /// with no badge (no number, ever) watchable.
    case subtreeChange = "Anything Changes Inside"

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
        case .subtreeChange:
            return "Notify when anything inside the element changes — a badge appears, text updates, items are added."
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
    var apiLookupCommand: String? // Optional command to resolve a destination URL (prints URL to stdout)

    // Badge extraction
    var badgeAttribute: String? // Custom attribute to read for badge value (e.g., "initial-count", "data-count")

    /// An always-present element near the badge. Its presence is what lets a missing
    /// badge be reported as a confirmed zero instead of "I could not look".
    var anchorSelector: String?

    /// Built-in detection recipe backing this watcher, if any.
    var profileId: String?

    /// Detection strategy set by the Element Picker Assistant. `nil` means manual/legacy
    /// (the watcher was hand-configured before the assistant existed, or uses a profile
    /// whose own strategy takes precedence).
    var strategy: ProbeStrategy?

    /// Open the page automatically when no matching tab exists.
    var autoOpenEnabled: Bool

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

    /// G2: when the subtree fingerprint (or any conclusive value) last actually changed,
    /// as opposed to merely being re-checked. Set by `WatcherStore.recordObservation`
    /// only when the new conclusive value differs from the previous one, so a watcher
    /// that keeps reading the same value never advances this timestamp.
    var lastChangeDate: Date?

    /// The last reading we are actually confident in. Survives blocked checks, so a
    /// transient failure can never wipe the baseline and swallow the next real change.
    var lastConclusiveValue: String?

    /// True once any check produced a conclusive reading. A watcher that has never
    /// matched anything is misconfigured, not quiet.
    var everMatched: Bool

    /// Why the most recent check could not observe, if it couldn't.
    var lastCannotReason: String?
    var consecutiveCannotObserve: Int

    /// Suppress checks until this time (exponential backoff after repeated failures).
    var backoffUntil: Date?

    /// When we last told the user this watcher is broken, so we don't nag.
    var healthNotifiedAt: Date?

    /// Set when WebWatcher opened the tab itself. Such tabs are never force-refreshed,
    /// so an auto-opened sign-in page can't be reloaded on a timer forever.
    var appOpenedTab: Bool
    var lastAutoOpen: Date?
    var autoOpensToday: Int
    var autoOpenDay: Date?

    /// When we last reloaded this tab to recover from `.tabSuspended`. Throttled
    /// separately from `lastAutoOpen` — a reload is not a new tab.
    var lastReloadAttempt: Date?

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
        apiLookupCommand: String? = nil,
        badgeAttribute: String? = nil,
        anchorSelector: String? = nil,
        profileId: String? = nil,
        strategy: ProbeStrategy? = nil,
        autoOpenEnabled: Bool = true,
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
        self.apiLookupCommand = apiLookupCommand
        self.badgeAttribute = badgeAttribute
        self.anchorSelector = anchorSelector
        self.profileId = profileId
        self.strategy = strategy
        self.autoOpenEnabled = autoOpenEnabled
        self.customIconPath = customIconPath
        self.notificationTitle = notificationTitle
        self.notificationBodyTemplate = notificationBodyTemplate
        self.forceRefresh = forceRefresh
        self.refreshDelay = refreshDelay
        self.lastValue = nil
        self.lastCheck = nil
        self.lastError = nil
        self.consecutiveErrors = 0
        self.lastChangeDate = nil
        self.lastConclusiveValue = nil
        self.everMatched = false
        self.lastCannotReason = nil
        self.consecutiveCannotObserve = 0
        self.backoffUntil = nil
        self.healthNotifiedAt = nil
        self.appOpenedTab = false
        self.lastAutoOpen = nil
        self.autoOpensToday = 0
        self.autoOpenDay = nil
        self.lastReloadAttempt = nil
    }

    /// Overall health, derived rather than stored so it can never drift from the counters.
    enum Health {
        case unknown
        case ok
        case blocked(CannotReason)
        case broken(CannotReason)

        var isHealthy: Bool { if case .ok = self { return true }; return false }
    }

    var health: Health {
        if let raw = lastCannotReason, let reason = CannotReason(rawValue: raw) {
            return consecutiveCannotObserve >= 3 ? .broken(reason) : .blocked(reason)
        }
        if lastConclusiveValue == nil { return .unknown }
        return .ok
    }

    /// Current badge reading, preserving a "9+" style cap.
    var badgeValue: BadgeValue? {
        guard let v = lastConclusiveValue else { return nil }
        return BadgeValue.parse(v)
    }

    /// Display string for the current status.
    ///
    /// "Nothing new" is reachable only from a conclusive reading. Everything else names
    /// what actually went wrong, so a signed-out or tab-less watcher can never masquerade
    /// as a quiet one.
    var statusDisplay: String {
        if let raw = lastCannotReason, let reason = CannotReason(rawValue: raw) {
            return reason.shortStatus
        }
        if let error = lastError, lastConclusiveValue == nil {
            return "Error: \(error)"
        }
        guard let value = lastConclusiveValue ?? lastValue else {
            return "Not checked yet"
        }
        switch watchType {
        case .badgeNumber:
            guard let badge = BadgeValue.parse(value) else { return "Nothing new" }
            return badge.number == 0 ? "Nothing new" : "\(badge.display) new"
        case .elementCount:
            return value == "0" ? "Nothing new" : "\(value) items"
        case .textChange:
            return value.isEmpty ? "Empty" : "Last: \(value.prefix(30))"
        case .elementExists:
            return value == "true" ? "Present" : "Nothing new"
        case .elementDisappears:
            return value == "true" ? "Still there" : "Gone"
        case .subtreeChange:
            if let lastChangeDate {
                return "Changed \(EmailTimeFormatter.received(lastChangeDate))"
            }
            return lastConclusiveValue == nil ? "Not checked yet" : "Watching"
        }
    }

    /// Whether the watcher needs the user's attention.
    var mayHaveIssue: Bool {
        if case .broken = health { return true }
        if lastCannotReason != nil { return true }
        return false
    }

    /// A watcher with no anchor cannot prove a zero, so its quiet readings are unverified —
    /// unless the strategy itself makes zero self-evident (ariaCount and autoBadge read the
    /// anchor directly; documentTitle needs no selector at all).
    var canConfirmZero: Bool {
        if profileId != nil { return true }
        if !(anchorSelector ?? "").isEmpty { return true }
        switch strategy {
        case .autoBadge, .ariaCount, .documentTitle: return true
        default: return false
        }
    }
}

// MARK: - Codable (with backwards compatibility)
extension Watcher: Codable {
    enum CodingKeys: String, CodingKey {
        case id, name, url, selector, selectorType, watchType, interval, isEnabled
        case notificationSound, actionURL, apiLookupCommand, badgeAttribute, customIconPath, notificationTitle, notificationBodyTemplate
        case forceRefresh, refreshDelay
        case lastValue, lastCheck, lastError, consecutiveErrors, lastChangeDate
        case anchorSelector, profileId, autoOpenEnabled
        case strategy, lastReloadAttempt
        case lastConclusiveValue, everMatched, lastCannotReason, consecutiveCannotObserve
        case backoffUntil, healthNotifiedAt
        case appOpenedTab, lastAutoOpen, autoOpensToday, autoOpenDay
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
        apiLookupCommand = try container.decodeIfPresent(String.self, forKey: .apiLookupCommand)
        badgeAttribute = try container.decodeIfPresent(String.self, forKey: .badgeAttribute)
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
        // Absent in every JSON written before G2 existed.
        lastChangeDate = try container.decodeIfPresent(Date.self, forKey: .lastChangeDate)

        anchorSelector = try container.decodeIfPresent(String.self, forKey: .anchorSelector)
        profileId = try container.decodeIfPresent(String.self, forKey: .profileId)
        // Absent in every JSON written before this feature; nil correctly means "manual/legacy".
        strategy = try container.decodeIfPresent(ProbeStrategy.self, forKey: .strategy)
        autoOpenEnabled = try container.decodeIfPresent(Bool.self, forKey: .autoOpenEnabled) ?? true

        // Seed the baseline from the legacy field so an upgrade doesn't look like a
        // fresh install, but don't claim a watcher "matched" on the strength of a
        // legacy "0" — under the old code that value was also what a dead selector wrote.
        lastConclusiveValue = try container.decodeIfPresent(String.self, forKey: .lastConclusiveValue) ?? lastValue
        everMatched = try container.decodeIfPresent(Bool.self, forKey: .everMatched)
            ?? (lastValue != nil && lastValue != "0")
        lastCannotReason = try container.decodeIfPresent(String.self, forKey: .lastCannotReason)
        consecutiveCannotObserve = try container.decodeIfPresent(Int.self, forKey: .consecutiveCannotObserve) ?? 0
        backoffUntil = try container.decodeIfPresent(Date.self, forKey: .backoffUntil)
        healthNotifiedAt = try container.decodeIfPresent(Date.self, forKey: .healthNotifiedAt)
        appOpenedTab = try container.decodeIfPresent(Bool.self, forKey: .appOpenedTab) ?? false
        lastAutoOpen = try container.decodeIfPresent(Date.self, forKey: .lastAutoOpen)
        autoOpensToday = try container.decodeIfPresent(Int.self, forKey: .autoOpensToday) ?? 0
        autoOpenDay = try container.decodeIfPresent(Date.self, forKey: .autoOpenDay)
        lastReloadAttempt = try container.decodeIfPresent(Date.self, forKey: .lastReloadAttempt)
    }
}

/// Result from checking a watcher.
///
/// There is no `hasChanged` here on purpose: change detection used to be computed from a
/// stale snapshot in the scraper and then re-derived in the service. It now lives in
/// exactly one place, `WatcherService`.
struct WatchResult {
    let watcherId: UUID
    let report: ProbeReport
    let timestamp: Date

    var observation: Observation { report.observation }
}
