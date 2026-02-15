import SwiftUI

/// Settings view for global app configuration
struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @Environment(\.dismiss) var dismiss
    @State private var notificationsGranted = false
    @State private var safariAutomationGranted = false
    @State private var systemEventsAutomationGranted = false
    @State private var defaultBrowserAutomationGranted = false
    @State private var defaultBrowserBundleID: String?
    @State private var defaultBrowserName = "Default Browser"
    @State private var isRefreshingPermissions = false

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text("Settings")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.escape)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // General Section
                    GroupBox(label: Label("General", systemImage: "gear")) {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("Launch at login", isOn: $settings.launchAtLogin)
                                .help("Start Web Watcher automatically when you log in")

                            Toggle("Show badge in menu bar", isOn: $settings.showMenuBarBadge)
                                .help("Show unread count badge on menu bar icon")

                            Toggle("Reuse existing browser tab by domain", isOn: $settings.reuseExistingBrowserTabByDomain)
                                .help("When opening a watcher page, switch to an existing tab with the same domain instead of creating a new tab")
                        }
                        .padding(.vertical, 4)
                    }

                    // Permissions Section
                    GroupBox(label: Label("Permissions", systemImage: "checkmark.shield")) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Button("Open System Automation Settings") {
                                    BrowserNavigationService.shared.openAutomationSettings()
                                }

                                Spacer()

                                Button("Refresh") {
                                    refreshPermissionStatus()
                                }
                                .disabled(isRefreshingPermissions)
                            }

                            permissionStatusRow(
                                title: "Notifications",
                                granted: notificationsGranted,
                                buttonTitle: notificationsGranted ? "Open" : "Fix",
                                action: {
                                    requestNotificationPermissionAndOpenSettings()
                                }
                            )

                            permissionStatusRow(
                                title: "Safari Automation",
                                granted: safariAutomationGranted,
                                buttonTitle: safariAutomationGranted ? "Open" : "Fix",
                                action: {
                                    requestAutomationPermission(bundleID: "com.apple.Safari", appName: "Safari")
                                }
                            )

                            permissionStatusRow(
                                title: "System Events Automation",
                                granted: systemEventsAutomationGranted,
                                buttonTitle: systemEventsAutomationGranted ? "Open" : "Fix",
                                action: {
                                    requestAutomationPermission(bundleID: "com.apple.systemevents", appName: "System Events")
                                }
                            )

                            permissionStatusRow(
                                title: "\(defaultBrowserName) Automation",
                                granted: defaultBrowserAutomationGranted,
                                buttonTitle: defaultBrowserAutomationGranted ? "Open" : "Fix",
                                action: {
                                    if let bundleID = defaultBrowserBundleID {
                                        requestAutomationPermission(bundleID: bundleID, appName: defaultBrowserName)
                                    } else {
                                        BrowserNavigationService.shared.openAutomationSettings()
                                    }
                                }
                            )
                        }
                        .padding(.vertical, 4)
                    }

                    // Default Settings Section
                    GroupBox(label: Label("Defaults", systemImage: "slider.horizontal.3")) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Default check interval:")
                                Spacer()
                                Picker("", selection: $settings.defaultCheckInterval) {
                                    ForEach(CheckInterval.allCases, id: \.self) { interval in
                                        Text(interval.displayName).tag(interval)
                                    }
                                }
                                .frame(width: 120)
                            }

                            HStack {
                                Text("Page load delay:")
                                Spacer()
                                Picker("", selection: $settings.pageLoadDelay) {
                                    Text("2 seconds").tag(2.0)
                                    Text("3 seconds").tag(3.0)
                                    Text("5 seconds").tag(5.0)
                                    Text("10 seconds").tag(10.0)
                                    Text("15 seconds").tag(15.0)
                                }
                                .frame(width: 120)
                            }
                            Text("Time to wait after page loads before extracting content. Increase if pages use heavy JavaScript.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }

                    // Notifications Section
                    GroupBox(label: Label("Notifications", systemImage: "bell")) {
                        VStack(alignment: .leading, spacing: 12) {
                            Button("Open System Notification Settings") {
                                openNotificationSettings()
                            }

                            Text("Configure notification banners, sounds, and grouping in System Settings.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }

                    // Data Section
                    GroupBox(label: Label("Data", systemImage: "folder")) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Config location:")
                                Spacer()
                                Text("~/Library/Application Support/WebWatcher/")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }

                            Button("Open Config Folder") {
                                let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                                let folder = appSupport.appendingPathComponent("WebWatcher")
                                NSWorkspace.shared.open(folder)
                            }

                            Button("Clear Saved Cookies/Sessions") {
                                clearWebData()
                            }
                            .foregroundColor(.orange)
                        }
                        .padding(.vertical, 4)
                    }

                    // About Section
                    GroupBox(label: Label("About", systemImage: "info.circle")) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Web Watcher")
                                    .font(.headline)
                                Spacer()
                                Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")")
                                    .foregroundColor(.secondary)
                            }
                            Text("Monitor web pages for changes and get native macOS notifications.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding()
            }
        }
        .frame(width: 450, height: 550)
        .onAppear {
            refreshPermissionStatus()
        }
    }

    @ViewBuilder
    private func permissionStatusRow(
        title: String,
        granted: Bool,
        buttonTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(granted ? Color.green : Color.red)
                .frame(width: 9, height: 9)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                Text(granted ? "Granted" : "Not granted")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(buttonTitle, action: action)
        }
    }

    /// Refresh all permission indicators shown in the Settings dashboard.
    private func refreshPermissionStatus() {
        isRefreshingPermissions = true

        Task {
            let notifications = await NotificationService.shared.checkPermission()
            let safariAutomation = BrowserNavigationService.shared.hasAutomationPermission(bundleID: "com.apple.Safari")
            let systemEventsAutomation = BrowserNavigationService.shared.hasAutomationPermission(bundleID: "com.apple.systemevents")
            let defaultBrowserSnapshot = BrowserNavigationService.shared.defaultBrowserAutomationPermissionSnapshot()

            await MainActor.run {
                notificationsGranted = notifications
                safariAutomationGranted = safariAutomation
                systemEventsAutomationGranted = systemEventsAutomation

                if let defaultBrowserSnapshot {
                    defaultBrowserBundleID = defaultBrowserSnapshot.bundleID
                    defaultBrowserName = defaultBrowserSnapshot.appName
                    defaultBrowserAutomationGranted = defaultBrowserSnapshot.granted
                } else {
                    defaultBrowserBundleID = nil
                    defaultBrowserName = "Default Browser"
                    defaultBrowserAutomationGranted = false
                }

                isRefreshingPermissions = false
            }
        }
    }

    /// Request notifications permission and route the user to System Settings.
    private func requestNotificationPermissionAndOpenSettings() {
        Task {
            _ = await NotificationService.shared.requestPermission()
            await MainActor.run {
                openNotificationSettings()
                refreshPermissionStatus()
            }
        }
    }

    /// Trigger a single automation permission prompt and refresh dashboard state.
    private func requestAutomationPermission(bundleID: String, appName: String) {
        Task { @MainActor in
            _ = BrowserNavigationService.shared.requestAutomationPermission(bundleID: bundleID, appName: appName)
            refreshPermissionStatus()
        }
    }

    private func openNotificationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(url)
        }
    }

    private func clearWebData() {
        let dataStore = WKWebsiteDataStore.default()
        let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()

        dataStore.fetchDataRecords(ofTypes: dataTypes) { records in
            dataStore.removeData(ofTypes: dataTypes, for: records) {
                print("Cleared web data")
            }
        }
    }
}

import WebKit
