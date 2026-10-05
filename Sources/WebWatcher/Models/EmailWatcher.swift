import Foundation

/// A Gmail sender-based watcher (G2): notifies when a message from any of `senders` lands
/// in the account's inbox. The state fields use `decodeIfPresent` because they don't exist
/// in JSON written before a watcher's first match (or before this feature existed at all).
struct EmailWatcher: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var accountId: UUID
    /// Normalized via `SenderMatcher.normalize`: lowercased "a@b.com" or "@b.com". Never
    /// empty when saved (the editor enforces at least one sender before enabling Save).
    var senders: [String]
    var isEnabled: Bool
    var notificationSound: Bool

    // MARK: - State (all decodeIfPresent)
    var lastMatchDate: Date?
    /// Raw From header of the last match, kept alongside the parsed name/address so the UI
    /// can show exactly what Gmail sent even if `SenderMatcher.parse` is later refined.
    var lastMatchFrom: String?
    var lastMatchSubject: String?
    var lastMatchMessageId: String?
    var lastMatchThreadId: String?
    var matchCount: Int
    var lastError: String?

    // MARK: - Notification settings (1.9.0, all decodeIfPresent)
    var customIconPath: String?
    var notificationTitle: String?
    var notificationBodyTemplate: String?

    // MARK: - Live unread state (1.9.0, all decodeIfPresent)
    /// Ids of unread inbox messages that currently match `senders`.
    var unreadMessageIds: [String]
    /// Stored copy of `unreadMessageIds.count` for display.
    var unreadCount: Int
    /// Newest first, at most 3.
    var recentSubjects: [String]

    enum CodingKeys: String, CodingKey {
        case id, name, accountId, senders, isEnabled, notificationSound
        case lastMatchDate, lastMatchFrom, lastMatchSubject, lastMatchMessageId, lastMatchThreadId, matchCount, lastError
        case customIconPath, notificationTitle, notificationBodyTemplate
        case unreadMessageIds, unreadCount, recentSubjects
    }

    init(
        id: UUID = UUID(),
        name: String = "",
        accountId: UUID,
        senders: [String] = [],
        isEnabled: Bool = true,
        notificationSound: Bool = true
    ) {
        self.id = id
        self.name = name
        self.accountId = accountId
        self.senders = senders
        self.isEnabled = isEnabled
        self.notificationSound = notificationSound
        self.lastMatchDate = nil
        self.lastMatchFrom = nil
        self.lastMatchSubject = nil
        self.lastMatchMessageId = nil
        self.lastMatchThreadId = nil
        self.matchCount = 0
        self.lastError = nil
        self.customIconPath = nil
        self.notificationTitle = nil
        self.notificationBodyTemplate = nil
        self.unreadMessageIds = []
        self.unreadCount = 0
        self.recentSubjects = []
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        accountId = try container.decode(UUID.self, forKey: .accountId)
        senders = try container.decode([String].self, forKey: .senders)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        notificationSound = try container.decode(Bool.self, forKey: .notificationSound)
        lastMatchDate = try container.decodeIfPresent(Date.self, forKey: .lastMatchDate)
        lastMatchFrom = try container.decodeIfPresent(String.self, forKey: .lastMatchFrom)
        lastMatchSubject = try container.decodeIfPresent(String.self, forKey: .lastMatchSubject)
        lastMatchMessageId = try container.decodeIfPresent(String.self, forKey: .lastMatchMessageId)
        lastMatchThreadId = try container.decodeIfPresent(String.self, forKey: .lastMatchThreadId)
        matchCount = try container.decodeIfPresent(Int.self, forKey: .matchCount) ?? 0
        lastError = try container.decodeIfPresent(String.self, forKey: .lastError)
        customIconPath = try container.decodeIfPresent(String.self, forKey: .customIconPath)
        notificationTitle = try container.decodeIfPresent(String.self, forKey: .notificationTitle)
        notificationBodyTemplate = try container.decodeIfPresent(String.self, forKey: .notificationBodyTemplate)
        unreadMessageIds = try container.decodeIfPresent([String].self, forKey: .unreadMessageIds) ?? []
        unreadCount = try container.decodeIfPresent(Int.self, forKey: .unreadCount) ?? 0
        recentSubjects = try container.decodeIfPresent([String].self, forKey: .recentSubjects) ?? []
    }

    var statusDisplay: String {
        if let lastError {
            return "Error: \(lastError)"
        }
        if unreadCount > 0 {
            if let lastMatchDate {
                return "\(unreadCount) unread · latest \(EmailTimeFormatter.received(lastMatchDate))"
            }
            return "\(unreadCount) unread"
        }
        return lastMatchDate == nil ? "No email yet" : "No unread"
    }

    /// Any unread → Gmail's search for the unread inbox mail from these senders, which is exactly what the count
    /// counts, so what opens always matches the number. (Opening the "last match" thread instead could land on a
    /// different, already read conversation.) Nothing unread → the inbox.
    func openURL(accountIndex: Int) -> URL? {
        if unreadCount >= 1, let search = Self.searchURL(accountIndex: accountIndex, senders: senders) {
            return search
        }
        return URL(string: "https://mail.google.com/mail/u/\(accountIndex)/#inbox")
    }

    static func searchURL(accountIndex: Int, senders: [String]) -> URL? {
        SenderMatcher.gmailSearchURL(accountIndex: accountIndex, senders: senders)
    }

    var displayName: String {
        name.isEmpty ? senders.joined(separator: ", ") : name
    }
}

