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

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!

    private var store: WatcherStore!
    private var watcherService: WatcherService!
    private var gmailStore: GmailAccountStore!
    private var gmailPollingService: GmailPollingService!
    private var emailWatcherStore: EmailWatcherStore!

    private var addWatcherWindow: NSWindow?
    private var editWatcherWindow: NSWindow?
    private var editEmailWatcherWindow: NSWindow?
    private var settingsWindow: NSWindow?

    // MARK: - Cmd+Tab window bookkeeping (G3/§9.5)

    /// One `NSWindow.willCloseNotification` observer per open window, keyed so `present`'s
    /// own closure can remove exactly its own token (never a stale one for a window that
    /// closed and reopened) as the FIRST thing it does on close (§9.5).
    private var closeObservers: [ObjectIdentifier: NSObjectProtocol] = [:]
    private var openWindowIDs: Set<ObjectIdentifier> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        // Hidden marketing-capture mode (`--screenshots <dir>` / WW_SCREENSHOTS): sample data
        // only, no real stores, notifications, network or Safari. Normal launch is unchanged.
        if ScreenshotMode.isActive {
            ScreenshotRunner.shared.start()
            return
        }
        #endif
        guard shouldContinueAsPrimaryInstance() else {
            NSApp.terminate(nil)
            return
        }

        // Ensure launch-at-login registration points at the installed app location.
        if Bundle.main.bundleURL.path.hasPrefix("/Applications/") {
            AppSettings.shared.refreshLaunchAtLoginRegistrationIfNeeded()
        }

        // Initialize store and service
        store = WatcherStore()
        watcherService = WatcherService(store: store)
        gmailStore = GmailAccountStore.shared
        emailWatcherStore = EmailWatcherStore.shared
        gmailPollingService = GmailPollingService(store: gmailStore)

        // Create the status bar item with fixed width for the icon
        // Variable length lets the system centre the glyph with standard menu-bar
        // padding; the old fixed 28 pt slot rendered the symbol small and off-centre
        // next to other apps' items.
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = Self.menuBarImage()
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleNone
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

        // Start Gmail polling
        gmailPollingService.start()

        // Hide dock icon (menu bar app only)
        NSApp.setActivationPolicy(.accessory)

        // Herald bridge: callback listener + registration. Notifications go through Herald when it
        // is running and the setting allows; otherwise the native path below is used.
        NotificationService.shared.watcherLookup = { [weak self] id in
            self?.store.watchers.first(where: { $0.id == id })
        }
        NotificationService.shared.startHeraldBridge()

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


    /// The menu-bar glyph: the hourglass-with-eye symbol, drawn into a template canvas
    /// 22 pt tall whose width follows the glyph.
    ///
    /// The badge makes "hourglass.badge.eye" wider than it is tall, and the symbol box
    /// reserves room around it, so letting AppKit place it in a fixed 28 pt slot rendered
    /// it small and off-centre next to other apps' items. Scaling the symbol so the glyph
    /// itself is ~18 pt tall and centring it ourselves gives the neighbours' optical size
    /// and baseline while keeping the eye.
    static func menuBarImage() -> NSImage {
        let targetHeight: CGFloat = 18
        let config = NSImage.SymbolConfiguration(pointSize: 17, weight: .medium)
        guard let glyph = NSImage(systemSymbolName: "hourglass.badge.eye", accessibilityDescription: "Web Watcher")?
            .withSymbolConfiguration(config) else {
            return NSImage(systemSymbolName: "hourglass", accessibilityDescription: "Web Watcher") ?? NSImage()
        }
        let scale = targetHeight / max(glyph.size.height, 1)
        let drawn = NSSize(width: glyph.size.width * scale, height: targetHeight)
        let canvas = NSSize(width: max(22, ceil(drawn.width) + 2), height: 22)
        let image = NSImage(size: canvas, flipped: false) { rect in
            let origin = NSPoint(x: (rect.width - drawn.width) / 2, y: (rect.height - drawn.height) / 2)
            glyph.draw(in: NSRect(origin: origin, size: drawn), from: .zero, operation: .sourceOver, fraction: 1)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Web Watcher"
        return image
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
            gmailStore: gmailStore,
            emailWatcherStore: emailWatcherStore,
            onAddWatcher: { [weak self] in
                self?.showAddWatcher()
            },
            onEditWatcher: { [weak self] watcher in
                self?.showEditWatcher(watcher)
            },
            onShowSettings: { [weak self] in
                self?.showSettings()
            },
            onOpenWatcher: { [weak self] watcher in
                self?.popover.performClose(nil)
                BrowserNavigationService.shared.openWatcherDestination(watcher)
            },
            onOpenGmail: { [weak self] account in
                self?.popover.performClose(nil)
                if let url = account.gmailInboxURL {
                    NSWorkspace.shared.open(url)
                }
            },
            onEditEmailWatcher: { [weak self] watcher in
                self?.showEditEmailWatcher(watcher)
            },
            onOpenEmailWatcher: { [weak self] watcher in
                self?.popover.performClose(nil)
                guard let self else { return }
                let accountIndex = self.gmailStore.accounts.first(where: { $0.id == watcher.accountId })?.accountIndex ?? 0
                if let url = watcher.openURL(accountIndex: accountIndex) {
                    NSWorkspace.shared.open(url)
                }
            },
            onReconnectGmail: { [weak self] account in
                self?.reconnectGmailAccount(account)
            }
        )

        popover.contentViewController = NSHostingController(rootView: contentView)
    }

    private func showAddWatcher() {
        popover.performClose(nil)

        let editorView = AddWatcherView(
            store: store,
            watcherService: watcherService,
            gmailStore: gmailStore,
            emailWatcherStore: emailWatcherStore,
            gmailPolling: gmailPollingService,
            onOpenSettings: { [weak self] in
                self?.showSettings()
            },
            onKindChange: { [weak self] size in
                self?.addWatcherWindow?.setContentSize(size)
            }
        )

        let controller = NSHostingController(rootView: editorView)
        let window = NSWindow(contentViewController: controller)
        window.title = "Add Watcher"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 480, height: WatcherEditorView.contentHeight + AddWatcherView.barHeight))
        window.center()

        addWatcherWindow = window
        present(window) { [weak self] in self?.addWatcherWindow = nil }
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
        window.setContentSize(NSSize(width: 480, height: WatcherEditorView.contentHeight))
        window.center()

        editWatcherWindow = window
        present(window) { [weak self] in self?.editWatcherWindow = nil }
    }

    private func showEditEmailWatcher(_ watcher: EmailWatcher) {
        popover.performClose(nil)

        let editorView = EmailWatcherEditorView(
            existing: watcher,
            gmailStore: gmailStore,
            emailWatcherStore: emailWatcherStore,
            gmailPolling: gmailPollingService,
            onOpenSettings: { [weak self] in
                self?.showSettings()
            }
        )

        let controller = NSHostingController(rootView: editorView)
        let window = NSWindow(contentViewController: controller)
        window.title = "Edit Email Watcher"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 480, height: EmailWatcherEditorView.contentHeight))
        window.center()

        editEmailWatcherWindow = window
        present(window) { [weak self] in self?.editEmailWatcherWindow = nil }
    }

    private func showSettings() {
        popover.performClose(nil)

        let settingsView = SettingsView(gmailPolling: gmailPollingService)

        let controller = NSHostingController(rootView: settingsView)
        let window = NSWindow(contentViewController: controller)
        window.title = "Settings"
        window.styleMask = [.titled, .closable]
        window.center()

        settingsWindow = window
        present(window) { [weak self] in self?.settingsWindow = nil }
    }

    /// G3/§9.5: switches the app to `.regular` activation policy (the Dock icon appears —
    /// intended, it's what makes Cmd+Tab work at all) while ANY editor/Settings window is
    /// open, and back to `.accessory` once the last one closes, so the popover-only steady
    /// state stays out of the Dock and the switcher.
    ///
    /// `onClose` releases the caller's own stored `…Window` property — passed in rather than
    /// looked up by this shared helper, since it's the one thing that differs per call site.
    private func present(_ window: NSWindow, onClose: @escaping () -> Void) {
        window.isReleasedWhenClosed = false
        let id = ObjectIdentifier(window)
        openWindowIDs.insert(id)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)

        let token = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: window, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            // §9.5: remove the observer FIRST, then release the window (and its SwiftUI
            // view tree) via `onClose`, in the same closure — both must happen exactly once,
            // by this window's own close, never a stale token from a prior window reused by
            // an object at the same address after dealloc.
            if let token = self.closeObservers.removeValue(forKey: id) {
                NotificationCenter.default.removeObserver(token)
            }
            onClose()
            self.openWindowIDs.remove(id)
            if self.openWindowIDs.isEmpty {
                DispatchQueue.main.async {
                    NSApp.setActivationPolicy(.accessory)
                }
            }
        }
        closeObservers[id] = token
    }

    /// Re-runs OAuth for an account whose `lastError` is showing (§3.8) — used by both the
    /// menu bar's inline "Reconnect" and (indirectly, via Settings' own copy of this call)
    /// the Settings accounts list.
    private func reconnectGmailAccount(_ account: GmailAccount) {
        Task {
            do {
                _ = try await GmailAccountConnector.reconnect(account, store: gmailStore, polling: gmailPollingService)
            } catch {
                print("Gmail: reconnect failed for \(account.email): \(error)")
            }
        }
    }

    /// Nice-to-have (§3.7): clicking the Dock icon while every window is closed — reachable
    /// now that the app briefly runs `.regular` (G3) — opens Settings instead of doing
    /// nothing, since there's no main window to simply re-show.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showSettings()
        }
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        if ScreenshotMode.isActive {
            ScreenshotMode.cleanUp()
            return
        }
        watcherService.stop()
        gmailPollingService.stop()
        HeraldBridge.shared.stop()
    }

    /// Prevent duplicate menu bar instances; prefer the /Applications build when both are present.
    private func shouldContinueAsPrimaryInstance() -> Bool {
        guard let bundleID = Bundle.main.bundleIdentifier else {
            return true
        }

        let currentPID = ProcessInfo.processInfo.processIdentifier
        var otherInstances = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleID)
            .filter { $0.processIdentifier != currentPID }

        guard !otherInstances.isEmpty else {
            return true
        }

        let currentPath = Bundle.main.bundleURL.path
        let currentInApplications = currentPath.hasPrefix("/Applications/")

        if currentInApplications {
            var terminatedAny = false
            for other in otherInstances {
                let otherPath = other.bundleURL?.path ?? ""
                if !otherPath.hasPrefix("/Applications/") {
                    terminatedAny = other.terminate() || terminatedAny
                }
            }

            if terminatedAny {
                Thread.sleep(forTimeInterval: 0.2)
                otherInstances = NSRunningApplication
                    .runningApplications(withBundleIdentifier: bundleID)
                    .filter { $0.processIdentifier != currentPID }
            }
        }

        guard !otherInstances.isEmpty else {
            return true
        }

        otherInstances.first?.activate(options: [.activateIgnoringOtherApps])
        return false
    }
}

