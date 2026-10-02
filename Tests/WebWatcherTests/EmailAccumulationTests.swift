import XCTest
@testable import WebWatcher

/// Accumulated email-watcher notifications: content builder + live unread polling.
@MainActor
final class EmailAccumulationTests: XCTestCase {

    // MARK: - Fakes

    private final class FakeAPI: GmailAPIClient {
        var unreadIds: [String] = []
        var messagesById: [String: GmailMessageResponse] = [:]
        private(set) var fetchedIds: [String] = []

        func fetchProfile(accessToken: String) async throws -> GmailProfileResponse {
            GmailProfileResponse(emailAddress: "me@example.com", messagesTotal: nil, threadsTotal: nil, historyId: "1")
        }
        func fetchLabels(accessToken: String) async throws -> GmailLabelResponse { GmailLabelResponse(labels: []) }
        func fetchHistory(accessToken: String, startHistoryId: String, pageToken: String?) async throws -> GmailHistoryResponse {
            GmailHistoryResponse(history: nil, nextPageToken: nil, historyId: startHistoryId)
        }
        func fetchMessage(accessToken: String, messageId: String) async throws -> GmailMessageResponse {
            fetchedIds.append(messageId)
            guard let r = messagesById[messageId] else { throw APIError.requestFailed(404, "no fixture") }
            return r
        }
        func fetchUnreadCount(accessToken: String) async throws -> Int { 0 }
        func listMessages(accessToken: String, query: String, maxResults: Int) async throws -> GmailMessageListResponse {
            GmailMessageListResponse(messages: unreadIds.map { GmailMessageRef(id: $0, threadId: "t-\($0)") }, resultSizeEstimate: unreadIds.count)
        }
        func modifyMessage(accessToken: String, messageId: String, addLabels: [String]?, removeLabels: [String]?) async throws {}
        func trashMessage(accessToken: String, messageId: String) async throws {}
    }

    private final class FakeNotifier: GmailNotifying {
        private(set) var accumulated: [(watcher: EmailWatcher, newest: GmailMessage)] = []
        private(set) var cleared: [UUID] = []
        func notifyGmail(message: GmailMessage, account: GmailAccount) {}
        func notifyEmailWatcher(_ watcher: EmailWatcher, message: GmailMessage, account: GmailAccount) {}
        func notifyEmailWatcherAccumulated(_ watcher: EmailWatcher, newest: GmailMessage, account: GmailAccount) {
            accumulated.append((watcher, newest))
        }
        func clearEmailWatcherNotification(watcherId: UUID) { cleared.append(watcherId) }
    }

    // MARK: - Fixtures

    private func tempURL(_ name: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("\(name)_\(UUID().uuidString).json")
    }

    private func makeAccount(email: String = "me@example.com") -> GmailAccount {
        var a = GmailAccount(email: email, accountIndex: 2)
        a.accessToken = "access-token"
        a.refreshToken = "refresh-token"
        a.tokenExpiresAt = Date().addingTimeInterval(3600)
        return a
    }

    private func response(id: String, from: String, subject: String, millis: Int64) -> GmailMessageResponse {
        GmailMessageResponse(
            id: id, threadId: "t-\(id)", labelIds: ["INBOX", "UNREAD"], snippet: "",
            payload: GmailMessagePayload(
                headers: [GmailHeader(name: "From", value: from), GmailHeader(name: "Subject", value: subject), GmailHeader(name: "Date", value: "")],
                mimeType: nil, body: nil, parts: nil),
            internalDate: String(millis), historyId: nil)
    }

    private func message(from: String = "Acme Corp <a@acme.com>", subject: String = "Invoice", date: Date = Date()) -> GmailMessage {
        GmailMessage(accountId: UUID(), messageId: "m1", threadId: "t1", from: from, subject: subject, date: date, labelIds: [], snippet: "")
    }

    // MARK: - Content builder

    func testDefaultContentForSingleUnread() {
        var w = EmailWatcher(name: "Acme", accountId: UUID(), senders: ["a@acme.com"])
        w.unreadCount = 1
        w.recentSubjects = ["Invoice"]
        let now = Date()
        let c = NotificationService.emailWatcherAccumulatedContent(watcher: w, newest: message(date: now), account: makeAccount(), accountCount: 1, now: now)
        XCTAssertEqual(c.title, "Email from Acme Corp")
        XCTAssertEqual(c.subtitle, "Invoice")
        XCTAssertEqual(c.body, "• Invoice\nreceived \(EmailTimeFormatter.received(now, now: now))")
    }

    func testDefaultContentForThreeUnreadAndAccountSuffix() {
        var w = EmailWatcher(name: "Acme", accountId: UUID(), senders: ["a@acme.com"])
        w.unreadCount = 3
        w.recentSubjects = ["One", "Two", "Three"]
        let now = Date()
        let account = makeAccount(email: "me@example.com")
        let c = NotificationService.emailWatcherAccumulatedContent(watcher: w, newest: message(subject: "One", date: now), account: account, accountCount: 2, now: now)
        XCTAssertEqual(c.title, "3 new from Acme Corp")
        XCTAssertEqual(c.body, "• One\n• Two\n• Three\nreceived \(EmailTimeFormatter.received(now, now: now)) — me@example.com")
        let single = NotificationService.emailWatcherAccumulatedContent(watcher: w, newest: message(subject: "One", date: now), account: account, accountCount: 1, now: now)
        XCTAssertFalse(single.body.contains("me@example.com"))
    }