/// Parses and matches email sender patterns. Pure and unit-tested — no networking, no
/// Gmail API types — so both the editor's live validation and `GmailPollingService`'s
/// routing can share one implementation.
enum SenderMatcher {

    /// Normalizes free-form input into a lowercase address ("a@b.com") or domain pattern
    /// ("@domain.com"), handling "Name <a@B.com>", "a@B.com", "@Domain.com" and bare
    /// addresses. Returns nil for anything without an "@" or with whitespace inside the
    /// address part — those aren't a usable sender pattern.
    static func normalize(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // "@Domain.com" — a domain-suffix pattern, not a full address.
        if trimmed.hasPrefix("@") {
            let domain = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
            guard !domain.isEmpty, !domain.contains(where: { $0.isWhitespace }) else { return nil }
            return "@" + domain.lowercased()
        }

        // "Name <a@b.com>" (or `"Quoted, Name" <a@b.com>`) — pull the address out of the brackets.
        let address: String
        if let ltIndex = trimmed.firstIndex(of: "<"),
           let gtIndex = trimmed.lastIndex(of: ">"),
           ltIndex < gtIndex {
            address = String(trimmed[trimmed.index(after: ltIndex)..<gtIndex]).trimmingCharacters(in: .whitespaces)
        } else {
            address = trimmed
        }

        guard address.contains("@"), !address.contains(where: { $0.isWhitespace }) else { return nil }
        let parts = address.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else { return nil }

        return address.lowercased()
    }

    /// Splits an RFC 5322 From header into (name, address). A bare address with no angle
    /// brackets yields an empty name. A quoted name (which may itself contain a comma, e.g.
    /// `"Doe, Jane"`) has its surrounding quotes stripped; anything else — including an
    /// RFC 2047 encoded-word name — is left exactly as written, since decoding it isn't
    /// needed for sender matching or display.
    static func parse(fromHeader: String) -> (name: String, address: String) {
        let trimmed = fromHeader.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let ltIndex = trimmed.firstIndex(of: "<"),
              let gtIndex = trimmed.lastIndex(of: ">"),
              ltIndex < gtIndex else {
            return ("", trimmed)
        }

        var name = String(trimmed[trimmed.startIndex..<ltIndex]).trimmingCharacters(in: .whitespaces)
        if name.hasPrefix("\""), name.hasSuffix("\""), name.count >= 2 {
            name = String(name.dropFirst().dropLast())
        }
        let address = String(trimmed[trimmed.index(after: ltIndex)..<gtIndex]).trimmingCharacters(in: .whitespaces)
        return (name, address)
    }

    /// Exact (case-insensitive) or domain-suffix match. A domain pattern must match the
    /// whole domain — "@x.com" matches "a@x.com" but not "a@notx.com" — which the "@" +
    /// domain suffix check guarantees: the character right before the domain has to be the
    /// address's own "@", not part of another domain label.
    static func matches(address: String, patterns: [String]) -> Bool {
        let addr = address.lowercased()
        for pattern in patterns {
            let p = pattern.lowercased()
            if p.hasPrefix("@") {
                if addr.hasSuffix(p) { return true }
            } else if addr == p {
                return true
            }
        }
        return false
    }