/// Wrapper view for the popover content that handles navigation
struct MenuBarContentView: View {
    @ObservedObject var store: WatcherStore
    @ObservedObject var watcherService: WatcherService
    @ObservedObject var gmailStore: GmailAccountStore
    @ObservedObject var emailWatcherStore: EmailWatcherStore
    var onAddWatcher: () -> Void
    var onEditWatcher: (Watcher) -> Void
    var onShowSettings: () -> Void
    var onOpenWatcher: (Watcher) -> Void
    var onOpenGmail: (GmailAccount) -> Void
    var onEditEmailWatcher: (EmailWatcher) -> Void
    var onOpenEmailWatcher: (EmailWatcher) -> Void
    var onReconnectGmail: (GmailAccount) -> Void

    @State private var showingAddWatcher = false
    @State private var editingWatcher: Watcher?
    @State private var showingSettings = false

    var body: some View {
        MenuBarView(
            store: store,
            watcherService: watcherService,
            gmailStore: gmailStore,
            emailWatcherStore: emailWatcherStore,
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
            ),
            onOpenWatcher: onOpenWatcher,
            onOpenGmail: onOpenGmail,
            onEditEmailWatcher: onEditEmailWatcher,
            onOpenEmailWatcher: onOpenEmailWatcher,
            onReconnectGmail: onReconnectGmail
        )
    }
}


