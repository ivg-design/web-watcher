import Foundation
import Combine

/// Manages the collection of watchers and persists them.
@MainActor
class WatcherStore: ObservableObject {
    @Published var watchers: [Watcher] = []

    /// Set when the config file exists but could not be decoded. The old code replaced
    /// the list with `[]` and the next save overwrote the user's only copy; now the file
    /// is left alone and quarantined, and this flag surfaces the problem in the UI.
    @Published private(set) var loadFailure: String?

    private let fileURL: URL
    private let backupFolder: URL
    private var saveWorkItem: DispatchWorkItem?

    /// Keeps writes off the hot path: results land every interval, and the old code
    /// re-encoded the entire file on each one.
    private let saveDebounce: TimeInterval = 3.0
    private let maxBackups = 25

    /// `appFolder` nil → Application Support/WebWatcher; a custom directory lets tests
    /// point the whole store (data file AND its backups) at a temp folder instead of the
    /// user's real Application Support folder.
    init(appFolder: URL? = nil) {
        let folder: URL
        if let appFolder {
            folder = appFolder
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            folder = appSupport.appendingPathComponent("WebWatcher", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        self.fileURL = folder.appendingPathComponent("watchers.json")
        self.backupFolder = folder.appendingPathComponent("backups", isDirectory: true)
        try? FileManager.default.createDirectory(at: backupFolder, withIntermediateDirectories: true)

        load()
        backupCurrentConfig()
    }

    // MARK: - Persistence

    func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            watchers = [createSampleWatcher()]
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            watchers = try JSONDecoder().decode([Watcher].self, from: data)
            loadFailure = nil
        } catch {
            // Do NOT clear `watchers` and do NOT write. An unreadable file is recoverable;
            // an overwritten one is not.
            print("Failed to load watchers: \(error)")
            loadFailure = error.localizedDescription
            quarantineUnreadableConfig()
        }
    }

    /// Copy the config aside at launch, keeping the most recent few.
    ///
    /// Skips the copy when the newest backup is already byte-identical. Without that,
    /// a run of app restarts writes a fresh backup each time and the rotation quietly
    /// discards the older, genuinely different history — which is the one case backups
    /// exist for.
    private func backupCurrentConfig() {
        guard loadFailure == nil,
              FileManager.default.fileExists(atPath: fileURL.path),
              let current = try? Data(contentsOf: fileURL) else { return }

        if let newest = availableBackups().first,
           let previous = try? Data(contentsOf: newest),
           previous == current {
            return
        }

        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let dest = backupFolder.appendingPathComponent("watchers-\(stamp).json")
        try? current.write(to: dest, options: .atomic)
        pruneBackups()
    }

    private func pruneBackups() {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: backupFolder, includingPropertiesForKeys: [.creationDateKey]
        ) else { return }

