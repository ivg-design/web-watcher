import XCTest
@testable import WebWatcher

/// Coverage for §3.1's `EmailWatcher` (Codable, statusDisplay, displayName, openURL) and
/// §3.2's `EmailWatcherStore`. The store is always constructed with a temp `fileURL` — never
/// the real Application Support folder.
@MainActor
final class EmailWatcherTests: XCTestCase {

    // MARK: - Codable

    func testRoundTripPreservesEveryField() throws {
        var w = EmailWatcher(name: "Invoices", accountId: UUID(), senders: ["a@b.com", "@c.com"])
        w.lastMatchFrom = "A <a@b.com>"
        w.lastMatchSubject = "Invoice #1"
        w.lastMatchMessageId = "msg1"
        w.lastMatchThreadId = "thread1"
        w.matchCount = 3
        w.lastError = "temporary"

        let data = try JSONEncoder().encode(w)
        let decoded = try JSONDecoder().decode(EmailWatcher.self, from: data)

        XCTAssertEqual(decoded.id, w.id)
        XCTAssertEqual(decoded.name, w.name)
        XCTAssertEqual(decoded.accountId, w.accountId)
        XCTAssertEqual(decoded.senders, w.senders)
        XCTAssertEqual(decoded.isEnabled, w.isEnabled)
        XCTAssertEqual(decoded.notificationSound, w.notificationSound)
        XCTAssertEqual(decoded.lastMatchFrom, w.lastMatchFrom)
        XCTAssertEqual(decoded.lastMatchSubject, w.lastMatchSubject)
        XCTAssertEqual(decoded.lastMatchMessageId, w.lastMatchMessageId)
        XCTAssertEqual(decoded.lastMatchThreadId, w.lastMatchThreadId)
        XCTAssertEqual(decoded.matchCount, w.matchCount)
        XCTAssertEqual(decoded.lastError, w.lastError)
    }

    func testLegacyJSONWithoutStateFieldsDecodesWithDefaults() throws {
        let accountId = UUID()
        let legacy = """
        {"id":"\(UUID().uuidString)","name":"Test","accountId":"\(accountId.uuidString)",
         "senders":["a@b.com"],"isEnabled":true,"notificationSound":true}
        """
        let w = try JSONDecoder().decode(EmailWatcher.self, from: Data(legacy.utf8))

        XCTAssertEqual(w.accountId, accountId)
        XCTAssertEqual(w.senders, ["a@b.com"])
        XCTAssertNil(w.lastMatchDate)
        XCTAssertNil(w.lastMatchFrom)
        XCTAssertNil(w.lastMatchSubject)
        XCTAssertNil(w.lastMatchMessageId)
        XCTAssertNil(w.lastMatchThreadId)
        XCTAssertEqual(w.matchCount, 0)
        XCTAssertNil(w.lastError)
    }

    // MARK: - statusDisplay

    func testStatusDisplayShowsErrorFirst() {
        var w = EmailWatcher(accountId: UUID())
        w.lastMatchDate = Date()
        w.lastError = "Reconnect required"
        XCTAssertEqual(w.statusDisplay, "Error: Reconnect required")
    }

    func testStatusDisplayWithNoMatchYet() {
        let w = EmailWatcher(accountId: UUID())
        XCTAssertEqual(w.statusDisplay, "No email yet")
    }

    func testStatusDisplayWithMatchAndSubject() {
        var w = EmailWatcher(accountId: UUID())
        let when = Date()
        w.lastMatchDate = when
        w.lastMatchSubject = "Hello"
        XCTAssertEqual(w.statusDisplay, "No unread")
    }

    func testStatusDisplayWithMatchAndNoSubject() {
        var w = EmailWatcher(accountId: UUID())
        let when = Date()
        w.lastMatchDate = when
        XCTAssertEqual(w.statusDisplay, "No unread")
    }

    // MARK: - displayName

    func testDisplayNameFallsBackToJoinedSendersWhenNameEmpty() {
        let w = EmailWatcher(accountId: UUID(), senders: ["a@b.com", "c@d.com"])
        XCTAssertEqual(w.displayName, "a@b.com, c@d.com")
    }

    func testDisplayNamePrefersExplicitName() {
        let w = EmailWatcher(name: "Invoices", accountId: UUID(), senders: ["a@b.com"])
        XCTAssertEqual(w.displayName, "Invoices")
    }

    // MARK: - openURL

    func testOpenURLWithUnreadMailIsTheFilteredSearchNotAThread() {
        var w = EmailWatcher(accountId: UUID(), senders: ["a@b.com"])
        w.lastMatchThreadId = "t1"
        w.unreadCount = 1
        XCTAssertEqual(w.openURL(accountIndex: 0), SenderMatcher.gmailSearchURL(accountIndex: 0, senders: ["a@b.com"]))
        XCTAssertFalse(w.openURL(accountIndex: 0)?.absoluteString.contains("t1") == true)
    }

