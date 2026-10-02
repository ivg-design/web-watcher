import Foundation

/// Everything `GmailPollingService` needs from the Gmail REST API, extracted so tests can
/// drive polling/routing logic against a fake instead of the real network (§3.12).
protocol GmailAPIClient: AnyObject {
    func fetchProfile(accessToken: String) async throws -> GmailProfileResponse
    func fetchLabels(accessToken: String) async throws -> GmailLabelResponse
    func fetchHistory(accessToken: String, startHistoryId: String, pageToken: String?) async throws -> GmailHistoryResponse
    func fetchMessage(accessToken: String, messageId: String) async throws -> GmailMessageResponse
    func fetchUnreadCount(accessToken: String) async throws -> Int
    func listMessages(accessToken: String, query: String, maxResults: Int) async throws -> GmailMessageListResponse
    func modifyMessage(accessToken: String, messageId: String, addLabels: [String]?, removeLabels: [String]?) async throws
    func trashMessage(accessToken: String, messageId: String) async throws
}

/// Gmail REST API errors. Top-level (not nested in `GmailAPIService`) so both the service
/// and its protocol's callers (`GmailPollingService`, tests against `GmailAPIClient`) can
/// name it without qualifying through the concrete type.
enum APIError: Error, LocalizedError {
    case unauthorized
    /// HTTP 403 whose body contains "insufficient authentication scopes" — the token is
    /// otherwise valid, but was minted under a narrower scope than the app now requests
    /// (e.g. before gmail.modify replaced gmail.readonly). Treated like `.unauthorized`
    /// everywhere: the only remedy is reconnecting the account to re-consent.
    case insufficientScopes
    case historyExpired
    /// HTTP 403 whose body contains "accessNotConfigured" or "has not been used in
    /// project" — the Gmail API itself isn't enabled on the user's Google Cloud project.
    /// Carries the raw response body for logging; the fixed remedy copy doesn't need it.
    case apiNotEnabled(String)
    case rateLimited
    case requestFailed(Int, String)
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Token expired or revoked"
        case .insufficientScopes:
            return "Gmail access needs to be reconnected (insufficient permissions)."
        case .historyExpired:
            return "History ID expired"
        case .apiNotEnabled:
            return "Gmail API is not enabled for this Google Cloud project. Enable it, then try again."
        case .rateLimited:
            return "Google rate limit — will retry"
        case .requestFailed(let code, let msg):
            return "API error \(code): \(msg)"
        case .decodingFailed:
            return "Failed to decode API response"
        }
    }
}

/// Gmail REST API client
final class GmailAPIService: GmailAPIClient {
    static let shared = GmailAPIService()
    private let baseURL = "https://gmail.googleapis.com/gmail/v1/users/me"

    private init() {}

    /// Fetch the user's Gmail profile (email, historyId)
    func fetchProfile(accessToken: String) async throws -> GmailProfileResponse {
        let url = URL(string: "\(baseURL)/profile")!
        return try await performRequest(url: url, accessToken: accessToken)
    }

    /// Fetch all labels for the account
    func fetchLabels(accessToken: String) async throws -> GmailLabelResponse {
        let url = URL(string: "\(baseURL)/labels")!
        return try await performRequest(url: url, accessToken: accessToken)
    }

    /// Fetch history changes since the given historyId. `pageToken` continues a previous
    /// page: Gmail's `history.list` truncates to one page (documented on the order of ~100
    /// records) and returns `nextPageToken` when more remain, so a caller that never passes
    /// this along and persists the response's `historyId` anyway silently skips every
    /// message on the un-fetched pages.
    func fetchHistory(accessToken: String, startHistoryId: String, labelId: String = "INBOX", pageToken: String? = nil) async throws -> GmailHistoryResponse {
        var components = URLComponents(string: "\(baseURL)/history")!
        var queryItems = [
            URLQueryItem(name: "startHistoryId", value: startHistoryId),
            URLQueryItem(name: "labelId", value: labelId),
            URLQueryItem(name: "historyTypes", value: "messageAdded")
        ]
        if let pageToken {
            queryItems.append(URLQueryItem(name: "pageToken", value: pageToken))
        }
        components.queryItems = queryItems
        return try await performRequest(url: components.url!, accessToken: accessToken)
    }

    /// Thin `GmailAPIClient` witness: Swift protocol conformance needs the EXACT parameter
    /// list, so this just forwards to the defaulted method above with today's default label.
    func fetchHistory(accessToken: String, startHistoryId: String, pageToken: String?) async throws -> GmailHistoryResponse {
        try await fetchHistory(accessToken: accessToken, startHistoryId: startHistoryId, labelId: "INBOX", pageToken: pageToken)
    }