// MARK: - Hidden screenshot mode (Debug builds only)

/// Launch with `--screenshots <dir>` (or env `WW_SCREENSHOTS=<dir>`) in a Debug build to
/// render each window with sample data and capture it for the marketing site. Release builds
/// compile this down to `isActive == false`, so nothing here can run for users.
enum ScreenshotMode {
    static let scrollNotification = Notification.Name("WWScreenshotScrollTo")

    static let outputDir: String? = {
        #if DEBUG
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--screenshots"), i + 1 < args.count { return args[i + 1] }
        if let env = ProcessInfo.processInfo.environment["WW_SCREENSHOTS"], !env.isEmpty { return env }
        #endif
        return nil
    }()

    static var isActive: Bool { outputDir != nil }

    private static let suiteName = "com.webwatcher.screenshots-run"

    /// Throwaway settings domain, removed again on exit — the user's real defaults are never touched.
    static var defaults: UserDefaults {
        isActive ? (UserDefaults(suiteName: suiteName) ?? .standard) : .standard
    }

    /// Temp folder holding every store file of a screenshot run.
    static let scratch: URL = {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ww-screenshots-\(ProcessInfo.processInfo.processIdentifier)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    static func scratchFile(_ name: String) -> URL { scratch.appendingPathComponent(name) }

    static func cleanUp() {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: scratch)
    }

