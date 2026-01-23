import Foundation
import Combine

/// Orchestrates periodic checking of all watchers
@MainActor
class WatcherService: ObservableObject {
    @Published var isRunning = false
    @Published var lastCheckTime: Date?

    private var store: WatcherStore
    private var timers: [UUID: Timer] = [:]
    private let scraper = WebScraper()

    init(store: WatcherStore) {
        self.store = store
    }

    /// Start monitoring all enabled watchers
    func start() {
        guard !isRunning else { return }
        isRunning = true

        // Request notification permission
        Task {
            _ = await NotificationService.shared.requestPermission()
        }

        // Start timer for each enabled watcher
        for watcher in store.watchers where watcher.isEnabled {
            startTimer(for: watcher)
        }

        print("WatcherService started with \(timers.count) active watchers")
    }

    /// Stop all monitoring
    func stop() {
        isRunning = false
        for (_, timer) in timers {
            timer.invalidate()
        }
        timers.removeAll()
        print("WatcherService stopped")
    }

    /// Restart monitoring (call after watcher list changes)
    func restart() {
        stop()
        start()
    }

    /// Check a specific watcher immediately
    func checkNow(_ watcher: Watcher) {
        Task {
            await performCheck(watcher)
        }
    }

    /// Check all watchers immediately
    func checkAllNow() {
        for watcher in store.watchers where watcher.isEnabled {
            checkNow(watcher)
        }
    }

    /// Update timers when a watcher is modified
    func watcherUpdated(_ watcher: Watcher) {
        // Stop existing timer
        timers[watcher.id]?.invalidate()
        timers.removeValue(forKey: watcher.id)

        // Start new timer if enabled
        if watcher.isEnabled && isRunning {
            startTimer(for: watcher)
        }
    }

    /// Remove timer for deleted watcher
    func watcherDeleted(_ watcherId: UUID) {
        timers[watcherId]?.invalidate()
        timers.removeValue(forKey: watcherId)
    }

    // MARK: - Private

    private func startTimer(for watcher: Watcher) {
        // Perform initial check
        Task {
            await performCheck(watcher)
        }

        // Schedule periodic checks
        let timer = Timer.scheduledTimer(
            withTimeInterval: TimeInterval(watcher.interval.rawValue),
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                // Get fresh watcher data
                if let updatedWatcher = self.store.watchers.first(where: { $0.id == watcher.id }) {
                    await self.performCheck(updatedWatcher)
                }
            }
        }

        timers[watcher.id] = timer
        RunLoop.current.add(timer, forMode: .common)
    }

    private func performCheck(_ watcher: Watcher) async {
        print("Checking: \(watcher.name)")

        let result = await scraper.check(watcher)

        // Update store
        store.updateResult(for: result.watcherId, value: result.value, error: result.error)
        lastCheckTime = result.timestamp

        // Send notification if changed
        if result.hasChanged && result.error == nil {
            if let value = result.value {
                // Get the watcher again to have the old value
                if let currentWatcher = store.watchers.first(where: { $0.id == watcher.id }) {
                    let shouldNotify: Bool

                    switch watcher.watchType {
                    case .badgeNumber:
                        // Only notify if count increased
                        let oldCount = Int(watcher.lastValue ?? "0") ?? 0
                        let newCount = Int(value) ?? 0
                        shouldNotify = newCount > oldCount

                    case .elementDisappears:
                        // Only notify when element disappears (becomes false)
                        shouldNotify = value == "false" && watcher.lastValue == "true"

                    case .elementExists:
                        // Only notify when element appears (becomes true)
                        shouldNotify = value == "true" && watcher.lastValue != "true"

                    default:
                        shouldNotify = true
                    }

                    if shouldNotify {
                        NotificationService.shared.notify(
                            watcher: currentWatcher,
                            newValue: value,
                            oldValue: watcher.lastValue
                        )
                    }
                }
            }
        }

        print("Result for \(watcher.name): \(result.value ?? "nil"), error: \(result.error ?? "none")")
    }
}
