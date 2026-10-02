import Foundation
import Combine

/// Orchestrates periodic polling of Gmail accounts for new messages, and routes each new
/// message to the email watchers that care about its sender (G2) or to the legacy
/// notify-everything behaviour (G4). `api`, `oauth` and `notifier` are injectable so tests
/// can drive routing with fakes instead of the network and Notification Center (§3.12).
@MainActor
class GmailPollingService: ObservableObject {
    @Published var isRunning = false
    @Published var lastCheckTime: Date?

    private var store: GmailAccountStore
    private let emailWatchers: EmailWatcherStore
    private let api: any GmailAPIClient
    private let oauth: GmailOAuthService
    private let notifier: any GmailNotifying

    private var timers: [UUID: Timer] = [:]
    private var inFlightAccountIDs: Set<UUID> = []
    private var labelCache: [UUID: [String: String]] = [:] // accountId -> [labelId: labelName]
    /// watcherId -> [messageId: message] for unread ids already fetched and confirmed as
    /// matching, so each poll fetches metadata only for ids it has not seen.
    private var unreadCache: [UUID: [String: GmailMessage]] = [:]
    /// watcherId -> ids whose From did not match (the query over-matches), never refetched.
    private var unreadRejected: [UUID: Set<String>] = [:]
    /// Watchers whose unread set has been seeded this session; the first refresh is silent.
    private var seededWatchers: Set<UUID> = []

    init(
        store: GmailAccountStore,
        emailWatchers: EmailWatcherStore = .shared,
        api: any GmailAPIClient = GmailAPIService.shared,
        oauth: GmailOAuthService = .shared,
        notifier: any GmailNotifying = NotificationService.shared
    ) {
        self.store = store
        self.emailWatchers = emailWatchers
        self.api = api
        self.oauth = oauth
        self.notifier = notifier
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true

        for account in store.accounts where account.isEnabled && account.isAuthenticated {
            startTimer(for: account)
        }

        print("GmailPollingService started with \(timers.count) active accounts")
    }

    func stop() {
        isRunning = false
        for (_, timer) in timers {
            timer.invalidate()
        }
        timers.removeAll()
        print("GmailPollingService stopped")
    }

    func checkNow(_ account: GmailAccount) {
        Task {
            await performCheck(account)
        }
    }

    func accountUpdated(_ account: GmailAccount) {
        timers[account.id]?.invalidate()
        timers.removeValue(forKey: account.id)

        if account.isEnabled && account.isAuthenticated && isRunning {
            startTimer(for: account)
        }
    }

    /// Whether `accountId` currently has a `performCheck` awaiting the network. Only used by
    /// `GmailPollingRoutingTests` to assert that `accountUpdated` no longer clears this guard
    /// out from under a check that's genuinely mid-flight.
    func isCheckInFlight(_ accountId: UUID) -> Bool {
        inFlightAccountIDs.contains(accountId)
    }

    func accountDeleted(_ accountId: UUID) {
        timers[accountId]?.invalidate()
        timers.removeValue(forKey: accountId)
        inFlightAccountIDs.remove(accountId)
        labelCache.removeValue(forKey: accountId)
        for watcher in emailWatchers.watchers(for: accountId) {
            unreadCache.removeValue(forKey: watcher.id)
            unreadRejected.removeValue(forKey: watcher.id)
            seededWatchers.remove(watcher.id)
        }
    }

    // MARK: - Routing (pure, testable — §3.9)

    /// Which enabled watchers this message's sender matches. `nonisolated` and `static`
    /// because it's pure logic with no dependency on this instance's actor-isolated state,
    /// so `GmailPollingRoutingTests` can call it without any setup.
    nonisolated static func matchingWatchers(for message: GmailMessage, in watchers: [EmailWatcher]) -> [EmailWatcher] {
        let address = message.senderAddress
        return watchers.filter { $0.isEnabled && SenderMatcher.matches(address: address, patterns: $0.senders) }
    }