    #if DEBUG
    /// Canned probe so the editor never talks to Safari.
    static let probe: (any ElementProbing)? = isActive ? CannedProbe() : nil
    /// Set by the Add Watcher editor so the runner can drive the Page → Element → Confirm steps.
    @MainActor static var pickerModel: ElementPickerModel?

    static func prefillNewWatcher(name: inout String, url: inout String, markProgrammatic: () -> Void) {
        markProgrammatic()
        name = "iPhone 17 Pro price"
        url = CannedProbe.pageURL
    }
    #else
    static let probe: (any ElementProbing)? = nil
    #endif
}

#if DEBUG
final class CannedProbe: ElementProbing, @unchecked Sendable {
    static let pageURL = "https://www.apple.com/shop/buy-iphone/iphone-17-pro"
    static let pageTitle = "Buy iPhone 17 Pro - Apple"

    static func candidates() -> [ElementCandidate] {
        [
            ElementCandidate(selector: "[data-autom='cart-count']", anchor: "[data-autom='cart']", strategy: .badgeText,
                             value: "2", label: "2 · inside Shopping Bag", detail: "Small number on the bag icon in the page header, found by its unique name",
                             technical: "data-autom=cart-count · 16×16 · top 12 px", tier: 1, score: 96),
            ElementCandidate(selector: "[data-autom='bag']", strategy: .autoBadge,
                             label: "Shopping Bag icon", detail: "Icon with no counter yet. Starts reading as soon as one appears",
                             technical: "data-autom=bag · 44×44 · top 0 px", tier: 2, score: 74),
            ElementCandidate(selector: ".rf-pdp-currentprice", strategy: .text,
                             value: "$1,199.00", label: "$1,199.00 · Price", detail: "Current price in the product summary, found by its stable class",
                             technical: ".rf-pdp-currentprice · 96×24 · top 212 px", tier: 4, score: 88),
            ElementCandidate(selector: "title", strategy: .title,
                             value: Self.pageTitle, label: "Page title", detail: "The browser tab title",
                             technical: "document.title", tier: 1, score: 40)
        ]
    }

    private func page(_ obs: Observation = .zero) -> ProbeReport {
        ProbeReport(observation: obs, pageTitle: Self.pageTitle, matchedURL: Self.pageURL, tabVisible: true, isLoading: false)
    }