        let sorted = files
            .filter { $0.lastPathComponent.hasPrefix("watchers-") }
            .sorted { a, b in
                let da = (try? a.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                let db = (try? b.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                return da > db
            }
        for old in sorted.dropFirst(maxBackups) {
            try? FileManager.default.removeItem(at: old)
        }
    }

    private func quarantineUnreadableConfig() {
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let dest = backupFolder.appendingPathComponent("watchers-unreadable-\(stamp).json")
        try? FileManager.default.copyItem(at: fileURL, to: dest)
    }

    /// Backups available to restore, newest first.
    func availableBackups() -> [URL] {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: backupFolder, includingPropertiesForKeys: [.creationDateKey]
        ) else { return [] }
        return files
            .filter { $0.pathExtension == "json" }
            .sorted { a, b in
                let da = (try? a.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                let db = (try? b.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                return da > db
            }
    }

    @discardableResult
    func restoreBackup(_ url: URL) -> Bool {
        guard let data = try? Data(contentsOf: url),
              let restored = try? JSONDecoder().decode([Watcher].self, from: data) else { return false }
        watchers = restored
        loadFailure = nil
        saveNow()
        return true
    }

    /// Coalesced save. Use `saveNow()` for user-initiated edits that must not be lost.
    func save() {
        saveWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in self?.saveNow() }
        }
        saveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + saveDebounce, execute: work)
    }

    func saveNow() {
        saveWorkItem?.cancel()
        saveWorkItem = nil
        guard loadFailure == nil else {
            print("Refusing to save over an unreadable config")
            return
        }
        do {
            let data = try JSONEncoder().encode(watchers)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to save watchers: \(error)")
        }
    }

    // MARK: - Mutations

    func add(_ watcher: Watcher) {
        watchers.append(watcher)
        saveNow()
    }

    func update(_ watcher: Watcher) {
        if let index = watchers.firstIndex(where: { $0.id == watcher.id }) {
            watchers[index] = watcher
            saveNow()
        }
    }

    func delete(_ watcher: Watcher) {
        watchers.removeAll { $0.id == watcher.id }
        saveNow()
    }

    func delete(at offsets: IndexSet) {
        watchers.remove(atOffsets: offsets)
        saveNow()
    }

    // MARK: - Results

    /// Record a conclusive reading. Returns the previous conclusive value so the caller
    /// can decide whether to notify.
    @discardableResult
    func recordObservation(for watcherId: UUID, value: String) -> String? {
        guard let index = watchers.firstIndex(where: { $0.id == watcherId }) else { return nil }
        var w = watchers[index]
        let previous = w.lastConclusiveValue

        // G2: a real change (not just a re-check that landed the same reading) advances
        // the "Changed <when>" timestamp subtreeChange's statusDisplay reads.
        if previous != nil && previous != value {
            w.lastChangeDate = Date()
        }

        w.lastValue = value
        w.lastConclusiveValue = value
        w.everMatched = true
        w.lastCheck = Date()
        w.lastError = nil
        w.lastCannotReason = nil
        w.consecutiveErrors = 0
        w.consecutiveCannotObserve = 0
        w.backoffUntil = nil
        w.healthNotifiedAt = nil

        watchers[index] = w
        save()
        return previous
    }

    /// Record a failure to observe. Critically, this never touches `lastConclusiveValue`,
    /// so a blocked stretch can neither fabricate a change nor erase the baseline.
    func recordBlocked(for watcherId: UUID, reason: CannotReason, detail: String?, interval: TimeInterval) {
        guard let index = watchers.firstIndex(where: { $0.id == watcherId }) else { return }
        var w = watchers[index]

        w.lastCheck = Date()
        w.lastCannotReason = reason.rawValue
        w.lastError = detail ?? reason.shortStatus
        w.consecutiveCannotObserve += 1
        w.consecutiveErrors += 1

        // Exponential backoff, capped at 30 minutes, so a broken watcher stops hammering.
        let factor = pow(reason.backoffFactor, Double(min(w.consecutiveCannotObserve, 6)))
        let delay = min(interval * factor, 1800)
        w.backoffUntil = Date().addingTimeInterval(delay)

        watchers[index] = w
        save()
    }

    func markAutoOpened(for watcherId: UUID) {
        guard let index = watchers.firstIndex(where: { $0.id == watcherId }) else { return }
        var w = watchers[index]
        let cal = Calendar.current
        if let day = w.autoOpenDay, cal.isDateInToday(day) {
            w.autoOpensToday += 1
        } else {
            w.autoOpensToday = 1
            w.autoOpenDay = Date()
        }
        w.lastAutoOpen = Date()
        w.appOpenedTab = true
        watchers[index] = w
        save()
    }

    func markHealthNotified(for watcherId: UUID) {
        guard let index = watchers.firstIndex(where: { $0.id == watcherId }) else { return }
        watchers[index].healthNotifiedAt = Date()
        save()
    }

    /// Records that we just reloaded this watcher's tab to recover from `.tabSuspended`,
    /// so `WatcherService.canReload` can throttle repeated reloads independently of
    /// `lastAutoOpen` (a reload of an existing tab is not opening a new one).
    func markReloadAttempt(for watcherId: UUID) {
        guard let index = watchers.firstIndex(where: { $0.id == watcherId }) else { return }
        watchers[index].lastReloadAttempt = Date()
        save()
    }

    private func createSampleWatcher() -> Watcher {
        Watcher(
            name: "LinkedIn Notifications",
            url: "https://www.linkedin.com/",
            selector: "a[href*=\"/notifications/\"]",
            watchType: .badgeNumber,
            interval: .minutes2,
            isEnabled: false,
            notificationSound: true,
            actionURL: "https://www.linkedin.com/notifications/",
            anchorSelector: "a[href*=\"/notifications/\"]",
            profileId: "linkedin.notifications"
        )
    }
}
