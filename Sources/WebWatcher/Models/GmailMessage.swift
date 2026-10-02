import Foundation

/// A Gmail message for notification display
struct GmailMessage: Equatable {
    let accountId: UUID
    let messageId: String
    let threadId: String
    let from: String
    let subject: String
    let date: Date
    let labelIds: [String]
    let snippet: String

    /// The bare address parsed out of `from`, e.g. "jane@x.com" from "Jane Doe <jane@x.com>".
    /// Used by watcher routing (`SenderMatcher.matches`) instead of matching on the raw header.
    var senderAddress: String {
        SenderMatcher.parse(fromHeader: from).address
    }

    /// The display name parsed out of `from`; empty when the header has no name part.
    var senderName: String {
        SenderMatcher.parse(fromHeader: from).name
    }
}

// MARK: - Gmail message list (used for the email-watcher baseline lookup)

struct GmailMessageListResponse: Decodable {
    let messages: [GmailMessageRef]?
    let resultSizeEstimate: Int?
}

struct GmailMessageRef: Decodable {
    let id: String
    let threadId: String
}

// MARK: - Gmail API Response Types

struct GmailProfileResponse: Decodable {
    let emailAddress: String
    let messagesTotal: Int?
    let threadsTotal: Int?
    let historyId: String
}

struct GmailHistoryResponse: Decodable {
    let history: [GmailHistoryRecord]?
    let nextPageToken: String?
    let historyId: String
}

struct GmailHistoryRecord: Decodable {
    let id: String
    let messages: [GmailHistoryMessage]?
    let messagesAdded: [GmailMessageAdded]?
    let labelsAdded: [GmailLabelChange]?
    let labelsRemoved: [GmailLabelChange]?
}

struct GmailHistoryMessage: Decodable {
    let id: String
    let threadId: String
    let labelIds: [String]?
}

struct GmailMessageAdded: Decodable {
    let message: GmailHistoryMessage
}

struct GmailLabelChange: Decodable {
    let message: GmailHistoryMessage
    let labelIds: [String]
}

struct GmailMessageResponse: Decodable {
    let id: String
    let threadId: String
    let labelIds: [String]?
    let snippet: String?
    let payload: GmailMessagePayload?
    let internalDate: String?
    let historyId: String?
}

struct GmailMessagePayload: Decodable {
    let headers: [GmailHeader]?
    let mimeType: String?
    let body: GmailMessageBody?
    let parts: [GmailMessagePart]?
}

struct GmailHeader: Decodable {
    let name: String
    let value: String
}

struct GmailMessageBody: Decodable {
    let size: Int?
    let data: String?
}

struct GmailMessagePart: Decodable {
    let mimeType: String?
    let headers: [GmailHeader]?
    let body: GmailMessageBody?
}

struct GmailLabelResponse: Decodable {
    let labels: [GmailLabel]?
}

struct GmailLabel: Decodable {
    let id: String
    let name: String
    let type: String?
    let messagesUnread: Int?
}

struct GmailModifyRequest: Encodable {
    let addLabelIds: [String]?
    let removeLabelIds: [String]?
}

struct GmailTokenResponse: Decodable {
    let access_token: String
    let expires_in: Int
    let refresh_token: String?
    let token_type: String
    let scope: String?
}

struct GoogleUserInfoResponse: Decodable {
    let email: String
    let name: String?
    let picture: String?
}

struct GmailErrorResponse: Decodable {
    let error: GmailAPIError
}

struct GmailAPIError: Decodable {
    let code: Int
    let message: String
    let status: String?
}
