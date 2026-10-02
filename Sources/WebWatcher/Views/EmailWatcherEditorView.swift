import SwiftUI
import AppKit

/// Editor for creating or editing a Gmail sender watcher (G2). Unlike `WatcherEditorView`
/// there's no page to probe — the only inputs are which account to watch and which senders
/// match — so the form stays flat: account, senders, sound, then Save.
struct EmailWatcherEditorView: View {
    @Environment(\.dismiss) var dismiss

    @ObservedObject var gmailStore: GmailAccountStore
    @ObservedObject var emailWatcherStore: EmailWatcherStore
    var gmailPolling: GmailPollingService?
    var existing: EmailWatcher?
    var onOpenSettings: () -> Void

    @State private var name: String = ""
    @State private var accountId: UUID?
    @State private var senders: [String] = []
    @State private var senderInput: String = ""
    @State private var senderError: String?
    @State private var notificationSound: Bool = true
    @State private var notificationExpanded = false
    @State private var customIconPath: String = ""
    @State private var notificationTitle: String = ""
    @State private var notificationBodyTemplate: String = ""
    @State private var previewStatus: String?

    @State private var isConnecting = false
    @State private var connectError: String?
    @State private var connectErrorIsClientNotConfigured = false

    var isEditing: Bool { existing != nil }

    /// Single source of truth for this editor's window height (§9.4) — read by both this
    /// view's own `.frame` and `AddWatcherView.size(for: .email)`.
    static let contentHeight: CGFloat = 620

    init(
        existing: EmailWatcher?,
        gmailStore: GmailAccountStore,
        emailWatcherStore: EmailWatcherStore,
        gmailPolling: GmailPollingService?,
        onOpenSettings: @escaping () -> Void
    ) {
        self.existing = existing
        self.gmailStore = gmailStore
        self.emailWatcherStore = emailWatcherStore
        self.gmailPolling = gmailPolling
        self.onOpenSettings = onOpenSettings
        _name = State(initialValue: existing?.name ?? "")
        _accountId = State(initialValue: existing?.accountId ?? gmailStore.accounts.first?.id)
        _senders = State(initialValue: existing?.senders ?? [])
        _notificationSound = State(initialValue: existing?.notificationSound ?? true)
        _customIconPath = State(initialValue: existing?.customIconPath ?? "")
        _notificationTitle = State(initialValue: existing?.notificationTitle ?? "")
        _notificationBodyTemplate = State(initialValue: existing?.notificationBodyTemplate ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text(isEditing ? "Edit Email Watcher" : "Add Email Watcher")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Name
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Name")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("e.g. Invoices from Acme", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Gmail account (§3.7: empty-state "Sign in with Google")
                    gmailAccountSection

                    Divider()

                    // Senders
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Senders")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack {
                            TextField("person@company.com or @company.com", text: $senderInput, onCommit: addSendersFromInput)
                                .textFieldStyle(.roundedBorder)
                            Button("Add", action: addSendersFromInput)
                                .disabled(senderInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }

                        ForEach(senders, id: \.self) { sender in
                            HStack {
                                Text(sender)
                                    .font(.caption)
                                Spacer()
                                Button(action: { senders.removeAll { $0 == sender } }) {
                                    Image(systemName: "xmark.circle")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 2)
                        }

                        if let senderError {
                            Text(senderError)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }

                    Divider()

                    Toggle("Play sound", isOn: $notificationSound)

                    DisclosureGroup("Notification", isExpanded: $notificationExpanded) {
                        notificationSection
                            .padding(.top, 8)
                    }

                    Text(footnoteText)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding()
            }

            Divider()

            // Actions
            HStack {
                if isEditing {
                    Button("Delete", role: .destructive) {
                        if let existing {
                            emailWatcherStore.delete(existing)
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
                .disabled(accountId == nil || senders.isEmpty)
            }
            .padding()
        }
        .frame(width: 480, height: Self.contentHeight)
    }

    // MARK: - Notification customization

    private var notificationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
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
                            .overlay(Image(systemName: "photo").foregroundColor(.gray))
                    }

                    TextField("Path to icon image", text: $customIconPath)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))

                    Button("Browse...") { pickIcon() }

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

            VStack(alignment: .leading, spacing: 4) {
                Text("Custom Notification Title (optional)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("{count} new from {sender}", text: $notificationTitle)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Custom Body Template (optional)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("• {subject}\nreceived {time}", text: $notificationBodyTemplate)
                    .textFieldStyle(.roundedBorder)
                Text("Placeholders: {count} {sender} {address} {subject} {time} {name}. Leave empty for the default; they work in the title too.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

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
            customIconPath = NotificationIconStore.importIcon(from: url.path) ?? url.path
        }
    }

    private func previewNotification() {
        previewStatus = "Requesting permission..."

        Task {
            let granted = await NotificationService.shared.requestPermission()

            await MainActor.run {
                guard granted else {
                    previewStatus = "Permission denied. Enable in System Settings → Notifications"
                    return
                }
                var preview = existing ?? EmailWatcher(accountId: accountId ?? UUID())
                preview.name = name.isEmpty ? (senders.isEmpty ? "Preview Watcher" : senders.joined(separator: ", ")) : name
                preview.senders = senders
                preview.notificationSound = notificationSound
                preview.customIconPath = customIconPath.isEmpty ? nil : customIconPath
                preview.notificationTitle = notificationTitle.isEmpty ? nil : notificationTitle
                preview.notificationBodyTemplate = notificationBodyTemplate.isEmpty ? nil : notificationBodyTemplate

                NotificationService.shared.sendEmailPreview(watcher: preview)
                previewStatus = "Sent! Check your notifications."

                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    previewStatus = nil
                }
            }
        }
    }