    func testCustomTemplatesExpandEveryPlaceholder() {
        var w = EmailWatcher(name: "Acme", accountId: UUID(), senders: ["a@acme.com"])
        w.unreadCount = 4
        w.notificationTitle = "{name}: {count} from {sender}"
        w.notificationBodyTemplate = "{subject} / {address} / {time} / {count} / {sender} / {name}"
        let now = Date()
        let c = NotificationService.emailWatcherAccumulatedContent(watcher: w, newest: message(date: now), account: makeAccount(), accountCount: 2, now: now)
        XCTAssertEqual(c.title, "Acme: 4 from Acme Corp")
        XCTAssertEqual(c.body, "Invoice / a@acme.com / \(EmailTimeFormatter.received(now, now: now)) / 4 / Acme Corp / Acme")
    }

    func testContentFallsBackToAddressWhenNoDisplayName() {
        var w = EmailWatcher(name: "Acme", accountId: UUID(), senders: ["a@acme.com"])
        w.unreadCount = 2
        let c = NotificationService.emailWatcherAccumulatedContent(watcher: w, newest: message(from: "a@acme.com"), account: makeAccount(), accountCount: 1)
        XCTAssertEqual(c.title, "2 new from a@acme.com")
    }

    // MARK: - Polling

    private struct Rig {
        let service: GmailPollingService
        let api: FakeAPI
        let notifier: FakeNotifier
        let store: EmailWatcherStore
        let watcher: EmailWatcher
        let account: GmailAccount
    }

    private func makeRig() -> Rig {
        let account = makeAccount()
        let gmailStore = GmailAccountStore(fileURL: tempURL("accounts"), keychain: nil)
        gmailStore.add(account)
        let store = EmailWatcherStore(fileURL: tempURL("watchers"))
        let watcher = EmailWatcher(name: "Acme", accountId: account.id, senders: ["@acme.com"])
        store.add(watcher)
        let api = FakeAPI()
        api.messagesById["m1"] = response(id: "m1", from: "A <a@acme.com>", subject: "S1", millis: 1_000)
        api.messagesById["m2"] = response(id: "m2", from: "B <b@acme.com>", subject: "S2", millis: 2_000)
        api.messagesById["x1"] = response(id: "x1", from: "Not Acme.com <x@other.com>", subject: "Nope", millis: 3_000)
        let notifier = FakeNotifier()
        let service = GmailPollingService(store: gmailStore, emailWatchers: store, api: api, notifier: notifier)
        return Rig(service: service, api: api, notifier: notifier, store: store, watcher: watcher, account: account)
    }

    private func refresh(_ r: Rig) async {
        await r.service.refreshUnread(for: r.watcher, account: r.account, accessToken: "access-token")
    }

    func testFirstRefreshSeedsSilentlyThenNewIdNotifiesOnce() async {
        let r = makeRig()
        r.api.unreadIds = ["m1"]
        await refresh(r)
        XCTAssertEqual(r.store.watchers.first?.unreadCount, 1)
        XCTAssertTrue(r.notifier.accumulated.isEmpty, "first refresh is a silent baseline")

        r.api.unreadIds = ["m2", "m1"]
        await refresh(r)
        XCTAssertEqual(r.notifier.accumulated.count, 1)
        XCTAssertEqual(r.notifier.accumulated.first?.watcher.unreadCount, 2)
        XCTAssertEqual(r.notifier.accumulated.first?.newest.messageId, "m2")
        XCTAssertEqual(r.notifier.accumulated.first?.watcher.recentSubjects, ["S2", "S1"])
    }

    func testReadInGmailLowersCountWithoutNotifyingAndZeroClears() async {
        let r = makeRig()
        r.api.unreadIds = ["m1"]
        await refresh(r)
        r.api.unreadIds = ["m2", "m1"]
        await refresh(r)
        XCTAssertEqual(r.notifier.accumulated.count, 1)

        r.api.unreadIds = ["m2"]
        await refresh(r)
        XCTAssertEqual(r.notifier.accumulated.count, 1, "a decrease never notifies")
        XCTAssertEqual(r.store.watchers.first?.unreadCount, 1)
        XCTAssertTrue(r.notifier.cleared.isEmpty)

        r.api.unreadIds = []
        await refresh(r)
        XCTAssertEqual(r.notifier.cleared, [r.watcher.id])
        XCTAssertEqual(r.store.watchers.first?.unreadCount, 0)
    }

    func testNonMatchingSendersAreIgnoredAndNotRefetched() async {
        let r = makeRig()
        r.api.unreadIds = ["m1", "x1"]
        await refresh(r)
        XCTAssertEqual(r.store.watchers.first?.unreadMessageIds, ["m1"])
        await refresh(r)
        XCTAssertEqual(r.api.fetchedIds.filter { $0 == "x1" }.count, 1)
        XCTAssertEqual(r.api.fetchedIds.filter { $0 == "m1" }.count, 1, "known ids are cached")
    }

    func testBaselineSeedsUnreadWithoutNotifying() async {
        let r = makeRig()
        r.api.unreadIds = ["m1", "m2"]
        await r.service.baseline(r.watcher)
        XCTAssertEqual(r.store.watchers.first?.unreadCount, 2)
        XCTAssertTrue(r.notifier.accumulated.isEmpty)
        r.api.unreadIds = ["m1", "m2", "x1"]
        await refresh(r)
        XCTAssertTrue(r.notifier.accumulated.isEmpty, "x1 is ignored, nothing new")
    }
}
