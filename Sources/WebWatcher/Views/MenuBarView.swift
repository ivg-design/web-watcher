import SwiftUI

/// The main menu that appears when clicking the menu bar icon
struct MenuBarView: View {
    @ObservedObject var store: WatcherStore
    @ObservedObject var watcherService: WatcherService
    @ObservedObject var gmailStore: GmailAccountStore
    @ObservedObject var emailWatcherStore: EmailWatcherStore
    @Binding var showingAddWatcher: Bool
    @Binding var editingWatcher: Watcher?
    @Binding var showingSettings: Bool
    var onOpenWatcher: (Watcher) -> Void
    var onOpenGmail: (GmailAccount) -> Void
    var onEditEmailWatcher: (EmailWatcher) -> Void
    var onOpenEmailWatcher: (EmailWatcher) -> Void
    var onReconnectGmail: (GmailAccount) -> Void

    /// Accounts still worth a row of their own once their email watchers are doing the
    /// notifying (G2/G4): still-broad "notify everything" accounts, accounts nobody has
    /// scoped a watcher to yet, and accounts that need attention. A healthy account whose
    /// watchers already cover it would just be visual noise repeated twice.
    private var compactGmailAccounts: [GmailAccount] {
        gmailStore.accounts.filter { account in
            account.notifyAllMail || emailWatcherStore.watchers(for: account.id).isEmpty || account.lastError != nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Web Watcher")
                    .font(.headline)
                Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"))")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: {
                    if let url = URL(string: "https://github.com/ivg-design/web-watcher#readme") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Image(systemName: "info.circle")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("View documentation")

                if watcherService.isRunning {
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Watchers list
            if store.watchers.isEmpty {
                Text("No watchers configured")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(store.watchers) { watcher in
                    WatcherRowView(
                        watcher: watcher,
                        onToggle: { enabled in
                            var updated = watcher
                            updated.isEnabled = enabled
                            store.update(updated)
                            watcherService.watcherUpdated(updated)
                        },
                        onEdit: {
                            editingWatcher = watcher
                        },
                        onCheckNow: {
                            watcherService.checkNow(watcher)
                        },
                        onOpen: {
                            onOpenWatcher(watcher)
                        }
                    )
                }
            }

            // Email section (G2/G4): Gmail sender watchers plus the accounts that still
            // need a row of their own — shown whenever there's an account or a watcher,
            // so removing the last watcher never leaves an orphaned "Gmail" header behind.
            if !gmailStore.accounts.isEmpty || !emailWatcherStore.watchers.isEmpty {
                Divider()

                HStack {
                    Image(systemName: "envelope")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Email")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 4)

                ForEach(emailWatcherStore.watchers) { watcher in
                    EmailWatcherRowView(
                        watcher: watcher,
                        onToggle: { enabled in
                            var updated = watcher
                            updated.isEnabled = enabled
                            emailWatcherStore.update(updated)
                        },
                        onEdit: {
                            onEditEmailWatcher(watcher)
                        },
                        onOpen: {
                            onOpenEmailWatcher(watcher)
                        }
                    )
                }

                ForEach(compactGmailAccounts) { account in
                    if let lastError = account.lastError {
                        HStack {
                            Text("⚠︎ \(account.email): \(lastError)")
                                .font(.caption2)
                                .foregroundColor(.red)
                                .lineLimit(1)
                            Spacer()
                            Button("Reconnect") {
                                onReconnectGmail(account)
                            }
                            .font(.caption2)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                    } else {
                        GmailAccountRowView(
                            account: account,
                            onToggle: { enabled in
                                var updated = account
                                updated.isEnabled = enabled
                                gmailStore.update(updated)
                            },
                            onOpen: {
                                onOpenGmail(account)
                            }
                        )
                    }
                }
            }

            Divider()

            // Actions
            Button(action: { showingAddWatcher = true }) {
                HStack {
                    Image(systemName: "plus.circle")
                    Text("Add Watcher")
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .padding(.vertical, 6)

            Button(action: { watcherService.checkAllNow() }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Check All Now")
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .padding(.vertical, 6)
            .disabled(store.watchers.filter { $0.isEnabled }.isEmpty)

            Divider()

            // Status
            if let lastCheck = watcherService.lastCheckTime {
                Text("Last check: \(lastCheck.formatted(.relative(presentation: .named)))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.vertical, 4)

                Divider()
            }

            // Settings
            Button(action: { showingSettings = true }) {
                HStack {
                    Image(systemName: "gear")
                    Text("Settings...")
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .padding(.vertical, 6)

            // Quit
            Button(action: { NSApplication.shared.terminate(nil) }) {
                HStack {
                    Image(systemName: "power")
                    Text("Quit")
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
        .frame(width: 280)
    }
}

/// Row for a single watcher in the menu
struct WatcherRowView: View {
    let watcher: Watcher
    let onToggle: (Bool) -> Void
    let onEdit: () -> Void
    let onCheckNow: () -> Void
    let onOpen: () -> Void

    @State private var isHovering = false

    /// Blocked watchers are amber and broken ones are red, so "I couldn't look"
    /// never reads like ordinary quiet.
    private var statusColor: Color {
        switch watcher.health {
        case .broken:  return .red
        case .blocked: return .orange
        case .unknown: return .secondary
        case .ok:      return .secondary
        }
    }

    private var statusIcon: String? {
        switch watcher.health {
        case .broken:  return "exclamationmark.triangle.fill"
        case .blocked: return "eye.slash"
        case .unknown, .ok: return nil
        }
    }

    var body: some View {
        HStack {
            // Enable/disable toggle
            Toggle("", isOn: Binding(
                get: { watcher.isEnabled },
                set: { onToggle($0) }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
            .scaleEffect(0.7)

            // Info
            Button(action: onOpen) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(watcher.name)
                            .fontWeight(.medium)
                            .lineLimit(1)

                        HStack(spacing: 4) {
                            if let icon = statusIcon {
                                Image(systemName: icon)
                                    .font(.caption2)
                                    .foregroundColor(statusColor)
                            }
                            Text(watcher.statusDisplay)
                                .font(.caption)
                                .foregroundColor(statusColor)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .help(watcher.lastCannotReason
                .flatMap { CannotReason(rawValue: $0)?.remedy } ?? watcher.statusDisplay)

            // Actions (show on hover)
            if isHovering {
                Button(action: onCheckNow) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("Check now")

                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("Edit")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(isHovering ? Color.gray.opacity(0.1) : Color.clear)
        .cornerRadius(4)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

/// Row for a single Gmail account in the menu
struct GmailAccountRowView: View {
    let account: GmailAccount
    let onToggle: (Bool) -> Void
    let onOpen: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack {
            Toggle("", isOn: Binding(
                get: { account.isEnabled },
                set: { onToggle($0) }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
            .scaleEffect(0.7)

            Button(action: onOpen) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(account.email)
                            .fontWeight(.medium)
                            .lineLimit(1)
                            .font(.caption)

                        Text(account.statusDisplay)
                            .font(.caption2)
                            .foregroundColor(account.lastError != nil ? .red : .secondary)
                            .lineLimit(1)
                    }
                    Spacer()

                    if account.unreadCount > 0 {
                        Text("\(account.unreadCount)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.blue))
                    }
                }
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())

            if isHovering {
                Button(action: onOpen) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("Open Gmail")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .background(isHovering ? Color.gray.opacity(0.1) : Color.clear)
        .cornerRadius(4)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

/// Row for a single email (Gmail sender) watcher in the "Email" menu section (§3.11).
struct EmailWatcherRowView: View {
    let watcher: EmailWatcher
    let onToggle: (Bool) -> Void
    let onEdit: () -> Void
    let onOpen: () -> Void

    @State private var isHovering = false

    private var statusColor: Color {
        watcher.lastError != nil ? .red : .secondary
    }

    /// Compact "12m"-style age for the trailing chip — deliberately terser than
    /// `EmailTimeFormatter.received`, which is meant for the full status line, not a chip.
    private var relativeChip: String? {
        guard let date = watcher.lastMatchDate else { return nil }
        let seconds = max(0, Int(Date().timeIntervalSince(date)))
        if seconds < 60 { return "\(seconds)s" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h" }
        return "\(hours / 24)d"
    }

    var body: some View {
        HStack {
            Toggle("", isOn: Binding(
                get: { watcher.isEnabled },
                set: { onToggle($0) }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
            .scaleEffect(0.7)

            Button(action: onOpen) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(watcher.displayName)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        Text(watcher.statusDisplay)
                            .font(.caption)
                            .foregroundColor(statusColor)
                            .lineLimit(1)
                    }

                    Spacer()

                    if watcher.unreadCount > 0 {
                        Text("\(watcher.unreadCount)")
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.blue))
                    } else if let relativeChip {
                        Text(relativeChip)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.gray.opacity(0.2)))
                    }
                }
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())

            if isHovering {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("Edit")

                Button(action: onOpen) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("Open in Gmail")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(isHovering ? Color.gray.opacity(0.1) : Color.clear)
        .cornerRadius(4)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
