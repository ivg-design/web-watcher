import Foundation

/// Poll interval options for Gmail accounts
enum GmailPollInterval: Int, Codable, CaseIterable {
    case seconds30 = 30
    case minute1 = 60
    case minutes2 = 120
    case minutes5 = 300
    case minutes10 = 600

    var displayName: String {
        switch self {
        case .seconds30: return "30 seconds"
        case .minute1: return "1 minute"
        case .minutes2: return "2 minutes"
        case .minutes5: return "5 minutes"
        case .minutes10: return "10 minutes"
        }
    }
}

/// A connected Gmail account
struct GmailAccount: Identifiable, Codable {
    var id: UUID
    var email: String
    var displayName: String
    var isEnabled: Bool
    var pollingInterval: GmailPollInterval
    var notificationSound: Bool
    var accountIndex: Int
    /// Per-account "Notify for every new email" toggle (G4). Default false: with it off,
    /// nothing notifies unless an email watcher matches the sender.
    var notifyAllMail: Bool

    // State (persisted)
    var lastHistoryId: String?
    var lastCheck: Date?
    var lastError: String?
    var consecutiveErrors: Int
    var unreadCount: Int

    // Tokens are NOT persisted in JSON - stored in Keychain
    var accessToken: String?
    var refreshToken: String?
    var tokenExpiresAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, email, displayName, isEnabled, pollingInterval, notificationSound, accountIndex, notifyAllMail
        case lastHistoryId, lastCheck, lastError, consecutiveErrors, unreadCount
    }

    init(
        id: UUID = UUID(),
        email: String = "",
        displayName: String = "",
        isEnabled: Bool = true,
        pollingInterval: GmailPollInterval = .minute1,
        notificationSound: Bool = true,
        accountIndex: Int = 0,
        notifyAllMail: Bool = false
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.isEnabled = isEnabled
        self.pollingInterval = pollingInterval
        self.notificationSound = notificationSound
        self.accountIndex = accountIndex
        self.notifyAllMail = notifyAllMail
        self.lastHistoryId = nil
        self.lastCheck = nil
        self.lastError = nil
        self.consecutiveErrors = 0
        self.unreadCount = 0
        self.accessToken = nil
        self.refreshToken = nil
        self.tokenExpiresAt = nil
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        email = try container.decode(String.self, forKey: .email)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName) ?? ""
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        pollingInterval = try container.decodeIfPresent(GmailPollInterval.self, forKey: .pollingInterval) ?? .minute1
        notificationSound = try container.decodeIfPresent(Bool.self, forKey: .notificationSound) ?? true
        accountIndex = try container.decodeIfPresent(Int.self, forKey: .accountIndex) ?? 0
        notifyAllMail = try container.decodeIfPresent(Bool.self, forKey: .notifyAllMail) ?? false
        lastHistoryId = try container.decodeIfPresent(String.self, forKey: .lastHistoryId)
        lastCheck = try container.decodeIfPresent(Date.self, forKey: .lastCheck)
        lastError = try container.decodeIfPresent(String.self, forKey: .lastError)
        consecutiveErrors = try container.decodeIfPresent(Int.self, forKey: .consecutiveErrors) ?? 0
        unreadCount = try container.decodeIfPresent(Int.self, forKey: .unreadCount) ?? 0
        // Tokens loaded separately from Keychain
        accessToken = nil
        refreshToken = nil
        tokenExpiresAt = nil
    }

    var statusDisplay: String {
        if let error = lastError {
            return "Error: \(error)"
        }
        if !isAuthenticated {
            return "Not connected — reconnect in Settings"
        }
        if unreadCount > 0 {
            return "\(unreadCount) unread"
        }
        return "Monitoring"
    }

    /// Non-empty refresh token, not merely non-nil (F6: `AuthResult.refreshToken = tokenResponse.refresh_token ?? ""`
    /// used to leave an empty string that read as "authenticated" while every refresh failed).
    var isAuthenticated: Bool {
        !(refreshToken ?? "").isEmpty
    }

    var isTokenExpired: Bool {
        guard let expiresAt = tokenExpiresAt else { return true }
        return Date() >= expiresAt.addingTimeInterval(-60) // Refresh 60s early
    }

    /// Gmail inbox URL for this account
    var gmailInboxURL: URL? {
        URL(string: "https://mail.google.com/mail/u/\(accountIndex)/#inbox")
    }

    /// Gmail thread URL for this account
    func gmailThreadURL(threadId: String) -> URL? {
        URL(string: "https://mail.google.com/mail/u/\(accountIndex)/#inbox/\(threadId)")
    }
}