    func scan(_ watcher: Watcher, profile: SiteProfile?) async -> ProbeReport {
        var r = page(); r.candidates = Self.candidates(); return r
    }
    func beginPick(_ watcher: Watcher, profile: SiteProfile?) async -> ProbeReport { page() }
    func pollPick(_ watcher: Watcher, profile: SiteProfile?) async -> ProbeReport { page() }
    func endPick(_ watcher: Watcher, profile: SiteProfile?) async {}
    func highlight(_ selector: String, watcher: Watcher, profile: SiteProfile?) async -> Bool { true }
    func reloadTab(for watcher: Watcher, profile: SiteProfile?) async -> Bool { true }
    func openBackgroundTab(for watcher: Watcher, profile: SiteProfile?) async -> Bool { true }
    func diagnose(_ watcher: Watcher, profile: SiteProfile?) async -> ProbeReport {
        var r = page(.value("1199"))
        r.steps = [DoctorStep(label: "Element found", passed: true, note: ".rf-pdp-currentprice"),
                   DoctorStep(label: "Reads a value", passed: true, note: "$1,199.00")]
        return r
    }
    func locate(_ watcher: Watcher, profile: SiteProfile?) async -> ProbeReport { page() }
    func pickConfirm(_ watcher: Watcher, profile: SiteProfile?) async -> ProbeReport { page() }
}

/// Opens each window with sample data, waits for layout, captures it with `screencapture -l`
/// (-o: no shadow), closes it, and finally quits.
@MainActor
final class ScreenshotRunner {
    static let shared = ScreenshotRunner()

    private let outDir = URL(fileURLWithPath: ScreenshotMode.outputDir ?? "/tmp", isDirectory: true)
    private let store = WatcherStore(appFolder: ScreenshotMode.scratch.appendingPathComponent("watchers", isDirectory: true))
    private let gmailStore = GmailAccountStore.shared
    private let emailStore = EmailWatcherStore.shared
    private lazy var service = WatcherService(store: store)
    private lazy var polling = GmailPollingService(store: gmailStore)
    private var webWatchers: [Watcher] = []
    private var emailWatcher: EmailWatcher!
    private var failures: [String] = []

    func start() {
        try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        NSApp.setActivationPolicy(.regular)
        seed()
        Task { @MainActor in
            await self.runAll()
            if !self.failures.isEmpty { print("screenshots: FAILED \(self.failures)") }
            NSApp.terminate(nil)
        }
    }

    // MARK: Sample data

    private func seed() {
        let now = Date()
        var apple = Watcher(name: "iPhone 17 Pro price", url: CannedProbe.pageURL, selector: ".rf-pdp-currentprice",
                            watchType: .textChange, interval: .minutes5, anchorSelector: nil)
        apple.lastValue = "$1,199.00"; apple.lastConclusiveValue = "$1,199.00"; apple.lastCheck = now.addingTimeInterval(-45)
        apple.everMatched = true
        var github = Watcher(name: "WebWatcher releases", url: "https://github.com/ivg-design/web-watcher/releases",
                             selector: "a.Link--primary[href*='/releases/tag/']", watchType: .textChange, interval: .minutes10)
        github.lastValue = "v1.7.0"; github.lastConclusiveValue = "v1.7.0"; github.lastCheck = now.addingTimeInterval(-120)
        github.everMatched = true
        webWatchers = [apple, github]
        store.watchers = webWatchers

        var account = GmailAccount(email: "alex@example.com", displayName: "Alex", pollingInterval: .minute1)
        account.accessToken = "sample"; account.refreshToken = "sample"
        account.tokenExpiresAt = now.addingTimeInterval(3600); account.lastCheck = now.addingTimeInterval(-30)
        account.unreadCount = 3
        gmailStore.add(account)

        var mail = EmailWatcher(name: "Acme invoices", accountId: account.id, senders: ["billing@acme.com", "@acme-pay.com"])
        mail.unreadCount = 3
        mail.lastMatchDate = now.addingTimeInterval(-540)
        mail.lastMatchFrom = "Acme Billing <billing@acme.com>"
        mail.lastMatchSubject = "Invoice 2041 is ready"
        mail.recentSubjects = ["Invoice 2041 is ready", "Payment received, thank you", "Your October statement"]
        mail.matchCount = 12
        emailStore.add(mail)
        emailWatcher = mail

        service.isRunning = true
        service.lastCheckTime = now.addingTimeInterval(-45)
    }

    // MARK: Windows