    /// Fetch a single message with metadata
    func fetchMessage(accessToken: String, messageId: String, format: String = "metadata", metadataHeaders: [String] = ["From", "Subject", "Date"]) async throws -> GmailMessageResponse {
        var components = URLComponents(string: "\(baseURL)/messages/\(messageId)")!
        var queryItems = [
            URLQueryItem(name: "format", value: format)
        ]
        for header in metadataHeaders {
            queryItems.append(URLQueryItem(name: "metadataHeaders", value: header))
        }
        components.queryItems = queryItems
        return try await performRequest(url: components.url!, accessToken: accessToken)
    }

    /// Thin `GmailAPIClient` witness (see `fetchHistory` above for why this exists).
    func fetchMessage(accessToken: String, messageId: String) async throws -> GmailMessageResponse {
        try await fetchMessage(accessToken: accessToken, messageId: messageId, format: "metadata", metadataHeaders: ["From", "Subject", "Date"])
    }

    /// Search for messages matching `query` (used by the email-watcher baseline lookup,
    /// G3). Deliberately no `labelIds` filter: a sender's most recent mail may have been
    /// archived, and the baseline should still find it.
    func listMessages(accessToken: String, query: String, maxResults: Int) async throws -> GmailMessageListResponse {
        var components = URLComponents(string: "\(baseURL)/messages")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "maxResults", value: String(maxResults))
        ]
        return try await performRequest(url: components.url!, accessToken: accessToken)
    }

    /// Modify message labels (add/remove)
    func modifyMessage(accessToken: String, messageId: String, addLabels: [String]? = nil, removeLabels: [String]? = nil) async throws {
        let url = URL(string: "\(baseURL)/messages/\(messageId)/modify")!
        let body = GmailModifyRequest(addLabelIds: addLabels, removeLabelIds: removeLabels)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try handleHTTPResponse(response, data: data)
    }

    /// Move a message to trash
    func trashMessage(accessToken: String, messageId: String) async throws {
        let url = URL(string: "\(baseURL)/messages/\(messageId)/trash")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        try handleHTTPResponse(response, data: data)
    }

    /// Fetch unread count from INBOX label
    func fetchUnreadCount(accessToken: String) async throws -> Int {
        let url = URL(string: "\(baseURL)/labels/INBOX")!
        let label: GmailLabel = try await performRequest(url: url, accessToken: accessToken)
        return label.messagesUnread ?? 0
    }

    // MARK: - Private

    private func performRequest<T: Decodable>(url: URL, accessToken: String) async throws -> T {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        try handleHTTPResponse(response, data: data)

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            print("GmailAPIService: Decoding failed for \(T.self): \(error)")
            throw APIError.decodingFailed
        }
    }

    /// `internal`, not `private`, so `GmailAPIServiceErrorMappingTests` can build a bare
    /// `HTTPURLResponse` + body and assert on the mapped `APIError` with no network call.
    func handleHTTPResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else { return }

        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401:
            throw APIError.unauthorized
        case 403:
            let msg = String(data: data, encoding: .utf8) ?? "Forbidden"
            if msg.contains("insufficient authentication scopes") {
                throw APIError.insufficientScopes
            }
            if msg.contains("accessNotConfigured") || msg.contains("has not been used in project") {
                throw APIError.apiNotEnabled(msg)
            }
            throw APIError.requestFailed(403, msg)
        case 404:
            // Google's real 404 body for an invalid/expired startHistoryId is the fixed,
            // generic message "Requested entity was not found." — it never contains
            // "historyId" or "notFound" (those only appear in the legacy
            // `error.errors[].reason` field, which this app doesn't decode). The History
            // API's only documented cause for a 404 is an expired history record, so key
            // off the endpoint rather than message text real responses never match.
            if httpResponse.url?.path.contains("/history") == true {
                throw APIError.historyExpired
            }
            // Kept as a fallback for any error-body shape that does spell it out.
            if let errorResponse = try? JSONDecoder().decode(GmailErrorResponse.self, from: data),
               errorResponse.error.message.contains("historyId") || errorResponse.error.message.contains("notFound") {
                throw APIError.historyExpired
            }
            let msg = String(data: data, encoding: .utf8) ?? "Not found"
            throw APIError.requestFailed(404, msg)
        case 429:
            throw APIError.rateLimited
        default:
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.requestFailed(httpResponse.statusCode, msg)
        }
    }
}
