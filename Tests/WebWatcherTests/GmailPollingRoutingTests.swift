import XCTest
@testable import WebWatcher

/// Coverage for §3.9's routing logic in `GmailPollingService`: `matchingWatchers` (pure),
/// `processHistory` (message → watcher/notifyAllMail routing), `baseline` (client-side
/// re-check of the over-matching Gmail query), and `emailWatcherSaved` (when a save should
/// re-run the baseline). Every test uses a fake `GmailAPIClient` and fake `GmailNotifying`
/// plus temp-file-backed stores — nothing here touches the network, the real Keychain, or
/// the real Application Support folder.
@MainActor
final class GmailPollingRoutingTests: XCTestCase {

    // MARK: - Fakes

    private final class FakeGmailAPIClient: GmailAPIClient {
        var messagesById: [String: GmailMessageResponse] = [:]
        /// message ids in here fail `fetchMessage` with a transient-looking error, so tests
        /// can exercise the "a follow-up fetch fails mid-batch" path without real network.
        var messageFetchErrors: Set<String> = []
        var listMessagesResult: Result<GmailMessageListResponse, Error> = .success(
            GmailMessageListResponse(messages: [], resultSizeEstimate: 0)
        )
        /// Consumed in order, one per `fetchHistory` call, so pagination tests can hand back
        /// a distinct response (with its own `nextPageToken`/`historyId`) per page. Empty →
        /// falls back to an empty, single-page response echoing `startHistoryId` back.
        var historyPages: [GmailHistoryResponse] = []
        private(set) var fetchHistoryCallCount = 0
        /// Invoked at the top of `fetchHistory`, before returning a page — lets a test
        /// suspend a call mid-flight (e.g. via a rendezvous) to simulate a genuinely
        /// in-progress check instead of one that merely hasn't started yet.
        var onFetchHistory: (() async -> Void)?

        func fetchProfile(accessToken: String) async throws -> GmailProfileResponse {
            GmailProfileResponse(emailAddress: "me@example.com", messagesTotal: nil, threadsTotal: nil, historyId: "1")
        }

        func fetchLabels(accessToken: String) async throws -> GmailLabelResponse {
            GmailLabelResponse(labels: [])
        }

        func fetchHistory(accessToken: String, startHistoryId: String, pageToken: String?) async throws -> GmailHistoryResponse {
            await onFetchHistory?()
            fetchHistoryCallCount += 1
            guard !historyPages.isEmpty else {
                return GmailHistoryResponse(history: nil, nextPageToken: nil, historyId: startHistoryId)
            }
            let index = min(fetchHistoryCallCount - 1, historyPages.count - 1)
            return historyPages[index]
        }

        func fetchMessage(accessToken: String, messageId: String) async throws -> GmailMessageResponse {
            if messageFetchErrors.contains(messageId) {
                throw APIError.requestFailed(500, "transient failure")
            }
            guard let response = messagesById[messageId] else {
                throw APIError.requestFailed(404, "no fixture for \(messageId)")
            }
            return response
        }

        func fetchUnreadCount(accessToken: String) async throws -> Int { 0 }

        func listMessages(accessToken: String, query: String, maxResults: Int) async throws -> GmailMessageListResponse {
            try listMessagesResult.get()
        }

        func modifyMessage(accessToken: String, messageId: String, addLabels: [String]?, removeLabels: [String]?) async throws {}

        func trashMessage(accessToken: String, messageId: String) async throws {}
    }

    private final class FakeGmailNotifying: GmailNotifying {
        private(set) var gmailCalls: [(message: GmailMessage, account: GmailAccount)] = []
        private(set) var emailWatcherCalls: [(watcher: EmailWatcher, message: GmailMessage, account: GmailAccount)] = []

        func notifyGmail(message: GmailMessage, account: GmailAccount) {
            gmailCalls.append((message, account))
        }

        func notifyEmailWatcher(_ watcher: EmailWatcher, message: GmailMessage, account: GmailAccount) {
            emailWatcherCalls.append((watcher, message, account))
        }

        func notifyEmailWatcherAccumulated(_ watcher: EmailWatcher, newest: GmailMessage, account: GmailAccount) {}

        func clearEmailWatcherNotification(watcherId: UUID) {}
    }

    // MARK: - Fixtures

    private func tempURL(_ name: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("\(name)_\(UUID().uuidString).json")
    }

