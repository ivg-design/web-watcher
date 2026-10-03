import Foundation
import ServiceManagement

/// Where WebWatcher's notifications are delivered.
///
/// `.heraldWhenAvailable` sends through Herald (the menu-bar notification service) whenever it is
/// running, and uses the native macOS notification path otherwise. `.system` never uses Herald.
enum NotificationDelivery: String, Codable, CaseIterable, Identifiable {
    case system
    case heraldWhenAvailable

    var id: String { rawValue }

    static let `default`: NotificationDelivery = .heraldWhenAvailable

    var displayName: String {
        switch self {
        case .system: return "macOS notifications"
        case .heraldWhenAvailable: return "Herald when available"
        }
    }

    /// Reads a persisted raw value; anything missing or unknown becomes the default.
    static func fromStored(_ raw: String?) -> NotificationDelivery {
        raw.flatMap(NotificationDelivery.init(rawValue:)) ?? .default
    }
}

/// Global app settings
class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults = ScreenshotMode.defaults

    // Keys
    private let launchAtLoginKey = "launchAtLogin"
    private let showMenuBarBadgeKey = "showMenuBarBadge"
    private let defaultCheckIntervalKey = "defaultCheckInterval"
    private let pageLoadDelayKey = "pageLoadDelay"
    private let reuseExistingDomainTabKey = "reuseExistingDomainTab"
    private let notificationDeliveryKey = "notificationDelivery"

    @Published var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: launchAtLoginKey)
            updateLaunchAtLogin()
        }
    }

    @Published var showMenuBarBadge: Bool {
        didSet {
            defaults.set(showMenuBarBadge, forKey: showMenuBarBadgeKey)
        }
    }

    @Published var defaultCheckInterval: CheckInterval {
        didSet {
            defaults.set(defaultCheckInterval.rawValue, forKey: defaultCheckIntervalKey)
        }
    }

    @Published var pageLoadDelay: Double {
        didSet {
            defaults.set(pageLoadDelay, forKey: pageLoadDelayKey)
        }
    }

    @Published var reuseExistingBrowserTabByDomain: Bool {
        didSet {
            defaults.set(reuseExistingBrowserTabByDomain, forKey: reuseExistingDomainTabKey)
        }
    }

    @Published var notificationDelivery: NotificationDelivery {
        didSet {
            defaults.set(notificationDelivery.rawValue, forKey: notificationDeliveryKey)
        }
    }

    private init() {
        // Prefer the real service status to avoid stale toggle state.
        self.launchAtLogin = SMAppService.mainApp.status == .enabled
        self.showMenuBarBadge = defaults.object(forKey: showMenuBarBadgeKey) as? Bool ?? true
        self.defaultCheckInterval = CheckInterval(rawValue: defaults.integer(forKey: defaultCheckIntervalKey)) ?? .seconds30
        self.pageLoadDelay = defaults.object(forKey: pageLoadDelayKey) as? Double ?? 2.0
        self.reuseExistingBrowserTabByDomain = defaults.object(forKey: reuseExistingDomainTabKey) as? Bool ?? true
        self.notificationDelivery = NotificationDelivery.fromStored(defaults.string(forKey: notificationDeliveryKey))

        defaults.set(launchAtLogin, forKey: launchAtLoginKey)
    }

    private func updateLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to update launch at login: \(error)")
        }
    }

    /// Check current launch at login status
    func checkLaunchAtLoginStatus() -> Bool {
        return SMAppService.mainApp.status == .enabled
    }

    /// Re-register current app location for launch-at-login when enabled.
    func refreshLaunchAtLoginRegistrationIfNeeded() {
        guard launchAtLogin else { return }
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
            try SMAppService.mainApp.register()
        } catch {
            print("Failed to refresh launch at login registration: \(error)")
        }
    }
}
