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
        let demo = DemoMode.isActive
        #else
        let demo = false
        #endif
        if !demo {
            guard shouldContinueAsPrimaryInstance() else {
                NSApp.terminate(nil)
                return
            }

            // Ensure launch-at-login registration points at the installed app location.
            if Bundle.main.bundleURL.path.hasPrefix("/Applications/") {
                AppSettings.shared.refreshLaunchAtLoginRegistrationIfNeeded()
            }
        }

        // Initialize store and service
        #if DEBUG
        if demo {
            store = WatcherStore(appFolder: ScreenshotMode.scratch.appendingPathComponent("watchers", isDirectory: true))
            DemoMode.seed(store: store)
            AppSettings.shared.notificationDelivery = .heraldWhenAvailable
        } else {
            store = WatcherStore()
        }
        #else
        store = WatcherStore()
        #endif
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
        popover.contentSize = NSSize(width: 300, height: 372)
        popover.behavior = .transient
        popover.animates = true

        updatePopoverContent()

        // Start watching (demo: no background timers, only the scripted check)
        if !demo {
            watcherService.start()

            // Start Gmail polling
            gmailPollingService.start()
        }

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
            if !granted && !demo {
                await MainActor.run {
                    showNotificationPermissionAlert()
                }
            }
        }

        #if DEBUG
        if demo {
            DemoRunner.shared.start(delegate: self)
        }
        #endif
    }

    #if DEBUG
    // Demo-mode accessors (Debug only).
    var demoWatcherService: WatcherService { watcherService }
    var demoStore: WatcherStore { store }
    var demoAddWatcherWindow: NSWindow? { addWatcherWindow }
    var demoPopoverShown: Bool { popover.isShown }
    /// Demo: show the popover anchored to a view of our own staged window instead of the real status item.
    func showPopover(anchoredTo view: NSView) {
        guard !popover.isShown else { return }
        updatePopoverContent()
        popover.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
    }
    func closePopover() { if popover.isShown { popover.performClose(nil) } }
    var demoStatusItemFrame: NSRect? {
        guard let b = statusItem.button, let w = b.window else { return nil }
        return w.convertToScreen(b.convert(b.bounds, to: nil))
    }
    #endif

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

    func showAddWatcher() {
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
        if ScreenshotMode.isActive || DemoMode.isActive {
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

    /// True for both the screenshot mode and the scripted demo mode: scratch stores and a
    /// throwaway defaults suite, never the user's real data.
    static var isolated: Bool {
        #if DEBUG
        return isActive || DemoMode.isActive
        #else
        return false
        #endif
    }

    private static let suiteName = "com.webwatcher.screenshots-run"

    /// Throwaway settings domain, removed again on exit — the user's real defaults are never touched.
    static var defaults: UserDefaults {
        isolated ? (UserDefaults(suiteName: suiteName) ?? .standard) : .standard
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
    /// Screenshot-run switches read by the views (Debug only): which tab Add Watcher opens on, how tall the
    /// editor / Settings windows are, and whether the editor's disclosure sections start open.
    @MainActor static var startOnEmail = false
    @MainActor static var editorHeightOverride: CGFloat?
    @MainActor static var settingsHeight: CGFloat?
    /// When set, Settings shows only these groups (ids: general, permissions, defaults, notifications, gmail, data, about).
    @MainActor static var settingsOnly: Set<String>?
    @MainActor static var editorAdvanced = false
    @MainActor static var editorNotification = false

    static func prefillNewWatcher(name: inout String, url: inout String, markProgrammatic: () -> Void) {
        markProgrammatic()
        if DemoMode.isActive {
            name = "Rive Community bell"
            url = DemoMode.pageURL
        } else {
            name = "Trail runner price"
            url = CannedProbe.pageURL
        }
    }
    #else
    static let probe: (any ElementProbing)? = nil
    #endif
}

#if DEBUG
final class CannedProbe: ElementProbing, @unchecked Sendable {
    static let pageURL = "https://shop.example.com/products/trail-runner"
    static let pageTitle = "Trail Runner - Example Shop"

    static func candidates() -> [ElementCandidate] {
        [
            ElementCandidate(selector: ".cart-count", anchor: ".cart-link", strategy: .badgeText,
                             value: "2", label: "2 · inside Cart", detail: "Small number on the cart icon in the page header, found by its unique name",
                             technical: "class=cart-count · 16×16 · top 12 px", tier: 1, score: 96),
            ElementCandidate(selector: ".cart-icon", strategy: .autoBadge,
                             label: "Cart icon", detail: "Icon with no counter yet. Starts reading as soon as one appears",
                             technical: "class=cart-icon · 44×44 · top 0 px", tier: 2, score: 74),
            ElementCandidate(selector: ".product-price .current", strategy: .text,
                             value: "$129.00", label: "$129.00 · Price", detail: "Current price in the product summary, found by its stable class",
                             technical: ".product-price .current · 96×24 · top 212 px", tier: 4, score: 88),
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
        var r = page(.value("129"))
        r.steps = [DoctorStep(label: "Element found", passed: true, note: ".product-price .current"),
                   DoctorStep(label: "Reads a value", passed: true, note: "$129.00")]
        return r
    }
    func locate(_ watcher: Watcher, profile: SiteProfile?) async -> ProbeReport { page() }
    func pickConfirm(_ watcher: Watcher, profile: SiteProfile?) async -> ProbeReport { page() }
}

/// A window that is placed far outside every display and never becomes key or main, yet
/// reports itself as key/main so its title bar draws the live (coloured) traffic lights.
/// AppKit's own "keep on a screen" constraint is switched off so the origin sticks.
final class OffscreenWindow: NSWindow {
    static let origin = NSPoint(x: -30000, y: -30000)
    override var isKeyWindow: Bool { true }
    override var isMainWindow: Bool { true }
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
    // Private "draw as the active window" queries of the title-bar chrome (Debug screenshots only), so the
    // traffic lights and title are coloured although this window is never key.
    @objc(_hasKeyAppearance) func ww_hasKeyAppearance() -> Bool { true }
    @objc(_hasActiveAppearance) func ww_hasActiveAppearance() -> Bool { true }
    @objc(_hasActiveControls) func ww_hasActiveControls() -> Bool { true }
    @objc(hasKeyAppearance) func ww_hasKeyAppearancePublic() -> Bool { true }
    @objc(_hasActiveAppearanceIgnoringKeyFocus) func ww_hasActiveAppearanceIgnoringKeyFocus() -> Bool { true }
    /// Private switches that make controls draw as active (Debug screenshots only).
    func forceActiveLook() {
        typealias SetBool = @convention(c) (AnyObject, Selector, Bool) -> Void
        for name in ["_setForceActiveControls:", "_setHasActiveAppearance:"] {
            let sel = Selector(name)
            if responds(to: sel), let m = class_getInstanceMethod(NSWindow.self, sel) {
                unsafeBitCast(method_getImplementation(m), to: SetBool.self)(self, sel, true)
            }
        }
    }
}

/// Renders every window with sample data OFFSCREEN (origin -30000,-30000, ordered in without
/// activating, never key) and captures each by window id. Capture methods are tried in order and
/// the first that yields a correct, non-blank image of the expected size wins:
/// screencapture -l, CGWindowListCreateImage, then in-process cacheDisplay at 2x. The method used
/// per shot is logged to `<dir>/capture.log`.
@MainActor
final class ScreenshotRunner {
    static let shared = ScreenshotRunner()

    private let outDir = URL(fileURLWithPath: ScreenshotMode.outputDir ?? "/tmp", isDirectory: true)
    private let store = WatcherStore(appFolder: ScreenshotMode.scratch.appendingPathComponent("watchers", isDirectory: true))
    private let gmailStore = GmailAccountStore.shared
    private let emailStore = EmailWatcherStore.shared
    private lazy var service = WatcherService(store: store)
    private lazy var polling = GmailPollingService(store: gmailStore)
    private var watchers: [Watcher] = []
    private var emailWatcher: EmailWatcher!
    private var failures: [String] = []
    private var logLines: [String] = []
    private let only: Set<String> = Set((ProcessInfo.processInfo.environment["WW_SHOTS_ONLY"] ?? "").split(separator: ",").map(String.init))

    func start() {
        try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        NSApp.setActivationPolicy(.accessory)   // no Dock icon, never frontmost
        // Overlay scrollers (volatile registered default: nothing is written to any defaults domain).
        UserDefaults.standard.register(defaults: ["AppleShowScrollBars": "WhenScrolling"])
        // Controls draw as in an active app (coloured switches, blue default buttons) although the app is
        // never activated: NSApplication.isActive is made to report true for this Debug process only.
        let alwaysActive: @convention(block) (AnyObject) -> Bool = { _ in true }
        if let m = class_getInstanceMethod(NSApplication.self, #selector(getter: NSApplication.isActive)) {
            method_setImplementation(m, imp_implementationWithBlock(alwaysActive))
        }
        log("NSApp.isActive reports \(NSApp.isActive)")
        AppSettings.shared.notificationDelivery = .heraldWhenAvailable
        Task { @MainActor in
            await self.runAll()
            self.log("screens: " + NSScreen.screens.map { NSStringFromRect($0.frame) }.joined(separator: " "))
            if !self.failures.isEmpty { self.log("FAILED \(self.failures)") }
            try? self.logLines.joined(separator: "\n").appending("\n").write(to: self.outDir.appendingPathComponent("capture.log"), atomically: true, encoding: .utf8)
            NSApp.terminate(nil)
        }
    }

    private func log(_ s: String) { print("screenshots: \(s)"); logLines.append(s) }
    private func wants(_ name: String) -> Bool { only.isEmpty || only.contains(name) }

    // MARK: Sample data (fictional, privacy-safe)

    private func resetGmail() {
        for e in emailStore.watchers { emailStore.delete(e) }
        for a in gmailStore.accounts { gmailStore.delete(a) }
    }

    private func seedGmail() {
        resetGmail()
        let now = Date()
        var account = GmailAccount(email: "alex@example.com", displayName: "Alex", pollingInterval: .minute1)
        account.accessToken = "sample"; account.refreshToken = "sample"
        account.tokenExpiresAt = now.addingTimeInterval(3600); account.lastCheck = now.addingTimeInterval(-30)
        account.unreadCount = 3
        gmailStore.add(account)
        var mail = EmailWatcher(name: "Billing emails", accountId: account.id, senders: ["billing@example.com", "@example-pay.com"])
        mail.unreadCount = 3
        mail.lastMatchDate = now.addingTimeInterval(-540)
        mail.lastMatchFrom = "Example Billing <billing@example.com>"
        mail.lastMatchSubject = "Invoice 2041 is ready"
        mail.recentSubjects = ["Invoice 2041 is ready", "Payment received, thank you", "Your October statement"]
        mail.matchCount = 12
        emailStore.add(mail)
        emailWatcher = mail
    }

    /// `changed`: the forum bell shows 3 new and the release page just moved; otherwise everything is quiet.
    private func seedWatchers(changed: Bool) {
        let now = Date()
        func make(_ name: String, _ url: String, _ sel: String, _ type: WatchType, _ interval: CheckInterval,
                  value: String, ago: TimeInterval, strategy: ProbeStrategy?, anchor: String? = nil, changedAgo: TimeInterval? = nil) -> Watcher {
            var w = Watcher(name: name, url: url, selector: sel, watchType: type, interval: interval, anchorSelector: anchor)
            w.strategy = strategy
            w.lastValue = value; w.lastConclusiveValue = value; w.lastCheck = now.addingTimeInterval(-ago); w.everMatched = true
            if let c = changedAgo { w.lastChangeDate = now.addingTimeInterval(-c) }
            return w
        }
        let bell = make("Community forum bell", "https://community.example.com/", ".header-bell .badge", .badgeNumber, .seconds30,
                        value: changed ? "3" : "0", ago: 20, strategy: .anchoredBadge, anchor: ".header-bell")
        let price = make("Trail runner price", "https://shop.example.com/products/trail-runner", ".product-price .current", .textChange, .minutes5,
                         value: "$129.00", ago: 45, strategy: nil, changedAgo: changed ? 3600 * 26 : nil)
        let notes = make("Release notes", "https://example.com/changelog", "h2.release-title", .textChange, .minutes10,
                         value: changed ? "Version 4.2.0" : "Version 4.1.3", ago: 120, strategy: nil, changedAgo: changed ? 420 : nil)
        let issues = make("Open issues", "https://tracker.example.com/issues?state=open", "li.issue-row", .elementCount, .minutes5,
                          value: "17", ago: 70, strategy: nil)
        let stock = make("Back in stock", "https://shop.example.com/products/trail-runner", "button.add-to-cart", .elementExists, .minutes2,
                         value: "false", ago: 30, strategy: nil)
        let banner = make("Sale banner", "https://shop.example.com/", "div.sale-banner", .elementDisappears, .minutes30,
                          value: "true", ago: 300, strategy: nil)
        let any = make("Forum bell (anything inside)", "https://community.example.com/", ".header-bell", .subtreeChange, .minute1,
                       value: "9f3a1c", ago: 15, strategy: nil, changedAgo: 900)
        watchers = [bell, price, notes, issues, stock, banner, any]
        store.watchers = [bell, price, notes, issues]
        service.isRunning = true
        service.lastCheckTime = now.addingTimeInterval(-45)
    }

    // MARK: Run

    private func runAll() async {
        seedWatchers(changed: false)
        seedGmail()

        // Popover: idle, changed, empty first run; light and dark.
        await shootPopover("popover", dark: false)
        await shootPopover("popover-dark", dark: true)
        seedWatchers(changed: true)
        await shootPopover("popover-changed", dark: false)
        await shootPopover("popover-changed-dark", dark: true)
        seedWatchers(changed: false)

        // Add watcher flow (web page -> element -> confirm) and the Gmail tab.
        await shootAddWatcher(dark: false)
        ScreenshotMode.startOnEmail = true
        await shootAddGmail()
        ScreenshotMode.startOnEmail = false

        // Watcher editor: one per watch type, plus the options-open variants.
        let types: [(String, Int)] = [("watcher-editor-badge", 0), ("watcher-editor", 1), ("watcher-editor-text-change", 2), ("watcher-editor-element-count", 3),
                                      ("watcher-editor-element-exists", 4), ("watcher-editor-element-disappears", 5), ("watcher-editor-anything-changes", 6)]
        for (name, i) in types {
            await shootWindow(name, title: "Edit Watcher", size: NSSize(width: 480, height: WatcherEditorView.contentHeight),
                              view: WatcherEditorView(store: store, watcherService: service, existingWatcher: watchers[i]))
        }
        await shootWindow("watcher-editor-dark", title: "Edit Watcher", dark: true, size: NSSize(width: 480, height: WatcherEditorView.contentHeight),
                          view: WatcherEditorView(store: store, watcherService: service, existingWatcher: watchers[1]))
        ScreenshotMode.editorHeightOverride = 1450
        ScreenshotMode.editorAdvanced = true; ScreenshotMode.editorNotification = true
        await shootWindow("watcher-editor-advanced", title: "Edit Watcher", size: NSSize(width: 480, height: 1450),
                          view: WatcherEditorView(store: store, watcherService: service, existingWatcher: watchers[1]))
        ScreenshotMode.editorHeightOverride = nil
        ScreenshotMode.editorAdvanced = false; ScreenshotMode.editorNotification = false

        // Gmail: connected sender editor, then sign-in (no account) editor and settings.
        await shootWindow("gmail-sender-editor", title: "Edit Email Watcher",
                          size: NSSize(width: 480, height: EmailWatcherEditorView.contentHeight),
                          view: EmailWatcherEditorView(existing: emailWatcher, gmailStore: gmailStore, emailWatcherStore: emailStore,
                                                       gmailPolling: polling, onOpenSettings: {}))
        await shootWindow("gmail-sender-editor-dark", title: "Edit Email Watcher", dark: true,
                          size: NSSize(width: 480, height: EmailWatcherEditorView.contentHeight),
                          view: EmailWatcherEditorView(existing: emailWatcher, gmailStore: gmailStore, emailWatcherStore: emailStore,
                                                       gmailPolling: polling, onOpenSettings: {}))

        // Settings: one shot per group (window fits the group), light and dark, plus the whole window.
        await shootSettingsSections(dark: false)
        await shootSettingsSections(dark: true)
        await shootSettingsWhole()

        // Gmail not connected
        resetGmail()
        await shootSettingsGmailSignedOut()
        await shootWindow("gmail-signin", title: "Add Email Watcher",
                          size: NSSize(width: 480, height: EmailWatcherEditorView.contentHeight),
                          view: EmailWatcherEditorView(existing: nil, gmailStore: gmailStore, emailWatcherStore: emailStore,
                                                       gmailPolling: polling, onOpenSettings: {}))

        // Permission alerts
        await shootAlert("permission-notifications", title: "Configure Notifications", text: """
        To receive notification banners and sounds:

        1. Open System Settings → Notifications
        2. Find "WebWatcher" in the list
        3. Enable "Allow Notifications"
        4. Set alert style to "Banners" or "Alerts"
        5. Enable "Play sound for notifications"
        """, style: .informational, buttons: ["Open Notification Settings", "Later"])
        await shootAlert("permission-automation", title: "Enable Browser Automation", text: """
        WebWatcher can’t read open tabs in Safari yet.

        If Safari is listed under:
        Privacy & Security -> Automation -> WebWatcher
        enable it there.

        If Safari is NOT listed, click "Reset Automation Permission", then click "Check All Now" in WebWatcher to trigger consent again.
        """, style: .warning, buttons: ["Open Automation Settings", "Reset Automation Permission", "OK"])

        // Empty first-run popover (no watchers, no accounts)
        store.watchers = []
        await shootPopover("popover-empty", dark: false)
        await shootPopover("popover-empty-dark", dark: true)
    }

    // MARK: Shots

    private func shootPopover(_ name: String, dark: Bool) async {
        guard wants(name) else { return }
        let content = MenuBarContentView(
            store: store, watcherService: service, gmailStore: gmailStore, emailWatcherStore: emailStore,
            onAddWatcher: {}, onEditWatcher: { _ in }, onShowSettings: {}, onOpenWatcher: { _ in },
            onOpenGmail: { _ in }, onEditEmailWatcher: { _ in }, onOpenEmailWatcher: { _ in }, onReconnectGmail: { _ in })
        let host = NSHostingView(rootView: content.environment(\.controlActiveState, .key).tint(Color(nsColor: .controlAccentColor)))
        let size = NSSize(width: 300, height: max(host.fittingSize.height, 200))
        let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        // The real popover is vibrancy over whatever is behind it; offscreen there is nothing behind,
        // so draw its resting colour (the system popover grey) instead.
        let body = NSView(frame: NSRect(origin: .zero, size: size))
        body.appearance = appearance
        body.wantsLayer = true
        body.layer?.cornerRadius = 12; body.layer?.masksToBounds = true
        body.layer?.borderWidth = 0.5
        body.layer?.backgroundColor = (dark ? NSColor(white: 0.17, alpha: 1) : NSColor(white: 0.965, alpha: 1)).cgColor
        body.layer?.borderColor = (dark ? NSColor(white: 1, alpha: 0.16) : NSColor(white: 0, alpha: 0.14)).cgColor
        host.appearance = appearance
        host.frame = NSRect(x: (size.width - host.fittingSize.width) / 2, y: 0, width: host.fittingSize.width, height: size.height)
        host.autoresizingMask = [.height]
        body.addSubview(host)
        let window = OffscreenWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.isOpaque = false; window.backgroundColor = .clear; window.hasShadow = false
        window.appearance = appearance
        window.contentView = body
        show(window)
        await settle(1.2)
        capture(window, name)
        window.close()
        await settle(0.2)
    }

    private func shootAddWatcher(dark: Bool) async {
        guard wants("add-watcher-page") || wants("add-watcher-element") || wants("add-watcher-confirm") else { return }
        ScreenshotMode.editorHeightOverride = 900   // tall enough that no step is cut off
        defer { ScreenshotMode.editorHeightOverride = nil }
        var window: NSWindow!
        let view = AddWatcherView(
            store: store, watcherService: service, gmailStore: gmailStore, emailWatcherStore: emailStore, gmailPolling: polling,
            onOpenSettings: {}, onKindChange: { size in window?.setContentSize(size); window?.setFrameOrigin(OffscreenWindow.origin) })
        window = makeWindow(title: "Add Watcher", dark: dark,
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
        await settle(0.2)
    }

    private func shootAddGmail() async {
        guard wants("add-watcher-gmail") else { return }
        var window: NSWindow!
        let view = AddWatcherView(
            store: store, watcherService: service, gmailStore: gmailStore, emailWatcherStore: emailStore, gmailPolling: polling,
            onOpenSettings: {}, onKindChange: { size in window?.setContentSize(size); window?.setFrameOrigin(OffscreenWindow.origin) })
        window = makeWindow(title: "Add Watcher", dark: false,
                            size: NSSize(width: 480, height: EmailWatcherEditorView.contentHeight + AddWatcherView.barHeight), view: view)
        show(window)
        await settle(1.5)
        capture(window, "add-watcher-gmail")
        window.close()
        await settle(0.2)
    }

    private func shootSettingsSections(dark: Bool) async {
        let sfx = dark ? "-dark" : ""
        // (groups shown, shot names, window content height that fits them)
        var sections: [(Set<String>, [String], CGFloat)] = [
            (["general"], ["settings-general" + sfx], 222),
            (["permissions"], ["settings-permissions" + sfx, "permissions" + sfx], 302),
            (["notifications"], ["settings-notifications" + sfx], 258),
            (["gmail"], ["settings-gmail" + sfx], 400),
        ]
        if !dark { sections += [(["defaults"], ["settings-defaults"], 238), (["data", "about"], ["settings-data-about"], 305)] }
        for (only, names, height) in sections where names.contains(where: { wants($0) }) {
            ScreenshotMode.settingsOnly = only
            ScreenshotMode.settingsHeight = height
            let window = makeWindow(title: "Settings", dark: dark, size: nil, view: SettingsView(gmailPolling: polling))
            show(window)
            await settle(1.5)
            for n in names { capture(window, n) }
            window.close()
            await settle(0.2)
        }
        ScreenshotMode.settingsOnly = nil
        ScreenshotMode.settingsHeight = nil
    }

    private func shootSettingsWhole() async {
        guard wants("settings-whole") else { return }
        ScreenshotMode.settingsHeight = 1300
        defer { ScreenshotMode.settingsHeight = nil }
        let window = makeWindow(title: "Settings", dark: false, size: nil, view: SettingsView(gmailPolling: polling))
        show(window)
        await settle(1.5)
        capture(window, "settings-whole")
        window.close()
        await settle(0.2)
    }

    private func shootSettingsGmailSignedOut() async {
        guard wants("settings-gmail-signin") else { return }
        ScreenshotMode.settingsOnly = ["gmail"]
        ScreenshotMode.settingsHeight = 235
        defer { ScreenshotMode.settingsOnly = nil; ScreenshotMode.settingsHeight = nil }
        let window = makeWindow(title: "Settings", dark: false, size: nil, view: SettingsView(gmailPolling: polling))
        show(window)
        await settle(1.5)
        capture(window, "settings-gmail-signin")
        window.close()
        await settle(0.2)
    }

    private func shootWindow<V: View>(_ name: String, title: String, dark: Bool = false, size: NSSize, view: V) async {
        guard wants(name) else { return }
        let window = makeWindow(title: title, dark: dark, size: size, view: view)
        show(window)
        await settle(1.5)
        capture(window, name)
        window.close()
        await settle(0.2)
    }

    private func shootAlert(_ name: String, title: String, text: String, style: NSAlert.Style, buttons: [String]) async {
        guard wants(name) else { return }
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        alert.alertStyle = style
        for b in buttons { alert.addButton(withTitle: b) }
        alert.layout()
        // NSAlert's own panel cannot be kept off the displays, so its laid-out content is moved into an
        // offscreen window of the same size (title bar hidden, as an alert has none).
        guard let content = alert.window.contentView else { return }
        let size = alert.window.frame.size
        let window = OffscreenWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.titled, .fullSizeContentView], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true; window.titleVisibility = .hidden
        for b in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] { window.standardWindowButton(b)?.isHidden = true }
        window.appearance = NSAppearance(named: .aqua)
        window.contentView = content
        window.setContentSize(size)
        show(window)
        await settle(1.0)
        capture(window, name)
        window.close()
        await settle(0.2)
    }

    // MARK: Helpers

    private func makeWindow<V: View>(title: String, dark: Bool = false, size: NSSize?, view: V) -> OffscreenWindow {
        let window = OffscreenWindow(contentViewController: NSHostingController(rootView: view.environment(\.controlActiveState, .key).tint(Color(nsColor: .controlAccentColor))))
        window.title = title
        window.styleMask = [.titled, .closable]
        if let size { window.setContentSize(size) }
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        return window
    }

    /// Place far outside every display and order in WITHOUT activating the app or making the window key.
    private func show(_ window: NSWindow) {
        window.setFrameOrigin(OffscreenWindow.origin)
        window.orderFrontRegardless()
        (window as? OffscreenWindow)?.forceActiveLook()
        window.setFrameOrigin(OffscreenWindow.origin)
        if NSScreen.screens.contains(where: { $0.frame.intersects(window.frame) }) {
            failures.append("ON-SCREEN \(window.title)")
            window.orderOut(nil)
        }
    }

    private func settle(_ seconds: Double) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    // MARK: Capture (by window id; first correct non-blank result wins)

    private func capture(_ window: NSWindow, _ name: String) {
        guard wants(name) else { return }
        _ = window.makeFirstResponder(nil)   // no focus ring / text selection in the shot
        if let root = window.contentView?.superview { Self.hideScrollers(root) }
        RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        let scale = max(window.backingScaleFactor, 1)
        let expW = Int((window.frame.width * 2).rounded()), expH = Int((window.frame.height * 2).rounded())
        _ = scale
        let attempts: [(String, () -> CGImage?)] = [
            ("screencapture", { self.viaScreencapture(window, name) }),
            ("CGWindowListCreateImage", { self.viaCGWindowList(window) }),
            ("cacheDisplay", { self.viaCacheDisplay(window) }),
        ]
        for (method, grab) in attempts {
            guard let img = grab() else { log("\(name): \(method) returned nothing"); continue }
            if let why = Self.problem(img, expW: expW, expH: expH) { log("\(name): \(method) rejected (\(why); got \(img.width)x\(img.height), want \(expW)x\(expH))"); continue }
            let rep = NSBitmapImageRep(cgImage: img)
            guard let data = rep.representation(using: .png, properties: [:]) else { continue }
            do { try data.write(to: outDir.appendingPathComponent("\(name).png")) } catch { failures.append(name); return }
            log("\(name): OK method=\(method) \(img.width)x\(img.height)")
            return
        }
        failures.append(name)
    }

    private func viaScreencapture(_ window: NSWindow, _ name: String) -> CGImage? {
        let path = ScreenshotMode.scratchFile("sc-\(name).png").path
        try? FileManager.default.removeItem(atPath: path)
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        p.arguments = ["-l", String(window.windowNumber), "-o", "-x", path]
        do { try p.run(); p.waitUntilExit() } catch { return nil }
        guard p.terminationStatus == 0, let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(src, 0, nil)
    }

    private func viaCGWindowList(_ window: NSWindow) -> CGImage? {
        typealias Fn = @convention(c) (CGRect, UInt32, UInt32, UInt32) -> Unmanaged<CGImage>?
        guard let h = dlopen(nil, RTLD_NOW), let sym = dlsym(h, "CGWindowListCreateImage") else { return nil }
        let fn = unsafeBitCast(sym, to: Fn.self)
        // optionIncludingWindow = 1<<3, boundsIgnoreFraming = 1<<0, bestResolution = 1<<3 (image option)
        return fn(.null, 1 << 3, UInt32(window.windowNumber), (1 << 0) | (1 << 3))?.takeRetainedValue()
    }

    private func viaCacheDisplay(_ window: NSWindow) -> CGImage? {
        guard let frameView = window.contentView?.superview ?? window.contentView else { return nil }
        let b = frameView.bounds
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(b.width * 2), pixelsHigh: Int(b.height * 2), bitsPerSample: 8,
                                         samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
        rep.size = b.size
        frameView.cacheDisplay(in: b, to: rep)
        return rep.cgImage
    }

    /// No scroll bar may appear in a screenshot: every scroll view gets overlay, hidden scrollers.
    private static func hideScrollers(_ view: NSView) {
        if let sv = view as? NSScrollView {
            sv.scrollerStyle = .overlay
            sv.hasVerticalScroller = false
            sv.hasHorizontalScroller = false
        }
        for sub in view.subviews { hideScrollers(sub) }
    }

    /// nil when the image is acceptable; otherwise the reason it is not.
    private static func problem(_ img: CGImage, expW: Int, expH: Int) -> String? {
        if abs(img.width - expW) > 3 || abs(img.height - expH) > 3 { return "wrong size" }
        let n = 48
        var px = [UInt8](repeating: 0, count: n * n * 4)
        guard let ctx = CGContext(data: &px, width: n, height: n, bitsPerComponent: 8, bytesPerRow: n * 4,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return "no context" }
        ctx.interpolationQuality = .low
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: n, height: n))
        var opaque = 0, lumSum = 0.0
        var buckets = Set<Int>()
        for i in 0..<(n * n) {
            let r = Int(px[i * 4]), g = Int(px[i * 4 + 1]), bl = Int(px[i * 4 + 2]), a = Int(px[i * 4 + 3])
            if a > 128 { opaque += 1 }
            lumSum += Double(r + g + bl) / 765
            buckets.insert((r / 24) << 16 | (g / 24) << 8 | (bl / 24))
        }
        if opaque < n * n / 2 { return "mostly transparent" }
        if lumSum / Double(n * n) < 0.02 { return "black" }
        if buckets.count < 4 { return "flat colour" }
        return nil
    }
}
#endif

