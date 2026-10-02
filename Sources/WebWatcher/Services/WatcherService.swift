import Foundation
import Combine
import AppKit

/// Orchestrates periodic checking of all watchers.
@MainActor
class WatcherService: ObservableObject {
    @Published var isRunning = false
    @Published var lastCheckTime: Date?

    private var store: WatcherStore
    private var timers: [UUID: Timer] = [:]
    private var inFlightWatcherIDs: Set<UUID> = []
    private let scraper = SafariScraper.shared

    /// Failures are not counted during this window. Timers don't fire while the machine
    /// sleeps, so on wake every watcher fires at once into a Safari that is still
    /// restoring its tabs — without a grace period that burst reads as "everything broke".
    private var graceUntil: Date

    private let autoOpenCooldown: TimeInterval = 600
    private let autoOpenDailyLimit = 3
    private let escalateAfterFailures = 3
    private let escalateAfterInterval: TimeInterval = 600
    private let renotifyInterval: TimeInterval = 6 * 3600

    init(store: WatcherStore) {
        self.store = store
        self.graceUntil = Date().addingTimeInterval(120)
        registerForSleepWake()
    }

    // MARK: - Lifecycle

    func start() {
        guard !isRunning else { return }
        isRunning = true

        Task { @MainActor [weak self] in
            guard let self else { return }

            let safariAllowed = BrowserNavigationService.shared.ensureSafariAutomationPermissionForMonitoring()
            guard safariAllowed else {
                self.isRunning = false
                print("WatcherService start paused: Safari automation permission not granted")
                return
            }

            _ = await NotificationService.shared.requestPermission()

            for watcher in self.store.watchers where watcher.isEnabled {
                self.startTimer(for: watcher)
            }

            print("WatcherService started with \(self.timers.count) active watchers")
        }
    }

    func stop() {
        isRunning = false
        for (_, timer) in timers { timer.invalidate() }
        timers.removeAll()
        print("WatcherService stopped")
    }

    func restart() {
        stop()
        start()
    }

    /// User-initiated check. Bypasses backoff — if someone asks, we look.
    func checkNow(_ watcher: Watcher) {
        Task { await performCheck(watcher, userInitiated: true) }
    }

    func checkAllNow() {
        for watcher in store.watchers where watcher.isEnabled {
            checkNow(watcher)
        }
    }

    func watcherUpdated(_ watcher: Watcher) {
        timers[watcher.id]?.invalidate()
        timers.removeValue(forKey: watcher.id)
        inFlightWatcherIDs.remove(watcher.id)

        if watcher.isEnabled && isRunning {
            startTimer(for: watcher)
        }
    }

    func watcherDeleted(_ watcherId: UUID) {
        timers[watcherId]?.invalidate()
        timers.removeValue(forKey: watcherId)
        inFlightWatcherIDs.remove(watcherId)
    }

    // MARK: - Sleep / wake

