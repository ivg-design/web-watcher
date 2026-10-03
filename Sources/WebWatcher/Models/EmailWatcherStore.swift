import Foundation
import Combine

/// Persists Gmail sender watchers. Every mutation saves immediately (unlike `WatcherStore`'s
/// debounced save) — email watchers change far less often, on edits and on Gmail matches,
/// so there's no hot path to protect from over-saving.
@MainActor
final class EmailWatcherStore: ObservableObject {
    static let shared = ScreenshotMode.isActive
        ? EmailWatcherStore(fileURL: ScreenshotMode.scratchFile("email_watchers.json"))
        : EmailWatcherStore()

    @Published private(set) var watchers: [EmailWatcher] = []

    private let fileURL: URL

    /// `fileURL` nil → Application Support/WebWatcher/email_watchers.json; a custom URL lets
    /// tests point at a temp file instead of the user's real Application Support folder.
    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let appFolder = appSupport.appendingPathComponent("WebWatcher", isDirectory: true)
            try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
            self.fileURL = appFolder.appendingPathComponent("email_watchers.json")
        }
        load()
    }

    func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            watchers = []
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            watchers = try JSONDecoder().decode([EmailWatcher].self, from: data)
        } catch {
            // An unreadable file must not be treated as "no watchers" and then overwritten
            // by the next save — but unlike WatcherStore this type has no backup/quarantine
            // story yet, so the best available behaviour is: keep the in-memory list empty
            // and leave the file untouched until `save()` is explicitly called again.
            print("Failed to load email watchers: \(error)")
            watchers = []
        }
    }

    func save() {
        do {
            let data = try JSONEncoder().encode(watchers)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to save email watchers: \(error)")
        }
    }

    func add(_ w: EmailWatcher) {
        watchers.append(w)
        save()
    }

    func update(_ w: EmailWatcher) {
        guard let index = watchers.firstIndex(where: { $0.id == w.id }) else { return }
        watchers[index] = w
        save()
    }

    func delete(_ w: EmailWatcher) {
        watchers.removeAll { $0.id == w.id }
        save()
    }

    func deleteAll(for accountId: UUID) {
        watchers.removeAll { $0.accountId == accountId }
        save()
    }

    func watchers(for accountId: UUID) -> [EmailWatcher] {
        watchers.filter { $0.accountId == accountId }
    }

    /// Records a real match: sets the lastMatch* fields from `message`, bumps `matchCount`,
    /// and clears any previous error (a fresh match means polling is working again).
    func recordMatch(for id: UUID, message: GmailMessage) {
        guard let index = watchers.firstIndex(where: { $0.id == id }) else { return }
        watchers[index].lastMatchDate = message.date
        watchers[index].lastMatchFrom = message.from
        watchers[index].lastMatchSubject = message.subject
        watchers[index].lastMatchMessageId = message.messageId
        watchers[index].lastMatchThreadId = message.threadId
        watchers[index].matchCount += 1
        watchers[index].lastError = nil
        save()
    }

    /// Records the newest pre-existing message found when the watcher was created (G3),
    /// without counting it as a match — a baseline is history, not something that just
    /// happened. `message == nil` (no prior mail from these senders) leaves lastMatch* nil.
    func recordBaseline(for id: UUID, message: GmailMessage?) {
        guard let index = watchers.firstIndex(where: { $0.id == id }) else { return }
        if let message {
            watchers[index].lastMatchDate = message.date
            watchers[index].lastMatchFrom = message.from
            watchers[index].lastMatchSubject = message.subject
            watchers[index].lastMatchMessageId = message.messageId
            watchers[index].lastMatchThreadId = message.threadId
        }
        watchers[index].lastError = nil
        save()
    }

    func recordError(for id: UUID, _ error: String?) {
        guard let index = watchers.firstIndex(where: { $0.id == id }) else { return }
        watchers[index].lastError = error
        save()
    }

    /// Replaces the unread set. `newest` (when given) updates lastMatch* and `subjects`
    /// (newest first, capped at 3) replaces recentSubjects. Returns the ids that were not
    /// in the previous set, in the order given — the reason to notify.
    @discardableResult
    func recordUnread(for id: UUID, ids: [String], newest: GmailMessage?, subjects: [String]) -> [String] {
        guard let index = watchers.firstIndex(where: { $0.id == id }) else { return [] }
        let known = Set(watchers[index].unreadMessageIds)
        var seen = Set<String>()
        let unique = ids.filter { seen.insert($0).inserted }
        let fresh = unique.filter { !known.contains($0) }
        watchers[index].unreadMessageIds = unique
        watchers[index].unreadCount = unique.count
        watchers[index].recentSubjects = Array(subjects.prefix(3))
        if let newest {
            watchers[index].lastMatchDate = newest.date
            watchers[index].lastMatchFrom = newest.from
            watchers[index].lastMatchSubject = newest.subject
            watchers[index].lastMatchMessageId = newest.messageId
            watchers[index].lastMatchThreadId = newest.threadId
        }
        watchers[index].lastError = nil
        save()
        return fresh
    }

    func clearUnread(for id: UUID) {
        guard let index = watchers.firstIndex(where: { $0.id == id }) else { return }
        watchers[index].unreadMessageIds = []
        watchers[index].unreadCount = 0
        save()
    }
}