    // MARK: - Gmail account (§3.7)

    /// Accounts already connected → pick one (plus a small link to connect another).
    /// No accounts yet → a centered "Sign in with Google" empty state, or — if this build
    /// has no Google client at all, built-in or imported — a message pointing at Settings
    /// instead of a dead-end button.
    @ViewBuilder
    private var gmailAccountSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Gmail account")
                .font(.caption)
                .foregroundColor(.secondary)

            if gmailStore.accounts.isEmpty {
                emptyGmailAccountState
            } else {
                Picker("", selection: $accountId) {
                    ForEach(gmailStore.accounts) { account in
                        Text(account.email).tag(Optional(account.id))
                    }
                }
                .labelsHidden()

                Button(action: connectAccount) {
                    HStack(spacing: 4) {
                        if isConnecting {
                            ProgressView().scaleEffect(0.5).frame(width: 12, height: 12)
                        } else {
                            Image(systemName: "plus.circle").font(.caption)
                        }
                        Text("Connect another account…")
                    }
                }
                .buttonStyle(.link)
                .font(.caption)
                .disabled(isConnecting)

                if let connectError {
                    connectErrorMessage(connectError)
                }
            }
        }
    }

    @ViewBuilder
    private var emptyGmailAccountState: some View {
        VStack(spacing: 10) {
            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.system(size: 30))
                .foregroundColor(GoogleOAuthClientStore.shared.load() != nil ? .accentColor : .secondary)

            if GoogleOAuthClientStore.shared.load() == nil {
                // Neither the built-in client nor an imported override is available — a
                // "Sign in" button here would just fail, so point at where to fix it instead.
                Text("This build has no Google client configured — see Settings → Gmail → Advanced.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Button(action: connectAccount) {
                    HStack(spacing: 6) {
                        if isConnecting {
                            ProgressView().scaleEffect(0.6).frame(width: 14, height: 14)
                        }
                        Text("Sign in with Google")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isConnecting)

                Text("Opens Google in your browser. WebWatcher asks only for permission to read and manage your Gmail.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                if let connectError {
                    connectErrorMessage(connectError)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    @ViewBuilder
    private func connectErrorMessage(_ message: String) -> some View {
        VStack(spacing: 4) {
            Text(message)
                .font(.caption)
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if connectErrorIsClientNotConfigured {
                Button("Open Settings") { onOpenSettings() }
                    .font(.caption)
            }
        }
    }

    /// "Checked every <pollingInterval> ..." footnote (§3.11) — pulled from the currently
    /// selected account so it reflects the interval that will actually apply once saved.
    private var footnoteText: String {
        let interval = gmailStore.accounts.first(where: { $0.id == accountId })?.pollingInterval.displayName ?? "the poll interval"
        return "Checked every \(interval) (change in Settings). Only mail that lands in the Inbox is seen. Email watchers currently support Gmail accounts only."
    }

    /// Adds every sender parsed out of the text field. Using `SenderMatcher.split` (rather
    /// than `normalize` on the raw string) means a single typed address and a pasted list
    /// of several addresses go through the exact same path.
    private func addSendersFromInput() {
        let text = senderInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let parsed = SenderMatcher.split(text)
        guard !parsed.isEmpty else {
            senderError = "Enter an email address or @domain"
            return
        }

        senderError = nil
        for pattern in parsed where !senders.contains(pattern) {
            senders.append(pattern)
        }
        senderInput = ""
    }

    private func connectAccount() {
        isConnecting = true
        connectError = nil
        connectErrorIsClientNotConfigured = false

        Task {
            do {
                let account = try await GmailAccountConnector.connect(store: gmailStore, polling: gmailPolling)
                await MainActor.run {
                    accountId = account.id
                    isConnecting = false
                }
            } catch let error as GmailOAuthService.OAuthError {
                await MainActor.run {
                    connectError = error.errorDescription ?? "Failed to connect the Gmail account."
                    if case .clientNotConfigured = error {
                        connectErrorIsClientNotConfigured = true
                    }
                    isConnecting = false
                }
            } catch {
                await MainActor.run {
                    connectError = error.localizedDescription
                    isConnecting = false
                }
            }
        }
    }

    /// Save disabled until an account is chosen and at least one sender is present (enforced
    /// by the button's `.disabled` above; this is the last line of defense in case that ever
    /// changes without updating both places).
    private func saveWatcher() {
        guard let accountId else { return }
        let previous = existing

        var watcher = existing ?? EmailWatcher(accountId: accountId)
        watcher.accountId = accountId
        watcher.senders = senders
        watcher.name = name.isEmpty ? senders.joined(separator: ", ") : name
        watcher.notificationSound = notificationSound
        // Typed or legacy paths are copied into the managed folder too, so the original
        // file can move or disappear without breaking the notification image.
        watcher.customIconPath = customIconPath.isEmpty ? nil : (NotificationIconStore.importIcon(from: customIconPath) ?? customIconPath)
        watcher.notificationTitle = notificationTitle.isEmpty ? nil : notificationTitle
        watcher.notificationBodyTemplate = notificationBodyTemplate.isEmpty ? nil : notificationBodyTemplate

        if existing != nil {
            emailWatcherStore.update(watcher)
        } else {
            emailWatcherStore.add(watcher)
        }

        Task {
            await gmailPolling?.emailWatcherSaved(watcher, previous: previous)
        }
    }
}
