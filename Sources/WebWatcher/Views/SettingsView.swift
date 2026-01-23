import SwiftUI

/// Settings view for global app configuration
struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @Environment(\.dismiss) var dismiss

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
                                    Text("1 second").tag(1.0)
                                    Text("2 seconds").tag(2.0)
                                    Text("3 seconds").tag(3.0)
                                    Text("5 seconds").tag(5.0)
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
                                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
                                    NSWorkspace.shared.open(url)
                                }
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
                                Text("v1.0.0")
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