    /// Splits pasted text on commas, semicolons, whitespace and newlines, normalizes each
    /// piece, drops anything invalid, and dedupes while preserving the first occurrence's
    /// position — so re-pasting a list with an accidental repeat doesn't create a duplicate
    /// sender row.
    static func split(_ text: String) -> [String] {
        let separators = CharacterSet(charactersIn: ",;").union(.whitespacesAndNewlines)
        let pieces = text.components(separatedBy: separators).filter { !$0.isEmpty }

        var seen = Set<String>()
        var result: [String] = []
        for piece in pieces {
            guard let normalized = normalize(piece), !seen.contains(normalized) else { continue }
            seen.insert(normalized)
            result.append(normalized)
        }
        return result
    }

    /// Gmail search query for the baseline lookup (G3). Gmail's `from:` operator has no
    /// documented "@domain" form, so a domain pattern "@b.com" becomes the bare token
    /// "from:b.com" (which over-matches: any address or *name* containing "b.com"), and
    /// exact addresses become "from:a@b.com". Several senders are OR-ed together. Callers
    /// MUST re-check every returned message with `matches(address:patterns:)` before
    /// trusting it — this query is a wide net, not the final filter.
    static func gmailQuery(for senders: [String]) -> String {
        let terms = senders.map { pattern -> String in
            if pattern.hasPrefix("@") {
                return "from:\(pattern.dropFirst())"
            }
            return "from:\(pattern)"
        }
        guard !terms.isEmpty else { return "newer_than:2y" }
        return "(\(terms.joined(separator: " OR "))) newer_than:2y"
    }

    /// Gmail web search URL for the unread mail from `senders`:
    /// `https://mail.google.com/mail/u/N/#search/<encoded "from:(a OR b) is:unread in:inbox">`.
    /// Domain patterns use the same bare "from:b.com" token as `gmailQuery`.
    static func gmailSearchURL(accountIndex: Int, senders: [String]) -> URL? {
        let terms = senders.map { $0.hasPrefix("@") ? String($0.dropFirst()) : $0 }
        guard !terms.isEmpty else { return nil }
        let query = "from:(\(terms.joined(separator: " OR "))) is:unread in:inbox"
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: allowed) else { return nil }
        return URL(string: "https://mail.google.com/mail/u/\(accountIndex)/#search/\(encoded)")
    }
}

/// Formats a message date the way the menu bar and notifications show "when" a match
/// arrived (G2). `now`, `calendar` and `locale` are injectable so tests can pin all three
/// instead of depending on the machine's clock/timezone/locale.
enum EmailTimeFormatter {

    /// "Today 2:14 PM", "Yesterday 2:14 PM", "Sep 24, 2:14 PM" (this year), or
    /// "Sep 24, 2025, 2:14 PM" (older).
    static func received(_ date: Date, now: Date = Date(), calendar: Calendar = .current, locale: Locale = .current) -> String {
        var cal = calendar
        cal.locale = locale

        let timeFormatter = DateFormatter()
        timeFormatter.locale = locale
        timeFormatter.calendar = cal
        timeFormatter.timeZone = cal.timeZone
        timeFormatter.dateFormat = "h:mm a"
        let time = timeFormatter.string(from: date)

        if cal.isDate(date, inSameDayAs: now) {
            return "Today \(time)"
        }
        if let yesterday = cal.date(byAdding: .day, value: -1, to: now), cal.isDate(date, inSameDayAs: yesterday) {
            return "Yesterday \(time)"
        }

        let sameYear = cal.component(.year, from: date) == cal.component(.year, from: now)
        let dayFormatter = DateFormatter()
        dayFormatter.locale = locale
        dayFormatter.calendar = cal
        dayFormatter.timeZone = cal.timeZone
        dayFormatter.dateFormat = sameYear ? "MMM d" : "MMM d, yyyy"
        let day = dayFormatter.string(from: date)

        return "\(day), \(time)"
    }
}