    /// Looks up the newest existing message from `watcher`'s senders and records it as the
    /// baseline (G3) without notifying. The search query over-matches by design (Gmail's
    /// `from:` operator has no "@domain" form — see `SenderMatcher.gmailQuery`), so every
    /// candidate is re-checked client-side before being trusted.
    func baseline(_ watcher: EmailWatcher) async {
        guard let account = store.accounts.first(where: { $0.id == watcher.accountId }) else { return }

        do {
            let accessToken = try await ensureValidToken(for: account)
            let query = SenderMatcher.gmailQuery(for: watcher.senders)
            let listResponse = try await api.listMessages(accessToken: accessToken, query: query, maxResults: 10)

            var matched: [GmailMessage] = []
            for ref in listResponse.messages ?? [] {
                guard let full = try? await api.fetchMessage(accessToken: accessToken, messageId: ref.id) else { continue }
                let message = buildGmailMessage(from: full, accountId: account.id)
                if SenderMatcher.matches(address: message.senderAddress, patterns: watcher.senders) {
                    matched.append(message)
                }
            }

            let newest = matched.max { $0.date < $1.date }
            emailWatchers.recordBaseline(for: watcher.id, message: newest)

            unreadCache.removeValue(forKey: watcher.id)
            unreadRejected.removeValue(forKey: watcher.id)
            // Seed the live unread set too, silently (no notification on a baseline).
            await refreshUnread(for: watcher, account: account, accessToken: accessToken, notify: false)
        } catch GmailOAuthService.OAuthError.refreshRevoked, APIError.insufficientScopes {
            emailWatchers.recordError(for: watcher.id, "Reconnect required")
        } catch {
            emailWatchers.recordError(for: watcher.id, error.localizedDescription)
        }
    }

    /// Live unread count for one watcher: lists unread inbox mail from its senders, re-checks
    /// each From client-side (fetching metadata only for ids not yet known), stores the set,
    /// and notifies once when new ids appeared. Silent for a watcher's first refresh in this
    /// session unless it already had a persisted unread set, and always when `notify` is false.
    /// Never throws: on a list failure the previous state is kept.
    func refreshUnread(for watcher: EmailWatcher, account: GmailAccount, accessToken: String, notify: Bool = true) async {
        let watcherId = watcher.id
        let current = emailWatchers.watchers.first(where: { $0.id == watcherId }) ?? watcher
        let wasSeeded = seededWatchers.contains(watcherId) || !current.unreadMessageIds.isEmpty
        let previousCount = current.unreadCount

        let query = SenderMatcher.gmailQuery(for: current.senders) + " is:unread in:inbox"
        let refs: [GmailMessageRef]
        do {
            refs = try await api.listMessages(accessToken: accessToken, query: query, maxResults: 25).messages ?? []
        } catch {
            print("Gmail: unread refresh failed for \(current.name): \(error)")
            return
        }

        var cache = unreadCache[watcherId] ?? [:]
        var rejected = unreadRejected[watcherId] ?? []
        var matched: [GmailMessage] = []
        for ref in refs {
            if let known = cache[ref.id] { matched.append(known); continue }
            if rejected.contains(ref.id) { continue }
            guard let full = try? await api.fetchMessage(accessToken: accessToken, messageId: ref.id) else { continue }
            let message = buildGmailMessage(from: full, accountId: account.id)
            if SenderMatcher.matches(address: message.senderAddress, patterns: current.senders) {
                cache[ref.id] = message
                matched.append(message)
            } else {
                rejected.insert(ref.id)
            }
        }
        let listed = Set(refs.map(\.id))
        unreadCache[watcherId] = cache.filter { listed.contains($0.key) }
        unreadRejected[watcherId] = rejected.intersection(listed)

        let sorted = matched.sorted { $0.date > $1.date }
        let fresh = emailWatchers.recordUnread(
            for: watcherId,
            ids: sorted.map(\.messageId),
            newest: sorted.first,
            subjects: sorted.prefix(3).map(\.subject)
        )
        seededWatchers.insert(watcherId)

        guard notify else { return }
        if sorted.isEmpty {
            if previousCount > 0 { notifier.clearEmailWatcherNotification(watcherId: watcherId) }
        } else if wasSeeded, !fresh.isEmpty, let newest = sorted.first,
                  let updated = emailWatchers.watchers.first(where: { $0.id == watcherId }) {
            notifier.notifyEmailWatcherAccumulated(updated, newest: newest, account: account)
        }
    }

    /// Called by the editor after add/update (§3.9): makes sure the account's timer
    /// exists, then re-runs the baseline only when something that changes what "recent
    /// mail from these senders" means actually changed — a rename or sound toggle must
    /// never clobber a live match with a fresh baseline lookup.
    func emailWatcherSaved(_ watcher: EmailWatcher, previous: EmailWatcher?) async {
        if let account = store.accounts.first(where: { $0.id == watcher.accountId }), timers[account.id] == nil {
            // Only (re)create the timer when this account doesn't already have one — a pure
            // rename or sound-toggle save must not restart a healthy timer, and doing so
            // unconditionally is what previously raced a check that was mid-flight for this
            // account (accountUpdated no longer touches the in-flight guard either way, but
            // there's still no reason to invalidate a timer that's already running fine).
            accountUpdated(account)
        }

        let shouldRunBaseline = previous == nil
            || previous?.senders != watcher.senders
            || previous?.accountId != watcher.accountId
        guard shouldRunBaseline else { return }

        await baseline(watcher)
    }

    // MARK: - Private

