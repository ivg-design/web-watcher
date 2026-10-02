import Foundation

/// Runs the Google OAuth flow and wires the result into `GmailAccountStore` +
/// `GmailPollingService` (G1). Both Settings and the email-watcher editor's "Connect a
/// Gmail account…" button call this, so there's exactly one place that turns an
/// `AuthResult` into a persisted, polling `GmailAccount` — no duplicated flow to drift.
@MainActor
enum GmailAccountConnector {

    enum ConnectError: LocalizedError {
        case alreadyConnected(String)
        /// `reconnect(_:)` requires signing back in as the SAME Google account — otherwise
        /// a set of email watchers would silently start pointing at a different mailbox.
        case wrongAccount(expected: String, got: String)

        var errorDescription: String? {
            switch self {
            case .alreadyConnected(let email):
                return "\(email) is already connected."
            case .wrongAccount(let expected, let got):
                return "You signed in as \(got), but this account is \(expected). Sign in with \(expected) instead, or add \(got) as a new account."
            }
        }
    }

    /// Runs OAuth, dedupes by email (case-insensitive), appends to the store with the next
    /// accountIndex, and starts polling.
    static func connect(
        store: GmailAccountStore = .shared,
        polling: GmailPollingService?,
        oauth: GmailOAuthService = .shared
    ) async throws -> GmailAccount {
        let result = try await oauth.authorize()

        if let existing = store.accounts.first(where: { $0.email.caseInsensitiveCompare(result.email) == .orderedSame }) {
            throw ConnectError.alreadyConnected(existing.email)
        }

        var account = GmailAccount(
            email: result.email,
            displayName: result.displayName,
            accountIndex: store.nextAccountIndex
        )
        account.accessToken = result.accessToken
        account.refreshToken = result.refreshToken
        account.tokenExpiresAt = result.expiresAt

        store.add(account)
        polling?.accountUpdated(account)
        return account
    }

    /// Re-runs OAuth for an existing account, replaces its tokens, and clears any
    /// `lastError` (a successful reconnect means whatever was broken now isn't).
    static func reconnect(
        _ account: GmailAccount,
        store: GmailAccountStore = .shared,
        polling: GmailPollingService?,
        oauth: GmailOAuthService = .shared
    ) async throws -> GmailAccount {
        let result = try await oauth.authorize()

        guard result.email.caseInsensitiveCompare(account.email) == .orderedSame else {
            throw ConnectError.wrongAccount(expected: account.email, got: result.email)
        }

        var updated = account
        updated.accessToken = result.accessToken
        updated.refreshToken = result.refreshToken
        updated.tokenExpiresAt = result.expiresAt
        updated.lastError = nil

        store.update(updated)
        polling?.accountUpdated(updated)
        return updated
    }
}