// MARK: - Hidden scripted demo mode (Debug builds only)

/// `WW_DEMO=<dir>` (env) or `--demo <dir>` in a Debug build: the app launches normally (real
/// status item, popover, Add Watcher window, real Safari probe) on scratch stores and drives
/// a ~40 s human-paced walkthrough while an external `screencapture -V` records the screen.
/// Release builds compile this down to `isActive == false`.
enum DemoMode {
    static let outputDir: String? = {
        #if DEBUG
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--demo"), i + 1 < args.count { return args[i + 1] }
        if let env = ProcessInfo.processInfo.environment["WW_DEMO"], !env.isEmpty { return env }
        #endif
        return nil
    }()

    static var isActive: Bool {
        #if DEBUG
        return outputDir != nil
        #else
        return false
        #endif
    }

    #if DEBUG
    static var pageURL: String {
        let env = ProcessInfo.processInfo.environment["WW_DEMO_URL"] ?? ""
        return env.isEmpty ? "http://localhost:8765/?bumpAfter=29" : env
    }

    /// Set by the Add Watcher editor: runs the real `saveWatcher()` then closes the window.
    @MainActor static var saveHook: (() -> Void)?

    /// Set by the runner: receives the notification the service would have posted (title, subtitle, body).
    /// In demo mode the service never touches Notification Center or Herald.
    @MainActor static var onNotify: ((String, String, String) -> Void)?