    private func startTimer(for account: GmailAccount) {
        // Perform initial check
        Task {
            await performCheck(account)
        }

        let timer = Timer.scheduledTimer(
            withTimeInterval: TimeInterval(account.pollingInterval.rawValue),
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let updatedAccount = self.store.accounts.first(where: { $0.id == account.id }) {
                    await self.performCheck(updatedAccount)
                }
            }
        }

        timers[account.id] = timer
        RunLoop.current.add(timer, forMode: .common)
    }

    /// `internal`, not `private`, so `GmailPollingRoutingTests` can drive a single check
    /// directly with a fake API client and assert on in-flight/watermark behaviour.
    func performCheck(_ account: GmailAccount) async {
        guard !inFlightAccountIDs.contains(account.id) else { return }
        inFlightAccountIDs.insert(account.id)
        defer { inFlightAccountIDs.remove(account.id) }

        print("Gmail: Checking \(account.email)")

        do {
            let accessToken = try await ensureValidToken(for: account)

            if let historyId = account.lastHistoryId {
                try await pollHistory(account: account, accessToken: accessToken, startHistoryId: historyId)
            } else {
                try await performInitialSetup(account: account, accessToken: accessToken)
            }

            for watcher in emailWatchers.watchers(for: account.id) where watcher.isEnabled {
                await refreshUnread(for: watcher, account: account, accessToken: accessToken)
            }

            let unreadCount = try await api.fetchUnreadCount(accessToken: accessToken)
            store.updateResult(for: account.id, historyId: nil, unreadCount: unreadCount, error: nil)
            lastCheckTime = Date()
        } catch APIError.unauthorized {
            store.updateResult(for: account.id, historyId: nil, unreadCount: nil, error: "Token expired")
        } catch APIError.insufficientScopes {
            store.updateResult(for: account.id, historyId: nil, unreadCount: nil, error: "Reconnect required")
        } catch APIError.historyExpired {
            // History ID is too old, reset and get a fresh one
            print("Gmail: History ID expired for \(account.email), resetting")
            do {
                let accessToken = try await ensureValidToken(for: account)
                try await performInitialSetup(account: account, accessToken: accessToken)
                let unreadCount = try await api.fetchUnreadCount(accessToken: accessToken)
                store.updateResult(for: account.id, historyId: nil, unreadCount: unreadCount, error: nil)
            } catch {
                store.updateResult(for: account.id, historyId: nil, unreadCount: nil, error: error.localizedDescription)
            }
        } catch GmailOAuthService.OAuthError.refreshRevoked {
            store.updateResult(for: account.id, historyId: nil, unreadCount: nil, error: "Reconnect required")
        } catch {
            store.updateResult(for: account.id, historyId: nil, unreadCount: nil, error: error.localizedDescription)
        }

        print("Gmail: Done checking \(account.email)")
    }

    private func performInitialSetup(account: GmailAccount, accessToken: String) async throws {
        let profile = try await api.fetchProfile(accessToken: accessToken)
        store.updateResult(for: account.id, historyId: profile.historyId, unreadCount: nil, error: nil)

        // Cache labels
        await refreshLabelCache(accountId: account.id, accessToken: accessToken)
    }

    /// `internal`, not `private`, so `GmailPollingRoutingTests` can drive it directly with a
    /// fake API client and assert on pagination and on when the watermark does/doesn't move.
    func pollHistory(account: GmailAccount, accessToken: String, startHistoryId: String) async throws {
        var pageToken: String?
        var latestHistoryId = startHistoryId
        var allSucceeded = true

        // Gmail's history.list truncates to one page and returns nextPageToken when more
        // records remain; follow it until exhausted so a busy inbox after downtime isn't
        // silently truncated to page 1 (the un-fetched pages would otherwise be skipped
        // forever once the final page's historyId is persisted below).
        repeat {
            let historyResponse = try await api.fetchHistory(accessToken: accessToken, startHistoryId: startHistoryId, pageToken: pageToken)
            latestHistoryId = historyResponse.historyId
            let pageSucceeded = await processHistory(historyResponse, account: account, accessToken: accessToken)
            allSucceeded = allSucceeded && pageSucceeded
            pageToken = historyResponse.nextPageToken
        } while pageToken != nil

        // Only advance the persisted watermark past this batch once every page has been
        // fetched AND every message in it was handled. Persisting earlier (or persisting
        // despite a per-message failure) would let an interruption — a crash, a force-quit,
        // or a transient per-message fetch error — permanently skip mail that was never
        // actually processed, since the next poll's startHistoryId would already be past it.
        // The accepted tradeoff: a partial failure re-fetches the whole window next time,
        // which can re-notify already-handled messages — `recordMatch`'s overwrite makes
        // that idempotent rather than duplicating watcher state.
        guard allSucceeded else { return }
        store.updateResult(for: account.id, historyId: latestHistoryId, unreadCount: nil, error: nil)
    }

    /// Routes every newly-added INBOX message from a history response: email watchers
    /// whose senders match get `recordMatch` + `notifyEmailWatcher`; when nothing matches
    /// and the account has "notify for every new email" on, falls back to `notifyGmail`
    /// (G4). Returns whether every message in this page was fetched and routed successfully
    /// — `pollHistory` uses that to decide whether it's safe to move the historyId watermark
    /// past this batch. `internal`, not `private`, so `GmailPollingRoutingTests` can drive it
    /// directly with a fake history response instead of going through the real History API.
    @discardableResult
    func processHistory(_ response: GmailHistoryResponse, account: GmailAccount, accessToken: String) async -> Bool {
        guard let historyRecords = response.history else { return true }

        var notifiedMessageIds: Set<String> = []
        var allSucceeded = true

        for record in historyRecords {
            guard let messagesAdded = record.messagesAdded else { continue }

            for added in messagesAdded {
                let msg = added.message
                // Only route INBOX messages
                guard msg.labelIds?.contains("INBOX") == true else { continue }
                guard !notifiedMessageIds.contains(msg.id) else { continue }
                notifiedMessageIds.insert(msg.id)

                do {
                    let fullMessage = try await api.fetchMessage(accessToken: accessToken, messageId: msg.id)
                    let gmailMessage = buildGmailMessage(from: fullMessage, accountId: account.id)

                    let matched = Self.matchingWatchers(for: gmailMessage, in: emailWatchers.watchers(for: account.id))
                    for watcher in matched {
                        // Notification is posted by `refreshUnread` (accumulated, one per watcher).
                        emailWatchers.recordMatch(for: watcher.id, message: gmailMessage)
                    }
                    if matched.isEmpty && account.notifyAllMail {
                        notifier.notifyGmail(message: gmailMessage, account: account)
                    }
                } catch {
                    // A transient failure (rate limit, brief 5xx) must not let the historyId
                    // watermark move past this message — reporting failure here is what
                    // makes `pollHistory` skip persisting, so the next poll re-fetches this
                    // same window and retries the message instead of dropping it forever.
                    print("Gmail: Failed to fetch message \(msg.id): \(error)")
                    allSucceeded = false
                }
            }
        }

        return allSucceeded
    }

    /// Returns a usable access token, refreshing it first if needed. Throws (rather than
    /// swallowing to nil) so `performCheck`/`baseline` can distinguish a revoked refresh
    /// token from any other failure and report "Reconnect required" specifically.
    private func ensureValidToken(for account: GmailAccount) async throws -> String {
        guard let refreshToken = account.refreshToken, !refreshToken.isEmpty else {
            throw GmailOAuthService.OAuthError.noRefreshToken
        }

        if let accessToken = account.accessToken, !account.isTokenExpired {
            return accessToken
        }

        let result = try await oauth.refreshAccessToken(refreshToken: refreshToken)
        store.updateTokens(for: account.id, accessToken: result.accessToken, expiresAt: result.expiresAt)
        return result.accessToken
    }

    private func refreshLabelCache(accountId: UUID, accessToken: String) async {
        do {
            let response = try await api.fetchLabels(accessToken: accessToken)
            var cache: [String: String] = [:]
            for label in response.labels ?? [] {
                cache[label.id] = label.name
            }
            labelCache[accountId] = cache
        } catch {
            print("Gmail: Failed to cache labels: \(error)")
        }
    }

    private func buildGmailMessage(from response: GmailMessageResponse, accountId: UUID) -> GmailMessage {
        let headers = response.payload?.headers ?? []
        let from = headers.first(where: { $0.name == "From" })?.value ?? "Unknown"
        let subject = headers.first(where: { $0.name == "Subject" })?.value ?? "(No Subject)"
        let dateString = headers.first(where: { $0.name == "Date" })?.value

        var date = Date()
        if let internalDate = response.internalDate, let millis = Double(internalDate) {
            date = Date(timeIntervalSince1970: millis / 1000)
        } else if let dateString {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            date = formatter.date(from: dateString) ?? Date()
        }

        // Resolve label names
        let labelIds = response.labelIds ?? []
        let labelNames: [String] = labelIds.compactMap { id in
            // Skip system labels that aren't useful to display
            if id == "INBOX" || id == "UNREAD" { return nil }
            return labelCache[accountId]?[id] ?? id
        }

        return GmailMessage(
            accountId: accountId,
            messageId: response.id,
            threadId: response.threadId,
            from: from,
            subject: subject,
            date: date,
            labelIds: labelNames,
            snippet: response.snippet ?? ""
        )
    }
}
