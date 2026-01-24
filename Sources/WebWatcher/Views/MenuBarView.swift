import SwiftUI

/// The main menu that appears when clicking the menu bar icon
struct MenuBarView: View {
    @ObservedObject var store: WatcherStore
    @ObservedObject var watcherService: WatcherService
    @Binding var showingAddWatcher: Bool
    @Binding var editingWatcher: Watcher?
    @Binding var showingSettings: Bool

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
                        }
                    )
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

    @State private var isHovering = false

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
            VStack(alignment: .leading, spacing: 2) {
                Text(watcher.name)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text(watcher.statusDisplay)
                    .font(.caption)
                    .foregroundColor(watcher.lastError != nil ? .red : .secondary)
                    .lineLimit(1)
            }

            Spacer()

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