    private func makeAccount(notifyAllMail: Bool = false) -> GmailAccount {
        var account = GmailAccount(email: "me@example.com", accountIndex: 0, notifyAllMail: notifyAllMail)
        // A valid, non-expired access token so `ensureValidToken` never calls the real
        // `GmailOAuthService` (no network, no client configuration needed in tests).
        account.accessToken = "access-token"
        account.refreshToken = "refresh-token"
        account.tokenExpiresAt = Date().addingTimeInterval(3600)
        return account
    }

    private func makeMessageResponse(id: String, threadId: String, from: String, subject: String, dateMillis: Int64, labelIds: [String] = ["INBOX"]) -> GmailMessageResponse {
        GmailMessageResponse(
            id: id,
            threadId: threadId,
            labelIds: labelIds,
            snippet: "",
            payload: GmailMessagePayload(
                headers: [
                    GmailHeader(name: "From", value: from),
                    GmailHeader(name: "Subject", value: subject),
                    GmailHeader(name: "Date", value: "")
                ],
                mimeType: nil,
                body: nil,
                parts: nil
            ),
            internalDate: String(dateMillis),
            historyId: nil
        )
    }

    private func historyResponse(messageIds: [(id: String, threadId: String)]) -> GmailHistoryResponse {
        let added = messageIds.map { GmailMessageAdded(message: GmailHistoryMessage(id: $0.id, threadId: $0.threadId, labelIds: ["INBOX"])) }
        let record = GmailHistoryRecord(id: "rec1", messages: nil, messagesAdded: added, labelsAdded: nil, labelsRemoved: nil)
        return GmailHistoryResponse(history: [record], nextPageToken: nil, historyId: "2")
    }

    // MARK: - matchingWatchers (pure)

    func testMatchingWatchersFiltersDisabledAndUnrelatedSenders() {
        let accountId = UUID()
        let watched = EmailWatcher(name: "Watched", accountId: accountId, senders: ["a@acme.com"])
        var disabled = EmailWatcher(name: "Disabled", accountId: accountId, senders: ["a@acme.com"])
        disabled.isEnabled = false
        let unrelated = EmailWatcher(name: "Unrelated", accountId: accountId, senders: ["x@other.com"])

        let message = GmailMessage(
            accountId: accountId, messageId: "m1", threadId: "t1",
            from: "A <a@acme.com>", subject: "Hi", date: Date(), labelIds: [], snippet: ""
        )

        let result = GmailPollingService.matchingWatchers(for: message, in: [watched, disabled, unrelated])
        XCTAssertEqual(result.map(\.id), [watched.id])
    }

    // MARK: - processHistory routing

    func testWatchedSenderRecordsMatchWithoutPerMessageNotification() async {
        let account = makeAccount()
        let gmailStore = GmailAccountStore(fileURL: tempURL("accounts"), keychain: nil)
        gmailStore.add(account)

        let emailStore = EmailWatcherStore(fileURL: tempURL("watchers"))
        let watcher = EmailWatcher(name: "Acme", accountId: account.id, senders: ["a@acme.com"])
        emailStore.add(watcher)

        let api = FakeGmailAPIClient()
        api.messagesById["m1"] = makeMessageResponse(id: "m1", threadId: "t1", from: "Acme <a@acme.com>", subject: "Invoice", dateMillis: 1_700_000_000_000)

        let notifier = FakeGmailNotifying()
        let service = GmailPollingService(store: gmailStore, emailWatchers: emailStore, api: api, notifier: notifier)

        await service.processHistory(historyResponse(messageIds: [(id: "m1", threadId: "t1")]), account: account, accessToken: "access-token")

        // Watcher matches no longer post per-message notifications; `refreshUnread` posts
        // one accumulated notification per watcher instead.
        XCTAssertEqual(notifier.emailWatcherCalls.count, 0)
        XCTAssertEqual(notifier.gmailCalls.count, 0)
        XCTAssertEqual(emailStore.watchers.first?.matchCount, 1)
        XCTAssertEqual(emailStore.watchers.first?.lastMatchMessageId, "m1")
    }