    @MainActor static func seed(store: WatcherStore) {
        var w = Watcher(name: "WebWatcher releases", url: "https://github.com/ivg-design/web-watcher/releases",
                        selector: "a.Link--primary[href*='/releases/tag/']", watchType: .textChange, interval: .minutes10)
        w.lastValue = "v1.10.9"; w.lastConclusiveValue = "v1.10.9"
        w.lastCheck = Date().addingTimeInterval(-120)
        w.everMatched = true
        store.watchers = [w]
    }
    #endif
}

#if DEBUG
import WebKit

// MARK: - Demo stage (Debug only): every pixel of the recorded region belongs to a window this app owns.

private final class DemoStageWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { true }
}

/// The site's hero poster gradient (150deg: #f6b25c, #ef7a6b 35%, #e0508a 70%, #b44fd0).
private final class DemoGradientView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        let g = NSGradient(colorsAndLocations:
            (NSColor(srgbRed: 0xf6/255, green: 0xb2/255, blue: 0x5c/255, alpha: 1), 0),
            (NSColor(srgbRed: 0xef/255, green: 0x7a/255, blue: 0x6b/255, alpha: 1), 0.35),
            (NSColor(srgbRed: 0xe0/255, green: 0x50/255, blue: 0x8a/255, alpha: 1), 0.70),
            (NSColor(srgbRed: 0xb4/255, green: 0x4f/255, blue: 0xd0/255, alpha: 1), 1))
        // CSS 150deg points down and slightly right; in an unflipped view that is -60 degrees.
        g?.draw(in: bounds, angle: -60)
    }
}