    private func runAll() async {
        await shootPopover()
        await shootAddWatcher()
        await shootWindow("watcher-editor", title: "Edit Watcher",
                          size: NSSize(width: 480, height: WatcherEditorView.contentHeight),
                          view: WatcherEditorView(store: store, watcherService: service, existingWatcher: webWatchers[0]))
        await shootWindow("gmail-sender-editor", title: "Edit Email Watcher",
                          size: NSSize(width: 480, height: EmailWatcherEditorView.contentHeight),
                          view: EmailWatcherEditorView(existing: emailWatcher, gmailStore: gmailStore, emailWatcherStore: emailStore,
                                                       gmailPolling: polling, onOpenSettings: {}))
        // Settings: one window, scrolled to each section in turn.
        let settings = makeWindow(title: "Settings", size: nil, view: SettingsView(gmailPolling: polling))
        show(settings)
        await settle(1.5)
        capture(settings, "settings-general")
        for (id, name) in [("permissions", "permissions"), ("notifications", "settings-notifications"), ("gmail", "settings-gmail")] {
            NotificationCenter.default.post(name: ScreenshotMode.scrollNotification, object: id)
            await settle(0.8)
            capture(settings, name)
        }
        settings.close()
        await settle(0.3)
    }

    private func shootPopover() async {
        let content = MenuBarContentView(
            store: store, watcherService: service, gmailStore: gmailStore, emailWatcherStore: emailStore,
            onAddWatcher: {}, onEditWatcher: { _ in }, onShowSettings: {}, onOpenWatcher: { _ in },
            onOpenGmail: { _ in }, onEditEmailWatcher: { _ in }, onOpenEmailWatcher: { _ in }, onReconnectGmail: { _ in })
        let host = NSHostingView(rootView: content)
        let size = NSSize(width: 300, height: max(host.fittingSize.height, 200))
        let blur = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
        blur.material = .popover; blur.state = .active; blur.blendingMode = .behindWindow
        blur.wantsLayer = true; blur.layer?.cornerRadius = 12; blur.layer?.masksToBounds = true
        host.frame = NSRect(x: (size.width - host.fittingSize.width) / 2, y: 0, width: host.fittingSize.width, height: size.height)
        host.autoresizingMask = [.height]
        blur.addSubview(host)
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.isOpaque = false; window.backgroundColor = .clear; window.hasShadow = false
        window.contentView = blur
        window.center()
        show(window)
        await settle(1.2)
        capture(window, "popover")
        window.close()
        await settle(0.3)
    }

    private func shootAddWatcher() async {
        var window: NSWindow!
        let view = AddWatcherView(
            store: store, watcherService: service, gmailStore: gmailStore, emailWatcherStore: emailStore, gmailPolling: polling,
            onOpenSettings: {}, onKindChange: { size in window?.setContentSize(size) })
        window = makeWindow(title: "Add Watcher",
                            size: NSSize(width: 480, height: WatcherEditorView.contentHeight + AddWatcherView.barHeight), view: view)
        show(window)
        await settle(1.5)
        capture(window, "add-watcher-page")

        guard let model = ScreenshotMode.pickerModel else { failures.append("pickerModel"); window.close(); return }
        model.locate()
        await settle(2.0)
        capture(window, "add-watcher-element")

        if let price = model.candidates.first(where: { $0.strategy == .text }) {
            model.useCandidate(price)
            if model.pendingChoice != nil, let first = model.choices.first(where: { $0.recommended }) ?? model.choices.first {
                model.chooseStrategy(first.id)
            }
        } else { failures.append("price candidate") }
        await settle(2.0)
        capture(window, "add-watcher-confirm")
        window.close()
        await settle(0.3)
    }

    private func shootWindow<V: View>(_ name: String, title: String, size: NSSize, view: V) async {
        let window = makeWindow(title: title, size: size, view: view)
        show(window)
        await settle(1.5)
        capture(window, name)
        window.close()
        await settle(0.3)
    }

    // MARK: Helpers

    private func makeWindow<V: View>(title: String, size: NSSize?, view: V) -> NSWindow {
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.title = title
        window.styleMask = [.titled, .closable]
        if let size { window.setContentSize(size) }
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }

    private func show(_ window: NSWindow) {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func settle(_ seconds: Double) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    private func capture(_ window: NSWindow, _ name: String) {
        let path = outDir.appendingPathComponent("\(name).png").path
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        p.arguments = ["-l", String(window.windowNumber), "-o", "-x", path]
        do { try p.run(); p.waitUntilExit() } catch { failures.append(name) }
        if p.terminationStatus != 0 { failures.append(name) }
    }
}
#endif