    func testUnwatchedSenderWithNotifyAllMailOffNotifiesNothing() async {
        let account = makeAccount(notifyAllMail: false)
        let gmailStore = GmailAccountStore(fileURL: tempURL("accounts"), keychain: nil)
        gmailStore.add(account)

        let emailStore = EmailWatcherStore(fileURL: tempURL("watchers"))
        let watcher = EmailWatcher(name: "Acme", accountId: account.id, senders: ["a@acme.com"])
        emailStore.add(watcher)

        let api = FakeGmailAPIClient()
        api.messagesById["m1"] = makeMessageResponse(id: "m1", threadId: "t1", from: "Someone <x@other.com>", subject: "Hi", dateMillis: 1)

        let notifier = FakeGmailNotifying()
        let service = GmailPollingService(store: gmailStore, emailWatchers: emailStore, api: api, notifier: notifier)

        await service.processHistory(historyResponse(messageIds: [(id: "m1", threadId: "t1")]), account: account, accessToken: "access-token")

        XCTAssertEqual(notifier.emailWatcherCalls.count, 0)
        XCTAssertEqual(notifier.gmailCalls.count, 0)
    }

    func testUnwatchedSenderWithNotifyAllMailOnFallsBackToNotifyGmail() async {
        let account = makeAccount(notifyAllMail: true)
        let gmailStore = GmailAccountStore(fileURL: tempURL("accounts"), keychain: nil)
        gmailStore.add(account)

        let emailStore = EmailWatcherStore(fileURL: tempURL("watchers"))

        let api = FakeGmailAPIClient()
        api.messagesById["m1"] = makeMessageResponse(id: "m1", threadId: "t1", from: "Someone <x@other.com>", subject: "Hi", dateMillis: 1)

        let notifier = FakeGmailNotifying()
        let service = GmailPollingService(store: gmailStore, emailWatchers: emailStore, api: api, notifier: notifier)

        await service.processHistory(historyResponse(messageIds: [(id: "m1", threadId: "t1")]), account: account, accessToken: "access-token")

        XCTAssertEqual(notifier.gmailCalls.count, 1)
        XCTAssertEqual(notifier.emailWatcherCalls.count, 0)
    }

    func testNonInboxMessageIsIgnored() async {
        let account = makeAccount(notifyAllMail: true)
        let gmailStore = GmailAccountStore(fileURL: tempURL("accounts"), keychain: nil)
        gmailStore.add(account)
        let emailStore = EmailWatcherStore(fileURL: tempURL("watchers"))

        let api = FakeGmailAPIClient()
        api.messagesById["m1"] = makeMessageResponse(id: "m1", threadId: "t1", from: "x@other.com", subject: "Hi", dateMillis: 1, labelIds: ["SENT"])

        let notifier = FakeGmailNotifying()
        let service = GmailPollingService(store: gmailStore, emailWatchers: emailStore, api: api, notifier: notifier)

        // The history record itself reports INBOX (that's what the real History API call
        // filters on), but the fetched message's own labelIds say otherwise — matching the
        // guard in `processHistory` that re-checks `msg.labelIds` from the added-message
        // record, not the full fetch. Build the history record directly to exercise that.
        let added = GmailMessageAdded(message: GmailHistoryMessage(id: "m1", threadId: "t1", labelIds: ["SENT"]))
        let record = GmailHistoryRecord(id: "r1", messages: nil, messagesAdded: [added], labelsAdded: nil, labelsRemoved: nil)
        let history = GmailHistoryResponse(history: [record], nextPageToken: nil, historyId: "2")

        await service.processHistory(history, account: account, accessToken: "access-token")

        XCTAssertEqual(notifier.gmailCalls.count, 0)
        XCTAssertEqual(notifier.emailWatcherCalls.count, 0)
    }

    // MARK: - baseline

    func testBaselineKeepsOnlyMatchingResultsAndNeverNotifies() async {
        let account = makeAccount()
        let gmailStore = GmailAccountStore(fileURL: tempURL("accounts"), keychain: nil)
        gmailStore.add(account)

        let emailStore = EmailWatcherStore(fileURL: tempURL("watchers"))
        let watcher = EmailWatcher(name: "Acme", accountId: account.id, senders: ["@acme.com"])
        emailStore.add(watcher)

        let api = FakeGmailAPIClient()
        api.listMessagesResult = .success(GmailMessageListResponse(
            messages: [GmailMessageRef(id: "m1", threadId: "t1"), GmailMessageRef(id: "m2", threadId: "t2")],
            resultSizeEstimate: 2
        ))
        // m1 is a genuine match, m2 is the query's over-match (domain token appears in the
        // display name, not the actual address) and must be dropped by the client-side
        // re-check.
        api.messagesById["m1"] = makeMessageResponse(id: "m1", threadId: "t1", from: "A <a@acme.com>", subject: "Older", dateMillis: 1_000)
        api.messagesById["m2"] = makeMessageResponse(id: "m2", threadId: "t2", from: "Not Acme.com Really <x@other.com>", subject: "Newer", dateMillis: 2_000)

        let notifier = FakeGmailNotifying()
        let service = GmailPollingService(store: gmailStore, emailWatchers: emailStore, api: api, notifier: notifier)

        await service.baseline(watcher)

        XCTAssertEqual(emailStore.watchers.first?.lastMatchMessageId, "m1")
        XCTAssertNil(emailStore.watchers.first?.lastError)
        XCTAssertEqual(notifier.gmailCalls.count, 0)
        XCTAssertEqual(notifier.emailWatcherCalls.count, 0)
        XCTAssertEqual(emailStore.watchers.first?.matchCount, 0, "a baseline must never count as a match")
    }