private final class DemoFlippedView: NSView { override var isFlipped: Bool { true } }

/// Hand-drawn Safari chrome: 52 px toolbar + 30 px tab strip.
private final class DemoSafariChrome: NSView {
    static let barHeight: CGFloat = 52
    static let tabHeight: CGFloat = 30
    static var totalHeight: CGFloat { barHeight + tabHeight }
    var tabTitle = "(3) Feed \u{2014} Community" { didSet { needsDisplay = true } }
    override var isFlipped: Bool { true }

    private func symbol(_ name: String, _ pt: CGFloat, _ weight: NSFont.Weight = .regular) -> NSImage? {
        NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: pt, weight: weight))
    }

    private func tinted(_ img: NSImage?, _ color: NSColor, in rect: NSRect) {
        guard let img else { return }
        let t = NSImage(size: img.size, flipped: false) { r in
            img.draw(in: r); color.set(); r.fill(using: .sourceAtop); return true
        }
        let s = img.size
        t.draw(in: NSRect(x: rect.midX - s.width / 2, y: rect.midY - s.height / 2, width: s.width, height: s.height),
               from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
    }

    override func draw(_ dirtyRect: NSRect) {
        let w = bounds.width
        NSColor(srgbRed: 0.925, green: 0.925, blue: 0.93, alpha: 1).setFill()
        NSRect(x: 0, y: 0, width: w, height: Self.barHeight).fill()
        NSColor(srgbRed: 0.88, green: 0.88, blue: 0.89, alpha: 1).setFill()
        NSRect(x: 0, y: Self.barHeight, width: w, height: Self.tabHeight).fill()
        // Traffic lights, 12 px.
        let lights: [NSColor] = [NSColor(srgbRed: 1, green: 0.37, blue: 0.34, alpha: 1),
                                 NSColor(srgbRed: 1, green: 0.74, blue: 0.18, alpha: 1),
                                 NSColor(srgbRed: 0.16, green: 0.79, blue: 0.25, alpha: 1)]
        for (i, c) in lights.enumerated() {
            let r = NSRect(x: 18 + CGFloat(i) * 20, y: 20, width: 12, height: 12)
            c.setFill(); NSBezierPath(ovalIn: r).fill()
            NSColor.black.withAlphaComponent(0.15).setStroke()
            let p = NSBezierPath(ovalIn: r.insetBy(dx: 0.25, dy: 0.25)); p.lineWidth = 0.5; p.stroke()
        }
        // Back / forward.
        tinted(symbol("chevron.left", 14, .semibold), NSColor.black.withAlphaComponent(0.55), in: NSRect(x: 100, y: 14, width: 24, height: 24))
        tinted(symbol("chevron.right", 14, .semibold), NSColor.black.withAlphaComponent(0.28), in: NSRect(x: 128, y: 14, width: 24, height: 24))
        // Address field.
        let field = NSRect(x: (w - 380) / 2, y: 11, width: 380, height: 30)
        NSColor.black.withAlphaComponent(0.07).setFill()
        NSBezierPath(roundedRect: field, xRadius: 8, yRadius: 8).fill()
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 13), .foregroundColor: NSColor.black.withAlphaComponent(0.85)]
        let str = NSAttributedString(string: "localhost:8765", attributes: attrs)
        let ts = str.size()
        let lockW: CGFloat = 14, gap: CGFloat = 5
        let startX = field.midX - (lockW + gap + ts.width) / 2
        tinted(symbol("lock.fill", 10, .medium), NSColor.black.withAlphaComponent(0.5), in: NSRect(x: startX, y: field.midY - 7, width: lockW, height: 14))
        str.draw(at: NSPoint(x: startX + lockW + gap, y: field.midY - ts.height / 2))
        // Bar bottom hairline + active tab.
        NSColor.black.withAlphaComponent(0.12).setFill()
        NSRect(x: 0, y: Self.barHeight - 0.5, width: w, height: 0.5).fill()
        let tab = NSRect(x: (w - 320) / 2, y: Self.barHeight + 3, width: 320, height: Self.tabHeight - 3)
        NSColor(srgbRed: 0.97, green: 0.97, blue: 0.975, alpha: 1).setFill()
        NSBezierPath(roundedRect: tab, xRadius: 6, yRadius: 6).fill()
        let tAttrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor.black.withAlphaComponent(0.85)]
        let tStr = NSAttributedString(string: tabTitle, attributes: tAttrs)
        let tSize = tStr.size()
        tStr.draw(at: NSPoint(x: tab.midX - tSize.width / 2, y: tab.midY - tSize.height / 2))
        NSColor.black.withAlphaComponent(0.18).setFill()
        NSRect(x: 0, y: bounds.height - 0.5, width: w, height: 0.5).fill()
    }
}

