import Foundation
import Combine

/// Manages the collection of watchers and persists them
@MainActor
class WatcherStore: ObservableObject {
    @Published var watchers: [Watcher] = []

    private let saveKey = "WebWatcher.watchers"
    private let fileURL: URL

    init() {
        // Store in Application Support
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("WebWatcher", isDirectory: true)

        // Create directory if needed
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)

        self.fileURL = appFolder.appendingPathComponent("watchers.json")
        load()
    }

    func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            // Create sample watcher on first run
            watchers = [createSampleWatcher()]
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            watchers = try JSONDecoder().decode([Watcher].self, from: data)
        } catch {
            print("Failed to load watchers: \(error)")
            watchers = []
        }
    }

    func save() {
        do {
            let data = try JSONEncoder().encode(watchers)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to save watchers: \(error)")
        }
    }

    func add(_ watcher: Watcher) {
        watchers.append(watcher)
        save()
    }

    func update(_ watcher: Watcher) {
        if let index = watchers.firstIndex(where: { $0.id == watcher.id }) {
            watchers[index] = watcher
            save()
        }
    }

    func delete(_ watcher: Watcher) {
        watchers.removeAll { $0.id == watcher.id }
        save()
    }

    func delete(at offsets: IndexSet) {
        watchers.remove(atOffsets: offsets)
        save()
    }

    func updateResult(for watcherId: UUID, value: String?, error: String?) {
        if let index = watchers.firstIndex(where: { $0.id == watcherId }) {
            watchers[index].lastValue = value
            watchers[index].lastCheck = Date()
            watchers[index].lastError = error
            if error != nil {
                watchers[index].consecutiveErrors += 1
            } else {
                watchers[index].consecutiveErrors = 0
            }
            save()
        }
    }

    private func createSampleWatcher() -> Watcher {
        Watcher(
            name: "Contra Messages",
            url: "https://contra.com/messages",
            selector: "[data-sentry-component='Messages'] [class*='badge'], [aria-label='Go to Messages'] [class*='count']",
            watchType: .badgeNumber,
            interval: .seconds30,
            isEnabled: false, // Disabled by default
            notificationSound: true,
            actionURL: "https://contra.com/messages"
        )
    }
}
