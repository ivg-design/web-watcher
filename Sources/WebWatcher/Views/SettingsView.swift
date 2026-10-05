import SwiftUI
import UniformTypeIdentifiers

/// Settings view for global app configuration
struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var gmailStore = GmailAccountStore.shared
    @ObservedObject var emailWatcherStore = EmailWatcherStore.shared
    /// Passed in by WebWatcherApp so an account added here starts polling immediately;
    /// nil (the default) keeps this view usable on its own, e.g. in previews.
    var gmailPolling: GmailPollingService?
    @Environment(\.dismiss) var dismiss
    @State private var isAddingGmailAccount = false
    @State private var gmailAuthError: String?
    @State private var reconnectingAccountId: UUID?
    @State private var oauthClient: GoogleOAuthClient? = GoogleOAuthClientStore.shared.load()
    @State private var oauthImportError: String?
    @State private var showingManualEntry = false
    @State private var manualClientId = ""
    @State private var manualClientSecret = ""
    @State private var downloadsCandidate: URL? = ScreenshotMode.isActive ? nil : GoogleOAuthClientParser.candidateFilesInDownloads().first
    @State private var notificationsGranted = false
    @State private var safariAutomationReport: BrowserNavigationService.PermissionReport = .undetermined
    @State private var defaultBrowserAutomationReport: BrowserNavigationService.PermissionReport = .undetermined
    @State private var defaultBrowserBundleID: String?
    @State private var defaultBrowserName = "Default Browser"
    @State private var isRefreshingPermissions = false
    @State private var heraldStatus: HeraldStatus?

    private static var windowHeight: CGFloat {
        #if DEBUG
        if ScreenshotMode.isActive {
            if let h = ScreenshotMode.settingsHeight { return h }
        }
        #endif
        return 650
    }

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

            ScrollViewReader { proxy in
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
                    .ssGroup("general")

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
                                report: safariAutomationReport,
                                buttonTitle: safariAutomationReport.isGranted ? "Open" : "Check",
                                action: {
                                    requestAutomationPermission(bundleID: "com.apple.Safari", appName: "Safari")
                                }
                            )

                            permissionStatusRow(
                                title: "\(defaultBrowserName) Automation",
                                report: defaultBrowserAutomationReport,
                                buttonTitle: defaultBrowserAutomationReport.isGranted ? "Open" : "Check",
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
                    .id("permissions")
                    .ssGroup("permissions")

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
                    .ssGroup("defaults")

                    // Notifications Section
                    GroupBox(label: Label("Notifications", systemImage: "bell")) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Deliver notifications via:")
                                Spacer()
                                Picker("", selection: $settings.notificationDelivery) {
                                    ForEach(NotificationDelivery.allCases) { delivery in
                                        Text(delivery.displayName).tag(delivery)
                                    }
                                }
                                .labelsHidden()
                                .frame(width: 190)
                            }

                            HStack(spacing: 6) {
                                Circle()
                                    .fill(heraldStatus?.isRunning == true ? Color.green : Color.secondary)
                                    .frame(width: 8, height: 8)
                                Text(heraldStatus?.line ?? "Checking Herald…")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Divider()

                            Button("Open System Notification Settings") {
                                openNotificationSettings()
                            }

                            Text("Configure notification banners, sounds, and grouping in System Settings.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .id("notifications")
                    .ssGroup("notifications")

                    // Gmail Section
                    GroupBox(label: Label("Gmail", systemImage: "envelope")) {
                        VStack(alignment: .leading, spacing: 14) {
                            accountsBlock

                            Divider()

                            // §9.4: the OAuth-client block moves under a collapsed
                            // "Advanced" disclosure now that most users never need to touch
                            // it — the built-in client (§9.6) makes "Add Gmail Account"
                            // work out of the box.
                            DisclosureGroup("Advanced: use your own Google OAuth client") {
                                oauthClientBlock
                                    .padding(.top, 8)
                            }

                            Divider()

                            Text(emailWatcherCountLine)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .id("gmail")
                    .ssGroup("gmail")

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
                    .ssGroup("data")

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
                    .ssGroup("about")
                }
                .padding()
            }
            #if DEBUG
            .onReceive(NotificationCenter.default.publisher(for: ScreenshotMode.scrollNotification)) { note in
                if let id = note.object as? String {
                    proxy.scrollTo(id, anchor: .top)
                }
            }
            #endif
            }
        }
        .frame(width: 450, height: Self.windowHeight)
        .onAppear {
            refreshPermissionStatus()
        }
        .task {
            // Keep the Herald status line current while Settings is open.
            if ScreenshotMode.isActive {
                heraldStatus = HeraldStatus(isRunning: true, port: 47321)
                return
            }
            while !Task.isCancelled {
                let status = await Task.detached { HeraldBridge.shared.currentStatus() }.value
                heraldStatus = status
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }
    }

    // MARK: - Gmail: Google OAuth client (§3.11)

    /// §9.4's exact status line: which client "Add Gmail Account" will actually use.
    private var oauthClientStatusText: String {
        if GoogleOAuthClientStore.shared.isUsingOverride, let oauthClient, oauthClient.isValid {
            return "Using your imported client (\(oauthClient.shortId))"
        }
        if GoogleOAuthClientStore.shared.builtInAvailable {
            return "Using WebWatcher's built-in Google client"
        }
        return "Not configured"
    }

    @ViewBuilder
    private var oauthClientBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Google OAuth client")
                .font(.subheadline)
                .fontWeight(.semibold)

            HStack(spacing: 6) {
                Circle()
                    .fill(oauthClient?.isValid == true ? Color.green : Color.secondary)
                    .frame(width: 8, height: 8)
                Text(oauthClientStatusText)
                    .font(.caption)
                if GoogleOAuthClientStore.shared.isUsingOverride {
                    Text("·")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button("Remove", role: .destructive) { removeOAuthClient() }
                        .buttonStyle(.link)
                        .font(.caption)
                }
            }

            HStack {
                Button("Import client JSON…") { importClientJSON() }
                Button("Enter manually…") { showingManualEntry = true }
            }

            if !GoogleOAuthClientStore.shared.isUsingOverride, let downloadsCandidate {
                HStack {
                    Text("Found \(downloadsCandidate.lastPathComponent) in Downloads")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    Spacer()
                    Button("Import") { importOAuthClient(from: downloadsCandidate) }
                        .font(.caption)
                }
            }

            if let oauthImportError {
                Text(oauthImportError)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            DisclosureGroup("How to get a client ID") {
                VStack(alignment: .leading, spacing: 8) {
                    oauthStepRow(
                        Text("1. Open Google Cloud Console → APIs & Services → Credentials."),
                        linkTitle: "console.cloud.google.com/apis/credentials",
                        url: "https://console.cloud.google.com/apis/credentials"
                    )
                    oauthStepRow(
                        Text("2. Create Credentials → OAuth client ID → Application type ")
                            + Text("Desktop app").fontWeight(.semibold)
                            + Text(" → Create → Download JSON.")
                    )
                    oauthStepRow(
                        Text("3. Enable the Gmail API."),
                        linkTitle: "console.cloud.google.com/apis/library/gmail.googleapis.com",
                        url: "https://console.cloud.google.com/apis/library/gmail.googleapis.com"
                    )
                    oauthStepRow(
                        Text("4. OAuth consent screen: if your Google Cloud project belongs to a Google Workspace organization, choose ")
                            + Text("Internal").fontWeight(.semibold)
                            + Text(". Otherwise choose External and add yourself under Test users — Google then revokes access every 7 days until the app is published.")
                    )
                    oauthStepRow(Text("5. Import the JSON here."))
                }
                .padding(.top, 6)
            }
        }
        .sheet(isPresented: $showingManualEntry) {
            manualEntrySheet
        }
    }

    @ViewBuilder
    private func oauthStepRow(_ text: Text, linkTitle: String? = nil, url: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            text
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
            if let linkTitle, let url, let linkURL = URL(string: url) {
                Link(linkTitle, destination: linkURL)
                    .font(.caption2)
            }
        }
    }

    private var manualEntrySheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Enter Google OAuth client")
                .font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                Text("Client ID")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("xxxx.apps.googleusercontent.com", text: $manualClientId)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Client secret")
                    .font(.caption)
                    .foregroundColor(.secondary)
                SecureField("Client secret", text: $manualClientSecret)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    manualClientId = ""
                    manualClientSecret = ""
                    showingManualEntry = false
                }
                Button("Save") { saveManualOAuthClient() }
                    .keyboardShortcut(.return)
                    .disabled(!GoogleOAuthClient(clientId: manualClientId, clientSecret: manualClientSecret, projectId: nil, sourceName: nil).isValid)
            }
        }
        .padding()
        .frame(width: 380)
    }

    private func importClientJSON() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK, let url = panel.url else { return }
        importOAuthClient(from: url)
    }

    private func importOAuthClient(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            var client = try GoogleOAuthClientParser.parse(data)
            client.sourceName = url.lastPathComponent
            GoogleOAuthClientStore.shared.save(client)
            oauthClient = client
            oauthImportError = nil
        } catch {
            oauthImportError = error.localizedDescription
        }
    }

    private func saveManualOAuthClient() {
        let client = GoogleOAuthClient(
            clientId: manualClientId.trimmingCharacters(in: .whitespacesAndNewlines),
            clientSecret: manualClientSecret.trimmingCharacters(in: .whitespacesAndNewlines),
            projectId: nil,
            sourceName: nil
        )
        GoogleOAuthClientStore.shared.save(client)
        oauthClient = client
        manualClientId = ""
        manualClientSecret = ""
        showingManualEntry = false
    }

    private func removeOAuthClient() {
        GoogleOAuthClientStore.shared.clear()
        oauthClient = nil
    }

    // MARK: - Gmail: Accounts (§3.11)

    private var emailWatcherCountLine: String {
        let count = emailWatcherStore.watchers.count
        return "\(count) email watcher\(count == 1 ? "" : "s") — add or edit them from the menu bar."
    }

    @ViewBuilder
    private var accountsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Accounts")
                .font(.subheadline)
                .fontWeight(.semibold)

            if gmailStore.accounts.isEmpty {
                Text("No Gmail accounts connected")
                    .foregroundColor(.secondary)
                    .font(.caption)
            } else {
                ForEach(gmailStore.accounts) { account in
                    accountRow(account)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Button(action: { addGmailAccount() }) {
                        HStack(spacing: 4) {
                            if isAddingGmailAccount {
                                ProgressView()
                                    .scaleEffect(0.5)
                                    .frame(width: 12, height: 12)
                            } else {
                                Image(systemName: "plus.circle")
                                    .font(.caption)
                            }
                            Text("Add Gmail Account")
                        }
                    }
                    // §9.4: enabled whenever ANY client resolves — built-in or imported —
                    // not just an imported override, now that most users never import one.
                    .disabled(isAddingGmailAccount || GoogleOAuthClientStore.shared.load() == nil)

                    Spacer()

                    if !gmailStore.accounts.isEmpty {
                        Picker("Poll interval:", selection: Binding(
                            get: { gmailStore.accounts.first?.pollingInterval ?? .minute1 },
                            set: { newInterval in
                                for i in gmailStore.accounts.indices {
                                    gmailStore.accounts[i].pollingInterval = newInterval
                                }
                                gmailStore.save()
                            }
                        )) {
                            ForEach(GmailPollInterval.allCases, id: \.self) { interval in
                                Text(interval.displayName).tag(interval)
                            }
                        }
                        .fixedSize()
                    }
                }

                if GoogleOAuthClientStore.shared.load() == nil {
                    Text("This build has no Google client configured — see Advanced below.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            if let error = gmailAuthError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            Text("If your Google app's consent screen is in Testing mode, Google revokes access every 7 days and you'll need to reconnect here.")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private func accountRow(_ account: GmailAccount) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Circle()
                    .fill(account.lastError != nil ? Color.red : (account.isAuthenticated ? Color.green : Color.orange))
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 1) {
                    Text(account.email)
                        .font(.caption)
                        .lineLimit(1)
                    Text(account.statusDisplay)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { account.isEnabled },
                    set: { newValue in
                        var updated = account
                        updated.isEnabled = newValue
                        gmailStore.update(updated)
                    }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
                .scaleEffect(0.7)

                Button(action: { gmailStore.delete(account) }) {
                    Image(systemName: "xmark.circle")
                        .foregroundColor(.red)
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("Remove account")
            }

            HStack {
                Toggle("Notify for every new email", isOn: Binding(
                    get: { account.notifyAllMail },
                    set: { newValue in
                        var updated = account
                        updated.notifyAllMail = newValue
                        gmailStore.update(updated)
                    }
                ))
                .font(.caption)
                .toggleStyle(.checkbox)

                Spacer()

                if account.lastError != nil {
                    Button(action: { reconnectGmailAccount(account) }) {
                        if reconnectingAccountId == account.id {
                            ProgressView()
                                .scaleEffect(0.5)
                                .frame(width: 12, height: 12)
                        } else {
                            Text("Reconnect")
                        }
                    }
                    .font(.caption)
                    .disabled(reconnectingAccountId == account.id)
                }
            }
            .padding(.leading, 16)
        }
        .padding(.vertical, 2)
    }

    private func addGmailAccount() {
        isAddingGmailAccount = true
        gmailAuthError = nil

        Task {
            do {
                _ = try await GmailAccountConnector.connect(store: gmailStore, polling: gmailPolling)
                await MainActor.run {
                    isAddingGmailAccount = false
                }
            } catch {
                await MainActor.run {
                    gmailAuthError = error.localizedDescription
                    isAddingGmailAccount = false
                }
            }
        }
    }

    private func reconnectGmailAccount(_ account: GmailAccount) {
        reconnectingAccountId = account.id
        Task {
            do {
                _ = try await GmailAccountConnector.reconnect(account, store: gmailStore, polling: gmailPolling)
            } catch {
                // `SettingsView` isn't `@MainActor`, so this `Task` resumes on a background
                // executor after the `await` above throws — publish the error the same way
                // `addGmailAccount()` already does, instead of mutating `@State` off-main.
                await MainActor.run {
                    gmailAuthError = error.localizedDescription
                }
            }
            await MainActor.run {
                reconnectingAccountId = nil
            }
        }
    }

    @ViewBuilder
    private func permissionStatusRow(
        title: String,
        granted: Bool,
        buttonTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        permissionStatusRow(
            title: title,
            report: granted ? .granted : .denied,
            buttonTitle: buttonTitle,
            action: action
        )
    }

    /// macOS reports three states, not two. Collapsing "undetermined" into "not granted"
    /// made allowed permissions show a red dot until the app happened to send an event.
    private func permissionStatusRow(
        title: String,
        report: BrowserNavigationService.PermissionReport,
        buttonTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        let color: Color
        let label: String
        switch report {
        case .granted:      color = .green;  label = "Granted"
        case .denied:       color = .red;    label = "Not granted"
        case .undetermined: color = .orange; label = "Not yet confirmed — click Check"
        }

        return HStack(spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 9, height: 9)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(buttonTitle, action: action)
        }
    }

    /// Refresh all permission indicators shown in the Settings dashboard.
    private func refreshPermissionStatus() {
        if ScreenshotMode.isActive {
            // Debug-only `--screenshots` mode: canned dashboard, no real permission probes.
            notificationsGranted = true
            safariAutomationReport = .granted
            defaultBrowserBundleID = "com.google.Chrome"
            defaultBrowserName = "Google Chrome"
            defaultBrowserAutomationReport = .granted
            return
        }
        isRefreshingPermissions = true

        Task {
            let notifications = await NotificationService.shared.checkPermission()
            let safariAutomation = BrowserNavigationService.shared.automationPermissionReport(bundleID: "com.apple.Safari")
            let defaultBrowserSnapshot = BrowserNavigationService.shared.defaultBrowserAutomationPermissionSnapshot()

            await MainActor.run {
                notificationsGranted = notifications
                safariAutomationReport = safariAutomation

                if let defaultBrowserSnapshot {
                    defaultBrowserBundleID = defaultBrowserSnapshot.bundleID
                    defaultBrowserName = defaultBrowserSnapshot.appName
                    defaultBrowserAutomationReport = BrowserNavigationService.shared.automationPermissionReport(bundleID: defaultBrowserSnapshot.bundleID)
                } else {
                    defaultBrowserBundleID = nil
                    defaultBrowserName = "Default Browser"
                    defaultBrowserAutomationReport = .undetermined
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


extension View {
    /// Debug screenshot runs can show a single Settings group (`ScreenshotMode.settingsOnly`); otherwise a no-op.
    @ViewBuilder func ssGroup(_ id: String) -> some View {
        #if DEBUG
        if ScreenshotMode.isActive, let only = ScreenshotMode.settingsOnly, !only.contains(id) { EmptyView() } else { self }
        #else
        self
        #endif
    }
}