private final class DemoNavDelegate: NSObject, WKNavigationDelegate {
    var onEvent: ((String) -> Void)?
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { onEvent?("demo webview loaded: \(webView.url?.absoluteString ?? "?")") }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { onEvent?("FAIL demo webview: \(error.localizedDescription)") }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { onEvent?("FAIL demo webview: \(error.localizedDescription)") }
}

@MainActor
final class DemoRunner {
    static let shared = DemoRunner()

    private weak var delegate: AppDelegate?
    private var t0 = Date()
    private var logLines: [String] = []
    private var failures = 0
    private let env = ProcessInfo.processInfo.environment

    private var recorder: Process?
    private var recorderExit: Int32?
    private var recordSeconds: Double = 46

    // Stage
    private var region = NSRect(x: 1120, y: 28, width: 1440, height: 900)   // top-left screen points
    private var regionString = "1120,28,1440,900"
    private var stage: NSWindow?
    private var pageWindow: NSWindow?
    private var bannerWindow: NSWindow?
    private var markButton: NSButton?
    private var chrome: DemoSafariChrome?
    private var demoWebView: WKWebView?
    private let navDelegate = DemoNavDelegate()
    private var safariWinID: String?
    private var notified: (String, String, String)?

    func start(delegate: AppDelegate) {
        self.delegate = delegate
        t0 = Date()
        Task { @MainActor in
            await self.run()
            await self.finish()
        }
    }