    func testBaselinePicksTheNewestOfSeveralMatches() async {
        let account = makeAccount()
        let gmailStore = GmailAccountStore(fileURL: tempURL("accounts"), keychain: nil)
        gmailStore.add(account)

        let emailStore = EmailWatcherStore(fileURL: tempURL("watchers"))
        let watcher = EmailWatcher(name: "Acme", accountId: account.id, senders: ["@acme.com"])
        emailStore.add(watcher)

        let api = FakeGmailAPIClient()
        api.listMessagesResult = .success(GmailMessageListResponse(
            messages: [GmailMessageRef(id: "m1", threadId: "t1"), GmailMessageRef(id: "m2", threadId: "t2")],
            resultSizeEstimate: 2
        ))
        api.messagesById["m1"] = makeMessageResponse(id: "m1", threadId: "t1", from: "a@acme.com", subject: "Older", dateMillis: 1_000)
        api.messagesById["m2"] = makeMessageResponse(id: "m2", threadId: "t2", from: "b@acme.com", subject: "Newer", dateMillis: 2_000)

        let notifier = FakeGmailNotifying()
        let service = GmailPollingService(store: gmailStore, emailWatchers: emailStore, api: api, notifier: notifier)

        await service.baseline(watcher)

        XCTAssertEqual(emailStore.watchers.first?.lastMatchMessageId, "m2")
    }

    func testBaselineWithEmptyListRecordsNilBaseline() async {
        let account = makeAccount()
        let gmailStore = GmailAccountStore(fileURL: tempURL("accounts"), keychain: nil)
        gmailStore.add(account)

        let emailStore = EmailWatcherStore(fileURL: tempURL("watchers"))
        let watcher = EmailWatcher(name: "Acme", accountId: account.id, senders: ["@acme.com"])
        emailStore.add(watcher)

        let api = FakeGmailAPIClient()
        api.listMessagesResult = .success(GmailMessageListResponse(messages: [], resultSizeEstimate: 0))

        let notifier = FakeGmailNotifying()
        let service = GmailPollingService(store: gmailStore, emailWatchers: emailStore, api: api, notifier: notifier)

        await service.baseline(watcher)

        XCTAssertNil(emailStore.watchers.first?.lastMatchMessageId)
        XCTAssertNil(emailStore.watchers.first?.lastError)
    }

    // MARK: - emailWatcherSaved

    func testRenameOnlySaveSkipsBaseline() async {
        let account = makeAccount()
        let gmailStore = GmailAccountStore(fileURL: tempURL("accounts"), keychain: nil)
        gmailStore.add(account)

        let emailStore = EmailWatcherStore(fileURL: tempURL("watchers"))
        let original = EmailWatcher(name: "Old Name", accountId: account.id, senders: ["a@acme.com"])
        emailStore.add(original)

        let api = FakeGmailAPIClient()
        // If baseline ran, this fixture would surface as the new lastMatchMessageId — its
        // absence after the save is how the test proves baseline did NOT run.
        api.listMessagesResult = .success(GmailMessageListResponse(messages: [GmailMessageRef(id: "m1", threadId: "t1")], resultSizeEstimate: 1))
        api.messagesById["m1"] = makeMessageResponse(id: "m1", threadId: "t1", from: "a@acme.com", subject: "S", dateMillis: 1)

        let notifier = FakeGmailNotifying()
        let service = GmailPollingService(store: gmailStore, emailWatchers: emailStore, api: api, notifier: notifier)

        var renamed = original
        renamed.name = "New Name"
        emailStore.update(renamed)

        await service.emailWatcherSaved(renamed, previous: original)

        XCTAssertNil(emailStore.watchers.first?.lastMatchMessageId)
    }