    private func registerForSleepWake() {
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.graceUntil = Date().addingTimeInterval(90)
                print("Woke from sleep — suppressing failure accounting for 90s")
            }
        }
    }

    private var inGracePeriod: Bool { Date() < graceUntil }

    // MARK: - Scheduling

    private func startTimer(for watcher: Watcher) {
        Task { await performCheck(watcher) }

        let timer = Timer.scheduledTimer(
            withTimeInterval: TimeInterval(watcher.interval.rawValue),
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let updated = self.store.watchers.first(where: { $0.id == watcher.id }) {
                    await self.performCheck(updated)
                }
            }
        }

        timers[watcher.id] = timer
        RunLoop.current.add(timer, forMode: .common)
    }

    // MARK: - Checking

    private func performCheck(_ watcher: Watcher, userInitiated: Bool = false) async {
        guard !inFlightWatcherIDs.contains(watcher.id) else { return }

        if !userInitiated, let until = watcher.backoffUntil, Date() < until {
            return
        }

        inFlightWatcherIDs.insert(watcher.id)
        defer { inFlightWatcherIDs.remove(watcher.id) }

        let profile = watcher.profileId.flatMap { SiteProfileStore.shared.profile(id: $0) }
        var result = await scraper.check(watcher, profile: profile)

        // Recovery is reason-specific:
        //  - a suspended tab (F1) is reloaded in place, throttled independently of
        //    auto-open — a reload of an existing tab is not opening a new one;
        //  - a missing tab is opened, as before;
        //  - a tab that answered from the wrong page is opened only when it is
        //    actually off the watcher's canonical URL. Some sites render whole
        //    sections without the global nav, so a host match can land on a page
        //    that cannot answer the question — but opening a duplicate of the SAME
        //    page the user is already looking at helps nobody; the recipe or a
        //    sign-in wall is the real problem there, and escalation covers it.
        switch result.observation.cannotReason {
        case .tabSuspended:
            if canReload(watcher) {
                store.markReloadAttempt(for: watcher.id)
                if await scraper.reloadTab(for: watcher, profile: profile) {
                    try? await Task.sleep(nanoseconds: 4_000_000_000)
                    if let refreshed = store.watchers.first(where: { $0.id == watcher.id }) {
                        result = await scraper.check(refreshed, profile: profile)
                    }
                }
            }

        case .noTab:
            if watcher.autoOpenEnabled, shouldAutoOpen(watcher) {
                result = await autoOpenAndRecheck(watcher, profile: profile) ?? result
            }

        case .anchorMissing:
            let canonical = ProbeScript.canonicalURL(for: watcher, profile: profile)
            let onCanonical = (result.report.matchedURL ?? "").hasPrefix(canonical) || canonical.isEmpty
            if !onCanonical, watcher.autoOpenEnabled, shouldAutoOpen(watcher) {
                result = await autoOpenAndRecheck(watcher, profile: profile) ?? result
            }

        default:
            break
        }

        lastCheckTime = result.timestamp
        apply(result: result, for: watcher, profile: profile)
    }

    /// Opens the watcher's page as a background tab and re-checks it, giving the page
    /// time to load before re-reading rather than reporting a failure we just set out
    /// to fix. Returns nil (leave the original result as-is) when opening failed.
    private func autoOpenAndRecheck(_ watcher: Watcher, profile: SiteProfile?) async -> WatchResult? {
        guard await scraper.openBackgroundTab(for: watcher, profile: profile) else { return nil }
        store.markAutoOpened(for: watcher.id)
        try? await Task.sleep(nanoseconds: 4_000_000_000)
        guard let refreshed = store.watchers.first(where: { $0.id == watcher.id }) else { return nil }
        return await scraper.check(refreshed, profile: profile)
    }

    private func shouldAutoOpen(_ watcher: Watcher) -> Bool {
        if let last = watcher.lastAutoOpen, Date().timeIntervalSince(last) < autoOpenCooldown {
            return false
        }
        if let day = watcher.autoOpenDay, Calendar.current.isDateInToday(day),
           watcher.autoOpensToday >= autoOpenDailyLimit {
            return false
        }
        return true
    }

    /// Throttles `.tabSuspended` reloads independently of `lastAutoOpen` (a reload
    /// of an existing tab is not opening a new one).
    private func canReload(_ watcher: Watcher) -> Bool {
        guard let last = watcher.lastReloadAttempt else { return true }
        return Date().timeIntervalSince(last) >= 300
    }

    private func apply(result: WatchResult, for watcher: Watcher, profile: SiteProfile?) {
        switch result.observation {
        case .cannot(let reason, let detail):
            guard !inGracePeriod else {
                print("[\(watcher.name)] \(reason.rawValue) during grace period — not counted")
                return
            }
            store.recordBlocked(
                for: watcher.id,
                reason: reason,
                detail: detail,
                interval: TimeInterval(watcher.interval.rawValue)
            )
            maybeEscalate(watcherId: watcher.id, reason: reason)
            print("[\(watcher.name)] cannot observe: \(reason.rawValue) \(detail ?? "")")

        case .zero, .value:
            guard let newValue = result.observation.observedValue else { return }
            let previous = store.recordObservation(for: watcher.id, value: newValue)
            guard let current = store.watchers.first(where: { $0.id == watcher.id }) else { return }

            if shouldNotify(watchType: watcher.watchType, old: previous, new: newValue) {
                NotificationService.shared.notify(
                    watcher: current,
                    newValue: newValue,
                    oldValue: previous
                )
            }
            print("[\(watcher.name)] \(newValue)")
        }
    }

    /// Change detection, in one place, as a pure function so it can be tested.
    nonisolated static func shouldNotifyValue(watchType: WatchType, old: String?, new: String) -> Bool {
        switch watchType {
        case .badgeNumber:
            guard let newBadge = BadgeValue.parse(new) else { return false }
            let oldBadge = old.flatMap { BadgeValue.parse($0) }
            return BadgeValue.shouldNotify(old: oldBadge, new: newBadge)

        case .elementCount:
            guard let oldN = old.flatMap({ Int($0) }), let newN = Int(new) else { return false }
            return newN > oldN

        case .elementExists:
            return new == "true" && old != "true"

        case .elementDisappears:
            return new == "false" && old == "true"

        case .textChange:
            guard let old else { return false }
            return old != new

        case .subtreeChange:
            // First conclusive reading is a baseline, never an alert — same rule as
            // textChange, just spelled out per §3.1 (`old != nil && old != new`).
            guard let old else { return false }
            return old != new
        }
    }

    private func shouldNotify(watchType: WatchType, old: String?, new: String) -> Bool {
        Self.shouldNotifyValue(watchType: watchType, old: old, new: new)
    }

    /// Tell the user once when a watcher goes properly broken, with a remedy —
    /// the failure mode this replaces was thousands of silent errors.
    private func maybeEscalate(watcherId: UUID, reason: CannotReason) {
        guard reason.isWorthEscalating,
              let w = store.watchers.first(where: { $0.id == watcherId }),
              w.consecutiveCannotObserve >= escalateAfterFailures else { return }

        // Require the problem to have persisted, not just repeated quickly.
        let elapsed = Double(w.consecutiveCannotObserve) * Double(w.interval.rawValue)
        guard elapsed >= escalateAfterInterval else { return }

        if let notified = w.healthNotifiedAt, Date().timeIntervalSince(notified) < renotifyInterval {
            return
        }

        NotificationService.shared.notifyWatcherBroken(watcher: w, reason: reason)
        store.markHealthNotified(for: watcherId)
    }
}