    func testOpenURLFallsBackToInboxOnlyWithoutSenders() {
        let w = EmailWatcher(accountId: UUID())
        XCTAssertEqual(w.openURL(accountIndex: 1)?.absoluteString, "https://mail.google.com/mail/u/1/#inbox")
        let withSender = EmailWatcher(accountId: UUID(), senders: ["a@b.com"])
        XCTAssertEqual(withSender.openURL(accountIndex: 1)?.absoluteString, "https://mail.google.com/mail/u/1/#search/from%3A%28a%40b.com%29")
    }

    // MARK: - EmailWatcherStore

    private func tempFileURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("email_watchers_test_\(UUID().uuidString).json")
    }

    private func sampleMessage(accountId: UUID) -> GmailMessage {
        GmailMessage(
            accountId: accountId, messageId: "m1", threadId: "t1",
            from: "A <a@b.com>", subject: "Hi", date: Date(), labelIds: [], snippet: ""
        )
    }

    func testStoreAddUpdateDelete() {
        let url = tempFileURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let store = EmailWatcherStore(fileURL: url)

        let w = EmailWatcher(name: "n", accountId: UUID(), senders: ["a@b.com"])
        store.add(w)
        XCTAssertEqual(store.watchers.count, 1)

        var updated = w
        updated.name = "renamed"
        store.update(updated)
        XCTAssertEqual(store.watchers.first?.name, "renamed")

        store.delete(updated)
        XCTAssertTrue(store.watchers.isEmpty)
    }

    func testStoreWritesAtomicallyAndReloadsFromDisk() {
        let url = tempFileURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let w = EmailWatcher(name: "n", accountId: UUID(), senders: ["a@b.com"])

        let store1 = EmailWatcherStore(fileURL: url)
        store1.add(w)

        let store2 = EmailWatcherStore(fileURL: url)
        XCTAssertEqual(store2.watchers.count, 1)
        XCTAssertEqual(store2.watchers.first?.id, w.id)
    }

    func testDeleteAllForAccountOnlyRemovesThatAccountsWatchers() {
        let url = tempFileURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let store = EmailWatcherStore(fileURL: url)
        let accountId = UUID()
        store.add(EmailWatcher(accountId: accountId, senders: ["a@b.com"]))
        store.add(EmailWatcher(accountId: UUID(), senders: ["c@d.com"]))

        store.deleteAll(for: accountId)

        XCTAssertEqual(store.watchers.count, 1)
        XCTAssertNotEqual(store.watchers.first?.accountId, accountId)
    }

    func testWatchersForAccountFiltersByAccountId() {
        let url = tempFileURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let store = EmailWatcherStore(fileURL: url)
        let accountId = UUID()
        store.add(EmailWatcher(accountId: accountId, senders: ["a@b.com"]))
        store.add(EmailWatcher(accountId: UUID(), senders: ["c@d.com"]))

        XCTAssertEqual(store.watchers(for: accountId).count, 1)
    }

    func testRecordMatchIncrementsCountAndClearsError() {
        let url = tempFileURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let store = EmailWatcherStore(fileURL: url)
        var w = EmailWatcher(accountId: UUID(), senders: ["a@b.com"])
        w.lastError = "boom"
        store.add(w)

        store.recordMatch(for: w.id, message: sampleMessage(accountId: w.accountId))

        let updated = store.watchers.first!
        XCTAssertEqual(updated.matchCount, 1)
        XCTAssertNil(updated.lastError)
        XCTAssertEqual(updated.lastMatchMessageId, "m1")
        XCTAssertEqual(updated.lastMatchThreadId, "t1")
    }

    func testRecordBaselineDoesNotTouchMatchCount() {
        let url = tempFileURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let store = EmailWatcherStore(fileURL: url)
        var w = EmailWatcher(accountId: UUID(), senders: ["a@b.com"])
        w.matchCount = 5
        store.add(w)

        store.recordBaseline(for: w.id, message: sampleMessage(accountId: w.accountId))

        let updated = store.watchers.first!
        XCTAssertEqual(updated.matchCount, 5)
        XCTAssertEqual(updated.lastMatchMessageId, "m1")
    }

    func testRecordBaselineWithNilMessageLeavesLastMatchNil() {
        let url = tempFileURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let store = EmailWatcherStore(fileURL: url)
        let w = EmailWatcher(accountId: UUID(), senders: ["a@b.com"])
        store.add(w)

        store.recordBaseline(for: w.id, message: nil)

        XCTAssertNil(store.watchers.first?.lastMatchDate)
    }

    func testRecordErrorSetsLastError() {
        let url = tempFileURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let store = EmailWatcherStore(fileURL: url)
        let w = EmailWatcher(accountId: UUID(), senders: ["a@b.com"])
        store.add(w)

        store.recordError(for: w.id, "Reconnect required")

        XCTAssertEqual(store.watchers.first?.lastError, "Reconnect required")
    }
}
