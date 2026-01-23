import SwiftUI
import AppKit

@main
struct WebWatcherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // We don't need a main window, just the menu bar
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!

    private var store: WatcherStore!
    private var watcherService: WatcherService!

    private var addWatcherWindow: NSWindow?
    private var editWatcherWindow: NSWindow?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize store and service
        store = WatcherStore()
        watcherService = WatcherService(store: store)

        // Create the status bar item with fixed width for the icon
        statusItem = NSStatusBar.system.statusItem(withLength: 28)

        if let button = statusItem.button {
            // Create larger icon with proper configuration
            let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
            if let image = NSImage(systemSymbolName: "hourglass.badge.eye", accessibilityDescription: "Web Watcher") {
                image.isTemplate = true // Adapts to menu bar appearance (light/dark)
                let configuredImage = image.withSymbolConfiguration(config)
                button.image = configuredImage
                button.imagePosition = .imageOnly
            }
            button.action = #selector(togglePopover)
            button.target = self
        }

        // Create the popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 400)
        popover.behavior = .transient
        popover.animates = true

        updatePopoverContent()

        // Start watching
        watcherService.start()

        // Hide dock icon (menu bar app only)
        NSApp.setActivationPolicy(.accessory)

        // Request notification permission
        Task {
            let granted = await NotificationService.shared.requestPermission()
            if !granted {
                await MainActor.run {
                    showNotificationPermissionAlert()
                }
            }
        }
    }

    private func showNotificationPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Configure Notifications"
        alert.informativeText = """
        To receive notification banners and sounds:

        1. Open System Settings → Notifications
        2. Find "WebWatcher" in the list
        3. Enable "Allow Notifications"
        4. Set alert style to "Banners" or "Alerts"
        5. Enable "Play sound for notifications"
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open Notification Settings")
        alert.addButton(withTitle: "Later")

        if alert.runModal() == .alertFirstButtonReturn {
            // Open directly to Notifications settings
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")!)
        }
    }

    @objc func togglePopover() {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                updatePopoverContent()
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                popover.contentViewController?.view.window?.makeKey()
            }
        }
    }

    private func updatePopoverContent() {
        let contentView = MenuBarContentView(
            store: store,
            watcherService: watcherService,
            onAddWatcher: { [weak self] in
                self?.showAddWatcher()
            },
            onEditWatcher: { [weak self] watcher in
                self?.showEditWatcher(watcher)
            },
            onShowSettings: { [weak self] in
                self?.showSettings()
            }
        )

        popover.contentViewController = NSHostingController(rootView: contentView)
    }

    private func showAddWatcher() {
        popover.performClose(nil)

        let editorView = WatcherEditorView(
            store: store,
            watcherService: watcherService,
            existingWatcher: nil
        )

        let controller = NSHostingController(rootView: editorView)
        let window = NSWindow(contentViewController: controller)
        window.title = "Add Watcher"
        window.styleMask = [.titled, .closable]
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        addWatcherWindow = window
    }

    private func showEditWatcher(_ watcher: Watcher) {
        popover.performClose(nil)

        let editorView = WatcherEditorView(
            store: store,
            watcherService: watcherService,
            existingWatcher: watcher
        )

        let controller = NSHostingController(rootView: editorView)
        let window = NSWindow(contentViewController: controller)
        window.title = "Edit Watcher"
        window.styleMask = [.titled, .closable]
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        editWatcherWindow = window
    }

    private func showSettings() {
        popover.performClose(nil)

        let settingsView = SettingsView()

        let controller = NSHostingController(rootView: settingsView)
        let window = NSWindow(contentViewController: controller)
        window.title = "Settings"
        window.styleMask = [.titled, .closable]
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        settingsWindow = window
    }

    func applicationWillTerminate(_ notification: Notification) {
        watcherService.stop()
    }
}

/// Wrapper view for the popover content that handles navigation
struct MenuBarContentView: View {
    @ObservedObject var store: WatcherStore
    @ObservedObject var watcherService: WatcherService
    var onAddWatcher: () -> Void
    var onEditWatcher: (Watcher) -> Void
    var onShowSettings: () -> Void

    @State private var showingAddWatcher = false
    @State private var editingWatcher: Watcher?
    @State private var showingSettings = false

    var body: some View {
        MenuBarView(
            store: store,
            watcherService: watcherService,
            showingAddWatcher: Binding(
                get: { showingAddWatcher },
                set: { newValue in
                    if newValue {
                        onAddWatcher()
                    }
                    showingAddWatcher = false
                }
            ),
            editingWatcher: Binding(
                get: { editingWatcher },
                set: { watcher in
                    if let watcher = watcher {
                        onEditWatcher(watcher)
                    }
                    editingWatcher = nil
                }
            ),
            showingSettings: Binding(
                get: { showingSettings },
                set: { newValue in
                    if newValue {
                        onShowSettings()
                    }
                    showingSettings = false
                }
            )
        )
    }
}
