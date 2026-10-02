import XCTest
@testable import WebWatcher

@MainActor
final class EmailWatcherUnreadTests: XCTestCase {

    private func makeStore() -> EmailWatcherStore {
        EmailWatcherStore(fileURL: FileManager.default.temporaryDirectory
            .appendingPathComponent("ew-unread-\(UUID().uuidString).json"))
    }

    private func message(_ id: String, thread: String = "t", subject: String = "S", date: Date = Date()) -> GmailMessage {
        GmailMessage(accountId: UUID(), messageId: id, threadId: thread, from: "A <a@b.com>",
                     subject: subject, date: date, labelIds: [], snippet: "")
    }

    func testDecodesLegacyJSONWithoutNewKeys() throws {
        let id = UUID(), acc = UUID()
        let json = """
        [{"id":"\(id)","name":"N","accountId":"\(acc)","senders":["a@b.com"],"isEnabled":true,"notificationSound":true}]
        """
        let w = try JSONDecoder().decode([EmailWatcher].self, from: Data(json.utf8))[0]
        XCTAssertEqual(w.unreadMessageIds, [])
        XCTAssertEqual(w.unreadCount, 0)
        XCTAssertEqual(w.recentSubjects, [])
        XCTAssertNil(w.customIconPath)
        XCTAssertNil(w.notificationTitle)
        XCTAssertNil(w.notificationBodyTemplate)
    }

    func testRoundTripNewFields() throws {
        var w = EmailWatcher(accountId: UUID(), senders: ["a@b.com"])
        w.customIconPath = "/x.png"
        w.notificationTitle = "T"
        w.notificationBodyTemplate = "B"
        w.unreadMessageIds = ["1", "2"]
        w.unreadCount = 2
        w.recentSubjects = ["s2", "s1"]
        let d = try JSONDecoder().decode(EmailWatcher.self, from: JSONEncoder().encode(w))
        XCTAssertEqual(d, w)
    }

    func testRecordUnreadReturnsOnlyNewIdsAndUpdatesState() {
        let store = makeStore()
        let w = EmailWatcher(accountId: UUID(), senders: ["a@b.com"])
        store.add(w)
        let first = store.recordUnread(for: w.id, ids: ["1", "2"], newest: message("2", thread: "t2", subject: "Two"), subjects: ["Two", "One"])
        XCTAssertEqual(first, ["1", "2"])
        let second = store.recordUnread(for: w.id, ids: ["3", "2"], newest: message("3", thread: "t3", subject: "Three"), subjects: ["Three", "Two", "One", "Zero"])
        XCTAssertEqual(second, ["3"])
        let got = store.watchers[0]
        XCTAssertEqual(got.unreadMessageIds, ["3", "2"])
        XCTAssertEqual(got.unreadCount, 2)
        XCTAssertEqual(got.recentSubjects, ["Three", "Two", "One"])
        XCTAssertEqual(got.lastMatchMessageId, "3")
        XCTAssertEqual(got.lastMatchThreadId, "t3")
        XCTAssertEqual(got.lastMatchSubject, "Three")
    }

    func testRecordUnreadDecreaseReturnsNothingAndKeepsLastMatchWithoutNewest() {
        let store = makeStore()
        let w = EmailWatcher(accountId: UUID(), senders: ["a@b.com"])
        store.add(w)
        store.recordUnread(for: w.id, ids: ["1", "2"], newest: message("2", subject: "Two"), subjects: ["Two"])
        let r = store.recordUnread(for: w.id, ids: ["1"], newest: nil, subjects: ["One"])
        XCTAssertEqual(r, [])
        XCTAssertEqual(store.watchers[0].unreadCount, 1)
        XCTAssertEqual(store.watchers[0].lastMatchSubject, "Two")
    }

    func testRecordUnreadUnknownWatcherReturnsEmpty() {
        XCTAssertEqual(makeStore().recordUnread(for: UUID(), ids: ["1"], newest: nil, subjects: []), [])
    }

    func testClearUnread() {
        let store = makeStore()
        let w = EmailWatcher(accountId: UUID(), senders: ["a@b.com"])
        store.add(w)
        store.recordUnread(for: w.id, ids: ["1"], newest: message("1"), subjects: ["S"])
        store.clearUnread(for: w.id)
        XCTAssertEqual(store.watchers[0].unreadMessageIds, [])
        XCTAssertEqual(store.watchers[0].unreadCount, 0)
    }

    func testStatusDisplay() {
        var w = EmailWatcher(accountId: UUID(), senders: ["a@b.com"])
        XCTAssertEqual(w.statusDisplay, "No email yet")
        let when = Date()
        w.lastMatchDate = when
        XCTAssertEqual(w.statusDisplay, "No unread")
        w.unreadCount = 3
        XCTAssertEqual(w.statusDisplay, "3 unread · latest \(EmailTimeFormatter.received(when))")
    }

    func testOpenURLRules() {
        var w = EmailWatcher(accountId: UUID(), senders: ["a@b.com", "@c.com"])
        w.lastMatchThreadId = "th"
        XCTAssertEqual(w.openURL(accountIndex: 2)?.absoluteString, "https://mail.google.com/mail/u/2/#inbox")
        w.unreadCount = 1
        XCTAssertEqual(w.openURL(accountIndex: 2)?.absoluteString, "https://mail.google.com/mail/u/2/#inbox/th")
        w.unreadCount = 2
        XCTAssertEqual(w.openURL(accountIndex: 2), SenderMatcher.gmailSearchURL(accountIndex: 2, senders: w.senders))
        w.lastMatchThreadId = nil
        w.unreadCount = 1
        XCTAssertEqual(w.openURL(accountIndex: 0)?.absoluteString, "https://mail.google.com/mail/u/0/#inbox")
    }

    func testGmailSearchURLEncoding() {
        let url = SenderMatcher.gmailSearchURL(accountIndex: 1, senders: ["a@b.com", "@c.com"])
        XCTAssertEqual(url?.absoluteString,
            "https://mail.google.com/mail/u/1/#search/from%3A%28a%40b.com%20OR%20c.com%29%20is%3Aunread%20in%3Ainbox")
        XCTAssertNil(SenderMatcher.gmailSearchURL(accountIndex: 0, senders: []))
    }
}