    func testSendersChangeRunsBaseline() async {
        let account = makeAccount()
        let gmailStore = GmailAccountStore(fileURL: tempURL("accounts"), keychain: nil)
        gmailStore.add(account)

        let emailStore = EmailWatcherStore(fileURL: tempURL("watchers"))
        let original = EmailWatcher(name: "W", accountId: account.id, senders: ["a@acme.com"])
        emailStore.add(original)

        let api = FakeGmailAPIClient()
        api.listMessagesResult = .success(GmailMessageListResponse(messages: [GmailMessageRef(id: "m1", threadId: "t1")], resultSizeEstimate: 1))
        api.messagesById["m1"] = makeMessageResponse(id: "m1", threadId: "t1", from: "b@acme.com", subject: "S", dateMillis: 1)

        let notifier = FakeGmailNotifying()
        let service = GmailPollingService(store: gmailStore, emailWatchers: emailStore, api: api, notifier: notifier)

        var changed = original
        changed.senders = ["b@acme.com"]
        emailStore.update(changed)

        await service.emailWatcherSaved(changed, previous: original)

        XCTAssertEqual(emailStore.watchers.first?.lastMatchMessageId, "m1")
    }

    func testNewWatcherWithNoPreviousRunsBaseline() async {
        let account = makeAccount()
        let gmailStore = GmailAccountStore(fileURL: tempURL("accounts"), keychain: nil)
        gmailStore.add(account)

        let emailStore = EmailWatcherStore(fileURL: tempURL("watchers"))
        let watcher = EmailWatcher(name: "New", accountId: account.id, senders: ["a@acme.com"])
        emailStore.add(watcher)

        let api = FakeGmailAPIClient()
        api.listMessagesResult = .success(GmailMessageListResponse(messages: [GmailMessageRef(id: "m1", threadId: "t1")], resultSizeEstimate: 1))
        api.messagesById["m1"] = makeMessageResponse(id: "m1", threadId: "t1", from: "a@acme.com", subject: "S", dateMillis: 1)

        let notifier = FakeGmailNotifying()
        let service = GmailPollingService(store: gmailStore, emailWatchers: emailStore, api: api, notifier: notifier)

        await service.emailWatcherSaved(watcher, previous: nil)

        XCTAssertEqual(emailStore.watchers.first?.lastMatchMessageId, "m1")
    }

    // MARK: - pollHistory (pagination + when the watermark is persisted)

    func testPollHistoryFollowsPaginationAndPersistsOnlyTheFinalPageHistoryId() async {
        let account = makeAccount()
        let gmailStore = GmailAccountStore(fileURL: tempURL("accounts"), keychain: nil)
        gmailStore.add(account)
        let emailStore = EmailWatcherStore(fileURL: tempURL("watchers"))
        let watcher = EmailWatcher(name: "Acme", accountId: account.id, senders: ["a@acme.com"])
        emailStore.add(watcher)

        let api = FakeGmailAPIClient()
        let addedPage1 = GmailMessageAdded(message: GmailHistoryMessage(id: "m1", threadId: "t1", labelIds: ["INBOX"]))
        let addedPage2 = GmailMessageAdded(message: GmailHistoryMessage(id: "m2", threadId: "t2", labelIds: ["INBOX"]))
        api.historyPages = [
            GmailHistoryResponse(
                history: [GmailHistoryRecord(id: "r1", messages: nil, messagesAdded: [addedPage1], labelsAdded: nil, labelsRemoved: nil)],
                nextPageToken: "page2",
                historyId: "50"
            ),
            GmailHistoryResponse(
                history: [GmailHistoryRecord(id: "r2", messages: nil, messagesAdded: [addedPage2], labelsAdded: nil, labelsRemoved: nil)],
                nextPageToken: nil,
                historyId: "99"
            )
        ]
        api.messagesById["m1"] = makeMessageResponse(id: "m1", threadId: "t1", from: "a@acme.com", subject: "One", dateMillis: 1)
        api.messagesById["m2"] = makeMessageResponse(id: "m2", threadId: "t2", from: "a@acme.com", subject: "Two", dateMillis: 2)

        let notifier = FakeGmailNotifying()
        let service = GmailPollingService(store: gmailStore, emailWatchers: emailStore, api: api, notifier: notifier)

        try? await service.pollHistory(account: account, accessToken: "access-token", startHistoryId: "1")

        XCTAssertEqual(api.fetchHistoryCallCount, 2, "must follow nextPageToken to fetch the second page instead of stopping at page 1")
        XCTAssertEqual(emailStore.watchers.first?.matchCount, 2, "both pages' messages must be routed, not just page 1's")
        XCTAssertEqual(gmailStore.accounts.first?.lastHistoryId, "99", "must persist the LAST page's historyId, not the first page's")
    }

