import Foundation
import ServiceManagement

/// Global app settings
class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    // Keys
    private let launchAtLoginKey = "launchAtLogin"
    private let showMenuBarBadgeKey = "showMenuBarBadge"
    private let defaultCheckIntervalKey = "defaultCheckInterval"
    private let pageLoadDelayKey = "pageLoadDelay"

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

    private init() {
        self.launchAtLogin = defaults.bool(forKey: launchAtLoginKey)
        self.showMenuBarBadge = defaults.object(forKey: showMenuBarBadgeKey) as? Bool ?? true
        self.defaultCheckInterval = CheckInterval(rawValue: defaults.integer(forKey: defaultCheckIntervalKey)) ?? .seconds30
        self.pageLoadDelay = defaults.object(forKey: pageLoadDelayKey) as? Double ?? 2.0
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
}