    // MARK: Geometry

    private var screenH: CGFloat { (NSScreen.screens.first ?? NSScreen.main)?.frame.height ?? 0 }

    /// Region-relative top-left rectangle -> Cocoa screen frame.
    private func screenFrame(_ ox: CGFloat, _ oy: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect {
        NSRect(x: region.minX + ox, y: screenH - (region.minY + oy) - h, width: w, height: h)
    }

    private func parseRegion() {
        regionString = (env["WW_DEMO_REGION"]?.isEmpty == false) ? env["WW_DEMO_REGION"]! : "1120,28,1440,900"
        let p = regionString.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        if p.count == 4 { region = NSRect(x: p[0], y: p[1], width: p[2], height: p[3]) }
    }

    // MARK: Stage

    private func buildStage(_ d: AppDelegate) {
        parseRegion()
        let frame = screenFrame(0, 0, region.width, region.height)
        let w = DemoStageWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        w.isReleasedWhenClosed = false
        w.level = .floating // above every other app's normal windows, whatever is active
        w.hasShadow = false
        w.isOpaque = true
        w.backgroundColor = .black
        let content = DemoGradientView(frame: NSRect(origin: .zero, size: frame.size))
        w.contentView = content
        w.setFrame(frame, display: true)

        // Menu-bar strip.
        let strip = NSView(frame: NSRect(x: 0, y: frame.height - 28, width: frame.width, height: 28))
        strip.wantsLayer = true
        strip.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.8).cgColor
        let hair = CALayer()
        hair.frame = CGRect(x: 0, y: 0, width: frame.width, height: 0.5)
        hair.backgroundColor = NSColor.black.withAlphaComponent(0.2).cgColor
        strip.layer?.addSublayer(hair)
        let clock = NSTextField(labelWithString: "Thu 8:14 PM")
        clock.font = .systemFont(ofSize: 13)
        clock.textColor = .black
        clock.sizeToFit()
        clock.setFrameOrigin(NSPoint(x: frame.width - 14 - clock.frame.width, y: (28 - clock.frame.height) / 2))
        strip.addSubview(clock)
        // Two ordinary status glyphs sit between the mark and the clock, so the popover (300 pt wide,
        // centred on the mark) stays inside the stage instead of clipping at the region's right edge.
        var cursorX = clock.frame.minX - 12
        for name in ["battery.75percent", "wifi"] {
            let glyph = NSImageView(frame: NSRect(x: 0, y: 2, width: 26, height: 24))
            glyph.image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
                .withSymbolConfiguration(.init(pointSize: 15, weight: .medium))
            glyph.contentTintColor = .black
            glyph.imageScaling = .scaleProportionallyDown
            cursorX -= 26
            glyph.setFrameOrigin(NSPoint(x: cursorX, y: 2))
            strip.addSubview(glyph)
            cursorX -= 8
        }
        let button = NSButton(frame: NSRect(x: cursorX - 28 - 60, y: 2, width: 28, height: 24))
        button.title = ""
        button.isBordered = false
        button.image = AppDelegate.menuBarImage()
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleNone
        button.contentTintColor = .black
        strip.addSubview(button)
        content.addSubview(strip)
        markButton = button
        stage = w

        // Fake Safari window (child, above the stage).
        let pw = NSWindow(contentRect: screenFrame(20, 70, 900, 760), styleMask: .borderless, backing: .buffered, defer: false)
        pw.isReleasedWhenClosed = false
        pw.isOpaque = false
        pw.backgroundColor = .clear
        pw.hasShadow = true
        pw.level = .floating
        let container = DemoFlippedView(frame: NSRect(x: 0, y: 0, width: 900, height: 760))
        container.wantsLayer = true
        container.layer?.cornerRadius = 10
        container.layer?.masksToBounds = true
        container.layer?.backgroundColor = NSColor.white.cgColor
        let ch = DemoSafariChrome(frame: NSRect(x: 0, y: 0, width: 900, height: DemoSafariChrome.totalHeight))
        container.addSubview(ch)
        chrome = ch
        let wv = WKWebView(frame: NSRect(x: 0, y: DemoSafariChrome.totalHeight, width: 900, height: 760 - DemoSafariChrome.totalHeight),
                           configuration: WKWebViewConfiguration())
        navDelegate.onEvent = { [weak self] m in Task { @MainActor in
            if m.hasPrefix("FAIL") { self?.fail(String(m.dropFirst(5))) } else { self?.log(m) } } }
        wv.navigationDelegate = navDelegate
        container.addSubview(wv)
        demoWebView = wv
        pw.contentView = container
        pw.setFrame(screenFrame(20, 70, 900, 760), display: true)
        w.addChildWindow(pw, ordered: .above)
        pageWindow = pw

        w.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true); NSCursor.hide(); CGWarpMouseCursorPosition(CGPoint(x: 24, y: 1400)) // cursor out of the region
        w.makeKeyAndOrderFront(nil)
        pw.invalidateShadow()
        if let url = URL(string: DemoMode.pageURL) { wv.load(URLRequest(url: url)) }
        log("stage up: region \(regionString)")
    }

    private func screenRect(of v: NSView) -> NSRect? {
        guard let w = v.window else { return nil }
        return w.convertToScreen(v.convert(v.bounds, to: nil))
    }

    // MARK: Safari (real tab, kept off the stage)

    nonisolated private static func osa(_ source: String) async -> (result: String?, error: String?) {
        await Task.detached {
            var err: NSDictionary?
            let r = NSAppleScript(source: source)?.executeAndReturnError(&err)
            if let err { return (nil, (err[NSAppleScript.errorMessage] as? String) ?? "\(err)") }
            return (r?.stringValue, nil)
        }.value
    }

    private func openSafariTab() async {
        let url = DemoMode.pageURL
        let script = """
        tell application "Safari"
            set beforeIDs to id of every window
            make new document with properties {URL:"\(url)"}
            set newID to missing value
            repeat 40 times
                repeat with w in windows
                    if (id of w) is not in beforeIDs then set newID to id of w
                end repeat
                if newID is not missing value then exit repeat
                delay 0.25
            end repeat
            if newID is missing value then error "new Safari window not found"
            set bounds of window id newID to {40, 1000, 940, 1400}
            return (newID as text) & "|" & (name of current tab of window id newID)
        end tell
        """
        let (res, err) = await Self.osa(script)
        if let err { fail("safari open: \(err)"); return }
        let parts = (res ?? "").split(separator: "|", maxSplits: 1).map(String.init)
        safariWinID = parts.first
        log("safari demo window id \(safariWinID ?? "?") created off-stage (bounds 40,1000,940,1400); tab name at creation: \(parts.count > 1 ? parts[1] : "?")")
    }

    private func verifySafariTab() async {
        guard let id = safariWinID else { fail("no safari window id"); return }
        let (res, err) = await Self.osa("tell application \"Safari\" to return name of current tab of window id \(id)")
        if let err { fail("safari verify: \(err)") } else { log("safari tab verified: \(res ?? "?")") }
    }

    // MARK: Recording

    private var rawURL: URL {
        URL(fileURLWithPath: DemoMode.outputDir ?? "/tmp", isDirectory: true).appendingPathComponent("raw.mov")
    }

    /// Spawned from this process so TCC attributes the screen recording to WebWatcher.app.
    private func startRecording() {
        recordSeconds = Double(env["WW_DEMO_SECONDS"] ?? "") ?? 46
        try? FileManager.default.createDirectory(at: rawURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? FileManager.default.removeItem(at: rawURL)
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        p.arguments = ["-V", String(Int(recordSeconds.rounded(.up))), "-R", regionString, "-x", rawURL.path]
        p.terminationHandler = { [weak self] proc in
            let status = proc.terminationStatus
            Task { @MainActor in
                self?.recorderExit = status
                if status != 0 || !FileManager.default.fileExists(atPath: self?.rawURL.path ?? "") {
                    self?.log("RECORDING FAILED (screencapture exited \(status) at t=\(String(format: "%.1f", self?.elapsed() ?? 0)))")
                }
            }
        }
        do {
            try p.run()
            recorder = p
            log("recording started: region \(regionString), \(Int(recordSeconds)) s -> \(rawURL.path)")
        } catch {
            log("RECORDING FAILED (could not launch screencapture: \(error.localizedDescription))")
        }
    }

    /// Waits for screencapture to exit (hard cap seconds + 5 after it started), logs status and file size.
    private func finishRecording(startedAt: Double) async {
        guard recorder != nil else { return }
        let cap = startedAt + recordSeconds + 5
        if await poll(max(0, cap - elapsed()), { self.recorderExit != nil }) == false {
            recorder?.terminate()
            _ = await poll(3, { self.recorderExit != nil })
            log("recording did not finish within cap; terminated")
        }
        let size = (try? FileManager.default.attributesOfItem(atPath: rawURL.path)[.size] as? Int) ?? nil
        log("recording exit status \(recorderExit.map(String.init) ?? "nil"), raw.mov size \(size.map(String.init) ?? "missing") bytes")
    }

    private func logFrame(_ name: String, _ r: NSRect?) {
        guard let r else { log("frame \(name): unavailable"); return }
        log("frame \(name): x=\(Int(r.minX)) y=\(Int(screenH - r.maxY)) w=\(Int(r.width)) h=\(Int(r.height))")
    }

    // MARK: Banner (our own macOS-style notification)

    private func showBanner(title: String, subtitle: String, body: String) {
        guard let stage else { return }
        let size = NSSize(width: 360, height: 76)
        let final = screenFrame(region.width - 16 - 360, 40, 360, 76)
        let w = NSWindow(contentRect: final, styleMask: .borderless, backing: .buffered, defer: false)
        w.isReleasedWhenClosed = false
        w.isOpaque = false
        w.backgroundColor = .clear
        w.hasShadow = true
        w.level = .floating
        let v = NSView(frame: NSRect(origin: .zero, size: size))
        v.wantsLayer = true
        v.layer?.cornerRadius = 14
        v.layer?.masksToBounds = true
        v.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.96).cgColor
        v.layer?.borderWidth = 0.5
        v.layer?.borderColor = NSColor.black.withAlphaComponent(0.12).cgColor
        let icon = NSImageView(frame: NSRect(x: 14, y: 20, width: 36, height: 36))
        icon.image = NSApp.applicationIconImage
        icon.imageScaling = .scaleProportionallyUpOrDown
        v.addSubview(icon)
        let t = NSTextField(labelWithString: title)
        t.font = .boldSystemFont(ofSize: 13)
        t.textColor = .black
        t.lineBreakMode = .byTruncatingTail
        t.frame = NSRect(x: 60, y: 50, width: 360 - 60 - 56, height: 17)
        v.addSubview(t)
        let msg = subtitle.isEmpty ? body : "\(subtitle)\n\(body)"
        let b = NSTextField(wrappingLabelWithString: msg)
        b.font = .systemFont(ofSize: 12)
        b.textColor = NSColor.black.withAlphaComponent(0.8)
        b.maximumNumberOfLines = 2
        b.lineBreakMode = .byTruncatingTail
        b.frame = NSRect(x: 60, y: 10, width: 360 - 60 - 14, height: 36)
        v.addSubview(b)
        let now = NSTextField(labelWithString: "now")
        now.font = .systemFont(ofSize: 11)
        now.textColor = .systemGray
        now.sizeToFit()
        now.setFrameOrigin(NSPoint(x: 360 - 14 - now.frame.width, y: 52))
        v.addSubview(now)
        w.contentView = v
        var start = final; start.origin.x += 40
        w.setFrame(start, display: true)
        w.alphaValue = 0
        stage.addChildWindow(w, ordered: .above)
        w.orderFront(nil)
        bannerWindow = w
        NSAnimationContext.beginGrouping()
        NSAnimationContext.current.duration = 0.32
        NSAnimationContext.current.timingFunction = CAMediaTimingFunction(name: .easeOut)
        w.animator().setFrame(final, display: true)
        w.animator().alphaValue = 1
        NSAnimationContext.endGrouping()
        log("banner shown")
    }

    private func clickBanner() async {
        guard let w = bannerWindow, let stage else { fail("banner missing at click beat"); return }
        log("banner click")
        w.alphaValue = 0.85
        await settle(0.12)
        var out = w.frame; out.origin.x += 360 + 16
        NSAnimationContext.beginGrouping()
        NSAnimationContext.current.duration = 0.24
        NSAnimationContext.current.timingFunction = CAMediaTimingFunction(name: .easeIn)
        w.animator().setFrame(out, display: true)
        w.animator().alphaValue = 0
        NSAnimationContext.endGrouping()
        pageWindow?.orderFront(nil)
        demoWebView?.evaluateJavaScript("""
        (function(){var b=document.getElementById('badge'); if(!b) return;
        b.classList.remove('bump'); void b.offsetWidth; b.classList.add('bump');
        b.style.transition='box-shadow 300ms'; b.style.boxShadow='0 0 0 8px rgba(229,72,77,.5)';
        setTimeout(function(){b.style.boxShadow='0 0 0 0 rgba(229,72,77,0)';},700);})()
        """, completionHandler: nil)
        await settle(0.3)
        stage.removeChildWindow(w)
        w.orderOut(nil)
        bannerWindow = nil
    }

    // MARK: Script

    private func run() async {
        guard let d = delegate else { return }
        DemoMode.onNotify = { [weak self] title, subtitle, body in
            guard let self else { return }
            self.notified = (title, subtitle, body)
            self.log("service notification: title=\"\(title)\" subtitle=\"\(subtitle)\" body=\"\(body)\"")
            self.showBanner(title: title, subtitle: subtitle, body: body)
        }

        buildStage(d)
        let safariTask = Task { @MainActor in await self.openSafariTab() }

        await until(0.3)
        let recStart = elapsed()
        startRecording()

        await until(1.5)
        logFrame("stage", stage?.frame)
        logFrame("pageWindow", pageWindow?.frame)
        logFrame("markButton", markButton.flatMap { screenRect(of: $0) })
        await safariTask.value
        await verifySafariTab()

        await until(4)
        log("open popover (anchored to staged mark)")
        stage?.makeKey()
        if let b = markButton { d.showPopover(anchoredTo: b) } else { fail("markButton missing") }
        await settle(3)
        d.closePopover()

        await until(7.5)
        log("show Add Watcher")
        d.showAddWatcher()
        await settle(0.3)
        var editor: NSWindow?
        if let w = d.demoAddWatcherWindow {
            editor = w
            let h = min(w.frame.height, 820)
            stage?.addChildWindow(w, ordered: .above); w.level = .floating
            w.setFrame(screenFrame(940, 60, 480, h), display: true)
            w.makeKeyAndOrderFront(nil)
            logFrame("add watcher window", w.frame)
        } else { fail("add watcher window missing") }
        await settle(1.7)

        if let model = ScreenshotMode.pickerModel {
            await editorSteps(model)
        } else { fail("pickerModel not set; skipping editor steps") }

        await tail(d, editor: editor)
        await finishRecording(startedAt: recStart)
    }

    private func editorSteps(_ model: ElementPickerModel) async {
        await until(10)
        log("locate tab")
        model.locate()
        if await poll(6, { if case .found = model.tab { return true } else { return model.scannedTitle != nil } }) {
            log("tab found: \(model.scannedTitle ?? "?")")
        } else { fail("locate timed out (tab=\(model.tab))") }
        await settle(2)

        await until(13)
        log("scan page")
        model.scan()
        if await poll(8, { !model.candidates.isEmpty }) {
            log("scan found \(model.candidates.count) candidates: \(model.candidates.map { "\($0.strategy.rawValue):\($0.selector)" })")
        } else { fail("scan produced no candidates (status=\(model.statusLine ?? "nil"))") }
        await settle(3)

        await until(18)
        if let c = model.candidates.first(where: { $0.strategy == .badgeText })
            ?? model.candidates.first(where: { $0.selector.localizedCaseInsensitiveContains("badge") })
            ?? model.candidates.first {
            log("pick candidate \(c.strategy.rawValue) \(c.selector) value=\(c.value ?? "nil")")
            model.useCandidate(c)
            if model.pendingChoice != nil,
               let ch = model.choices.first(where: { $0.recommended }) ?? model.choices.first {
                log("choose strategy \(ch.id.rawValue)")
                model.chooseStrategy(ch.id)
            }
            if await poll(6, { model.step == .confirm || model.diagnosisSummary != nil }) {
                log("confirm step reached: \(model.diagnosisSummary ?? "no diagnosis yet")")
            } else { fail("confirm step not reached (step=\(model.step))") }
        } else { fail("no candidate to pick") }
        await settle(3)
    }

    /// Save, popover, bump, check, banner, click.
    private func tail(_ d: AppDelegate, editor: NSWindow?) async {
        await until(24)
        log("save watcher")
        if let hook = DemoMode.saveHook { hook() } else { fail("saveHook not set") }
        if let editor { stage?.removeChildWindow(editor); editor.close(); log("add watcher window closed") }
        NSApp.activate(ignoringOtherApps: true); stage?.orderFrontRegardless()
        stage?.makeKeyAndOrderFront(nil)
        let pageURL = DemoMode.pageURL
        let saved: () -> Watcher? = {
            d.demoStore.watchers.first(where: { $0.name == "Rive Community bell" })
                ?? d.demoStore.watchers.first(where: { $0.url == pageURL })
        }
        _ = await poll(2, { saved() != nil })
        // First conclusive reading is a baseline, never an alert: take it now (page still reads 3).
        if let w = saved() { log("baseline check"); d.demoWatcherService.checkNow(w) } else { fail("new watcher not in store after save") }
        await settle(1.5)
        log("popover with new row")
        if let b = markButton { d.showPopover(anchoredTo: b) }
        await settle(3)
        d.closePopover()

        await until(30)
        log("bump page (real Safari tab + staged web view)")
        if let id = safariWinID {
            let (_, err) = await Self.osa("tell application \"Safari\" to do JavaScript \"window.bump()\" in current tab of window id \(id)")
            if let err { fail("bump in Safari: \(err)") }
        }
        demoWebView?.evaluateJavaScript("window.bump()", completionHandler: nil)
        await settle(0.3)
        demoWebView?.evaluateJavaScript("document.title") { [weak self] res, _ in
            Task { @MainActor in self?.chrome?.tabTitle = (res as? String) ?? "(4) Feed \u{2014} Community" }
        }

        await until(32)
        notified = nil
        if let w = saved() {
            log("check now (baseline was \(w.lastValue ?? "nil"))")
            d.demoWatcherService.checkNow(w)
        } else { fail("new watcher missing at check time") }
        if await poll(5, { self.notified != nil }) == false { fail("notification hook did not fire within 5 s") }

        await until(37)
        await clickBanner()
        await until(41)
    }

    private func finish() async {
        if env["WW_DEMO_CLOSE_TAB"] != "0", let id = safariWinID {
            let (_, err) = await Self.osa("tell application \"Safari\" to close window id \(id)")
            if let err { fail("close Safari tab: \(err)") } else { log("closed demo Safari window") }
        }
        DemoMode.onNotify = nil
        if let s = stage { pageWindow.map { s.removeChildWindow($0) }; bannerWindow?.close(); pageWindow?.close(); s.close() }
        log(failures == 0 ? "done, no failures" : "done, \(failures) failure(s)")
        if let dir = DemoMode.outputDir {
            let url = URL(fileURLWithPath: dir, isDirectory: true)
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            try? logLines.joined(separator: "\n").appending("\n").write(to: url.appendingPathComponent("demo.log"), atomically: true, encoding: .utf8)
        }
        ScreenshotMode.cleanUp()
        NSCursor.unhide(); NSApp.terminate(nil)
    }

    // MARK: Helpers

    private func elapsed() -> Double { Date().timeIntervalSince(t0) }

    private func log(_ message: String) {
        let line = String(format: "[t=%5.1f] ", elapsed()) + message
        logLines.append(line)
        print("demo: \(line)")
    }

    private func fail(_ message: String) {
        failures += 1
        log("FAIL " + message)
    }

    /// Sleep until `t` seconds after launch; returns immediately when already past.
    private func until(_ t: Double) async {
        let remaining = t - elapsed()
        if remaining > 0 { await settle(remaining) }
    }

    private func settle(_ seconds: Double) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    private func poll(_ timeout: Double, _ condition: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            await settle(0.2)
        }
        return condition()
    }
}
#endif