    func testPollHistoryDoesNotAdvanceWatermarkWhenAMessageFetchFails() async {
        var account = makeAccount()
        account.lastHistoryId = "1"
        let gmailStore = GmailAccountStore(fileURL: tempURL("accounts"), keychain: nil)
        gmailStore.add(account)
        let emailStore = EmailWatcherStore(fileURL: tempURL("watchers"))

        let api = FakeGmailAPIClient()
        let added = GmailMessageAdded(message: GmailHistoryMessage(id: "m1", threadId: "t1", labelIds: ["INBOX"]))
        api.historyPages = [
            GmailHistoryResponse(
                history: [GmailHistoryRecord(id: "r1", messages: nil, messagesAdded: [added], labelsAdded: nil, labelsRemoved: nil)],
                nextPageToken: nil,
                historyId: "50"
            )
        ]
        // Simulates a transient 429/500 on the follow-up GET /messages/{id}.
        api.messageFetchErrors.insert("m1")

        let notifier = FakeGmailNotifying()
        let service = GmailPollingService(store: gmailStore, emailWatchers: emailStore, api: api, notifier: notifier)

        try? await service.pollHistory(account: account, accessToken: "access-token", startHistoryId: "1")

        XCTAssertEqual(gmailStore.accounts.first?.lastHistoryId, "1", "a failed message fetch must not move the watermark past it, so the next poll re-fetches and retries the same window")
    }

    // MARK: - accountUpdated must not race an in-flight performCheck

    func testAccountUpdatedDoesNotClearAnInFlightGuard() async {
        var account = makeAccount()
        account.lastHistoryId = "1"
        let gmailStore = GmailAccountStore(fileURL: tempURL("accounts"), keychain: nil)
        gmailStore.add(account)
        let emailStore = EmailWatcherStore(fileURL: tempURL("watchers"))

        let api = FakeGmailAPIClient()
        api.historyPages = [GmailHistoryResponse(history: nil, nextPageToken: nil, historyId: "2")]

        let rendezvous = Rendezvous()
        api.onFetchHistory = { await rendezvous.arrive() }

        let notifier = FakeGmailNotifying()
        let service = GmailPollingService(store: gmailStore, emailWatchers: emailStore, api: api, notifier: notifier)

        // Start a check and let it suspend right at the network call, so `accountUpdated`
        // below lands while the check is genuinely mid-flight, not merely about to start.
        let checkTask = Task { await service.performCheck(account) }
        await rendezvous.waitForArrival()
        XCTAssertTrue(service.isCheckInFlight(account.id), "performCheck should mark itself in-flight before awaiting the network")

        // Simulates an unrelated save (e.g. a watcher rename) landing while that check is
        // suspended — this used to clear the re-entrancy guard out from under it.
        service.accountUpdated(account)
        XCTAssertTrue(service.isCheckInFlight(account.id), "accountUpdated must not clear the in-flight guard out from under a running check")

        await rendezvous.proceed()
        await checkTask.value
        XCTAssertFalse(service.isCheckInFlight(account.id), "the guard must still be cleared once the check actually finishes")
    }
}

/// A two-party async rendezvous: lets a test suspend a call inside the code under test at a
/// specific checkpoint (`arrive`), wait until it's actually suspended there (`waitForArrival`),
/// make its assertions, then release it (`proceed`) — used instead of `Task.sleep` guessing to
/// deterministically simulate a check that's genuinely mid-flight.
private actor Rendezvous {
    private var hasArrived = false
    private var mayProceed = false
    private var arrivedContinuation: CheckedContinuation<Void, Never>?
    private var proceedContinuation: CheckedContinuation<Void, Never>?

    func arrive() async {
        hasArrived = true
        arrivedContinuation?.resume()
        arrivedContinuation = nil
        if mayProceed { return }
        await withCheckedContinuation { proceedContinuation = $0 }
    }

    func waitForArrival() async {
        if hasArrived { return }
        await withCheckedContinuation { arrivedContinuation = $0 }
    }

    func proceed() {
        mayProceed = true
        proceedContinuation?.resume()
        proceedContinuation = nil
    }
}
