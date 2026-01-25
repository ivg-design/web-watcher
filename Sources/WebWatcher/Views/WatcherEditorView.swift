import SwiftUI
import AppKit

/// Editor view for creating or editing a watcher
struct WatcherEditorView: View {
    @Environment(\.dismiss) var dismiss

    @ObservedObject var store: WatcherStore
    var watcherService: WatcherService
    var existingWatcher: Watcher?

    @State private var name: String = ""
    @State private var url: String = ""
    @State private var selector: String = ""
    @State private var selectorType: SelectorType = .css
    @State private var watchType: WatchType = .badgeNumber
    @State private var interval: CheckInterval = .seconds30
    @State private var notificationSound: Bool = true
    @State private var actionURL: String = ""

    // Notification customization
    @State private var customIconPath: String = ""
    @State private var notificationTitle: String = ""
    @State private var notificationBodyTemplate: String = ""
    @State private var showingIconPicker = false

    // Badge extraction
    @State private var badgeAttribute: String = ""

    // Safari behavior
    @State private var forceRefresh: Bool = false
    @State private var refreshDelay: Double = 2.0

    @State private var testResult: String?
    @State private var isTesting: Bool = false
    @State private var previewStatus: String?

    var isEditing: Bool { existingWatcher != nil }

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text(isEditing ? "Edit Watcher" : "Add Watcher")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Form
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Name
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Name")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("e.g., Contra Messages", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }

                    // URL
                    VStack(alignment: .leading, spacing: 4) {
                        Text("URL to Monitor (must be open in Safari)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("https://example.com/page", text: $url)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Selector Type
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Selector Type")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("", selection: $selectorType) {
                            ForEach(SelectorType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                    }

                    // Selector
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(selectorType.rawValue)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("Help") {
                                NSWorkspace.shared.open(URL(string: selectorType.helpURL)!)
                            }
                            .font(.caption)
                            .buttonStyle(.link)
                        }
                        TextField(selectorType.placeholder, text: $selector)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))

                        Text(selectorType == .css
                            ? "Tip: Right-click element in DevTools → Copy → Copy selector"
                            : "Tip: Right-click element in DevTools → Copy → Copy XPath")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    // Watch Type
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Watch Type")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("", selection: $watchType) {
                            ForEach(WatchType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)

                        Text(watchType.description)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    // Badge Attribute (only for Badge/Number watch type)
                    if watchType == .badgeNumber {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Badge Attribute (optional)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("e.g., initial-count, data-count", text: $badgeAttribute)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                            Text("For web components with Shadow DOM. The attribute name on the element that holds the badge value. Leave empty to use innerText.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    // Interval
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Check Interval")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("", selection: $interval) {
                            ForEach(CheckInterval.allCases, id: \.self) { int in
                                Text(int.displayName).tag(int)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }

                    // Action URL (optional)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Action URL (optional)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("URL to open when clicking notification", text: $actionURL)
                            .textFieldStyle(.roundedBorder)
                        Text("Leave empty to use the monitored URL")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    // Sound
                    Toggle("Play sound with notification", isOn: $notificationSound)

                    // Force Refresh
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle("Force refresh before checking", isOn: $forceRefresh)
                        Text("Reloads the Safari tab before scraping. Enable this if values appear stale or don't update (Safari suspends background tabs).")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        if forceRefresh {
                            HStack {
                                Text("Settle delay:")
                                    .font(.caption)
                                Slider(value: $refreshDelay, in: 0.5...5.0, step: 0.5)
                                    .frame(width: 120)
                                Text(String(format: "%.1fs", refreshDelay))
                                    .font(.caption)
                                    .frame(width: 30)
                            }
                            .padding(.top, 4)
                            Text("Time to wait after page loads for dynamic content to update.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }

                    Divider()

                    // Notification Customization Section
                    Text("Notification Customization")
                        .font(.headline)
                        .padding(.top, 8)

                    // Custom Icon
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Custom Icon (optional)")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack {
                            if !customIconPath.isEmpty, let image = NSImage(contentsOfFile: customIconPath) {
                                Image(nsImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 32, height: 32)
                                    .cornerRadius(4)
                            } else {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Image(systemName: "photo")
                                            .foregroundColor(.gray)
                                    )
                            }

                            TextField("Path to icon image", text: $customIconPath)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))

                            Button("Browse...") {
                                pickIcon()
                            }

                            if !customIconPath.isEmpty {
                                Button(action: { customIconPath = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        Text("PNG, JPG, or ICNS file. Displays in notification.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    // Custom Title
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Custom Notification Title (optional)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Leave empty to use watcher name", text: $notificationTitle)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Custom Body Template
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Custom Body Template (optional)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("e.g., {value} new messages waiting", text: $notificationBodyTemplate)
                            .textFieldStyle(.roundedBorder)
                        Text("Use {value} for the detected value, {name} for watcher name")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    // Preview Notification
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Button(action: previewNotification) {
                                HStack {
                                    Image(systemName: "bell.badge")
                                    Text("Preview Notification")
                                }
                            }
                            Spacer()
                        }

                        if let status = previewStatus {
                            Text(status)
                                .font(.caption)
                                .foregroundColor(status.contains("Sent") ? .green : .orange)
                        }
                    }

                    Divider()

                    // Test section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Button(action: runTest) {
                                HStack {
                                    if isTesting {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                    } else {
                                        Image(systemName: "play.circle")
                                    }
                                    Text("Test Selector")
                                }
                            }
                            .disabled(url.isEmpty || selector.isEmpty || isTesting)

                            Spacer()
                        }

                        if let result = testResult {
                            let isError = result.starts(with: "Error") ||
                                          result.contains("ELEMENT_NOT_FOUND") ||
                                          result.contains("NO_NUMBER:")
                            let isWarning = result.contains("NO_NUMBER:")

                            HStack(alignment: .top) {
                                Image(systemName: isError ? (isWarning ? "exclamationmark.triangle" : "xmark.circle") : "checkmark.circle")
                                    .foregroundColor(isError ? (isWarning ? .orange : .red) : .green)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(result)
                                        .font(.caption)
                                        .foregroundColor(isError ? (isWarning ? .orange : .red) : .primary)
                                    if result.contains("ELEMENT_NOT_FOUND") {
                                        Text("Check your selector - element doesn't exist on page")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding(8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(6)
                        }
                    }
                }
                .padding()
            }

            Divider()

            // Actions
            HStack {
                if isEditing {
                    Button("Delete", role: .destructive) {
                        if let watcher = existingWatcher {
                            store.delete(watcher)
                            watcherService.watcherDeleted(watcher.id)
                        }
                        dismiss()
                    }
                    .foregroundColor(.red)
                }

                Spacer()

                Button("Save") {
                    saveWatcher()
                    dismiss()
                }
                .keyboardShortcut(.return)
                .disabled(name.isEmpty || url.isEmpty || selector.isEmpty)
            }
            .padding()
        }
        .frame(width: 450, height: 600)
        .onAppear {
            if let watcher = existingWatcher {
                name = watcher.name
                url = watcher.url
                selector = watcher.selector
                selectorType = watcher.selectorType
                watchType = watcher.watchType
                interval = watcher.interval
                notificationSound = watcher.notificationSound
                actionURL = watcher.actionURL ?? ""
                badgeAttribute = watcher.badgeAttribute ?? ""
                customIconPath = watcher.customIconPath ?? ""
                notificationTitle = watcher.notificationTitle ?? ""
                notificationBodyTemplate = watcher.notificationBodyTemplate ?? ""
                forceRefresh = watcher.forceRefresh
                refreshDelay = watcher.refreshDelay
            }
        }
    }

    private func runTest() {
        isTesting = true
        testResult = nil

        let testWatcher = Watcher(
            name: "Test",
            url: url,
            selector: selector,
            selectorType: selectorType,
            watchType: watchType,
            interval: .seconds30,
            badgeAttribute: badgeAttribute.isEmpty ? nil : badgeAttribute
        )

        Task {
            let scraper = SafariScraper.shared
            let result = await scraper.check(testWatcher)

            await MainActor.run {
                isTesting = false
                if let error = result.error {
                    testResult = "Error: \(error)"
                } else if let value = result.value {
                    // Format special error values
                    if value == "ELEMENT_NOT_FOUND" {
                        testResult = "ELEMENT_NOT_FOUND - Selector doesn't match any element"
                    } else if value.hasPrefix("NO_NUMBER:") {
                        let content = String(value.dropFirst(10))
                        testResult = "NO_NUMBER: Found text \"\(content)\" but no number"
                    } else if value == "0" {
                        testResult = "Found: 0 (no badge visible - element is empty)"
                    } else {
                        testResult = "Found: \"\(value)\""
                    }
                } else {
                    testResult = "No value found (element may not exist)"
                }
            }
        }
    }

    private func saveWatcher() {
        var watcher = existingWatcher ?? Watcher()
        watcher.name = name
        watcher.url = url
        watcher.selector = selector
        watcher.selectorType = selectorType
        watcher.watchType = watchType
        watcher.interval = interval
        watcher.notificationSound = notificationSound
        watcher.actionURL = actionURL.isEmpty ? nil : actionURL
        watcher.badgeAttribute = badgeAttribute.isEmpty ? nil : badgeAttribute
        watcher.customIconPath = customIconPath.isEmpty ? nil : customIconPath
        watcher.notificationTitle = notificationTitle.isEmpty ? nil : notificationTitle
        watcher.notificationBodyTemplate = notificationBodyTemplate.isEmpty ? nil : notificationBodyTemplate
        watcher.forceRefresh = forceRefresh
        watcher.refreshDelay = refreshDelay

        if isEditing {
            store.update(watcher)
            watcherService.watcherUpdated(watcher)
        } else {
            watcher.isEnabled = true
            store.add(watcher)
            watcherService.watcherUpdated(watcher)
        }
    }

    private func pickIcon() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .icns]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.title = "Select Icon Image"

        if panel.runModal() == .OK, let url = panel.url {
            customIconPath = url.path
        }
    }

    private func previewNotification() {
        previewStatus = "Requesting permission..."

        Task {
            let granted = await NotificationService.shared.requestPermission()

            await MainActor.run {
                if granted {
                    let previewWatcher = Watcher(
                        name: name.isEmpty ? "Preview Watcher" : name,
                        url: url,
                        selector: selector,
                        selectorType: selectorType,
                        watchType: watchType,
                        interval: interval,
                        notificationSound: notificationSound,
                        actionURL: actionURL.isEmpty ? nil : actionURL,
                        customIconPath: customIconPath.isEmpty ? nil : customIconPath,
                        notificationTitle: notificationTitle.isEmpty ? nil : notificationTitle,
                        notificationBodyTemplate: notificationBodyTemplate.isEmpty ? nil : notificationBodyTemplate
                    )

                    NotificationService.shared.sendPreview(watcher: previewWatcher, testValue: "3")
                    previewStatus = "Sent! Check your notifications."

                    // Clear status after a few seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        previewStatus = nil
                    }
                } else {
                    previewStatus = "Permission denied. Enable in System Settings → Notifications"
                }
            }
        }
    }
}
