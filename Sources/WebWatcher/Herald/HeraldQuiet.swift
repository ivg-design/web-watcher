import Foundation

// Quiet hours (DESIGN section 7.9.1). The wire/storage types live here so the app, the CLI and the MCP share them;
// the evaluator is Sources/Herald/Voice/QuietHours.swift.

public enum QuietDay {
    /// Canonical day names, Monday first.
    public static let all = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]
    /// "Mon", "monday", "MON" -> "mon"; nil if it is not a day.
    public static func normalize(_ s: String) -> String? {
        let p = s.trimmingCharacters(in: .whitespaces).lowercased().prefix(3)
        return all.contains(String(p)) ? String(p) : nil
    }
    /// Calendar weekday number (1 = Sunday ... 7 = Saturday) for a canonical name.
    public static func weekday(_ name: String) -> Int? {
        guard let i = all.firstIndex(of: name) else { return nil }
        return i == 6 ? 1 : i + 2
    }
}

/// One quiet window: `days` (empty = every day) on which it STARTS at `start` ("HH:MM", local time) and runs until
/// `end`; when `end` is not later than `start` it ends the next morning (an overnight window).
public struct QuietWindow: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var days: [String]
    public var start: String
    public var end: String
    /// What the window silences. Speech is on by default.
    public var speech: Bool
    public var sounds: Bool
    public var banners: Bool
    /// Speak one summary of what was held back when the window ends.
    public var speakSummary: Bool

    public init(id: String = UUID().uuidString, days: [String] = [], start: String = "22:30", end: String = "07:30",
                speech: Bool = true, sounds: Bool = false, banners: Bool = false, speakSummary: Bool = false) {
        self.id = id; self.days = days; self.start = start; self.end = end
        self.speech = speech; self.sounds = sounds; self.banners = banners; self.speakSummary = speakSummary
    }

    private enum CodingKeys: String, CodingKey { case id, days, start, end, speech, sounds, banners, speakSummary }

    public init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        self.init(id: try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString,
                  days: try c.decodeIfPresent([String].self, forKey: .days) ?? [],
                  start: try c.decode(String.self, forKey: .start),
                  end: try c.decode(String.self, forKey: .end),
                  speech: try c.decodeIfPresent(Bool.self, forKey: .speech) ?? true,
                  sounds: try c.decodeIfPresent(Bool.self, forKey: .sounds) ?? false,
                  banners: try c.decodeIfPresent(Bool.self, forKey: .banners) ?? false,
                  speakSummary: try c.decodeIfPresent(Bool.self, forKey: .speakSummary) ?? false)
    }
}

/// "Quiet for an hour": silence until `until` regardless of the schedule.
public struct HeraldQuietAdHoc: Codable, Equatable, Sendable {
    public var until: Date
    public var speech: Bool
    public var sounds: Bool
    public var banners: Bool
    public init(until: Date, speech: Bool = true, sounds: Bool = true, banners: Bool = false) {
        self.until = until; self.speech = speech; self.sounds = sounds; self.banners = banners
    }
}

/// Everything stored for quiet hours.
public struct HeraldQuietHours: Codable, Equatable, Sendable {
    public var windows: [QuietWindow]
    public var adHoc: HeraldQuietAdHoc?
    /// "Resume now": scheduled windows whose current occurrence ends at or before this are ignored.
    public var resumedUntil: Date?
    public init(windows: [QuietWindow] = [], adHoc: HeraldQuietAdHoc? = nil, resumedUntil: Date? = nil) {
        self.windows = windows; self.adHoc = adHoc; self.resumedUntil = resumedUntil
    }
}

/// What is silenced right now.
public struct HeraldQuietStatus: Codable, Equatable, Sendable {
    public var active: Bool
    public var speech: Bool
    public var sounds: Bool
    public var banners: Bool
    /// When the last of the active silences ends.
    public var until: Date?
    /// "window", "adhoc" or "both" while active.
    public var source: String?
    public init(active: Bool = false, speech: Bool = false, sounds: Bool = false, banners: Bool = false,
                until: Date? = nil, source: String? = nil) {
        self.active = active; self.speech = speech; self.sounds = sounds; self.banners = banners
        self.until = until; self.source = source
    }
}

/// `GET/PUT /v1/settings/quiet-hours` reply.
public struct HeraldQuietReply: Codable, Equatable, Sendable {
    public var windows: [QuietWindow]
    public var adHoc: HeraldQuietAdHoc?
    public var status: HeraldQuietStatus
    public init(windows: [QuietWindow], adHoc: HeraldQuietAdHoc?, status: HeraldQuietStatus) {
        self.windows = windows; self.adHoc = adHoc; self.status = status
    }
}

/// `PUT /v1/settings/quiet-hours` body; every field is optional and they apply in this order: `windows`
/// replaces the schedule, `resume` ends the current silence (what `herald quiet off` sends), `adHoc` starts one.
public struct HeraldQuietUpdate: Codable, Equatable, Sendable {
    public struct AdHoc: Codable, Equatable, Sendable {
        /// "HH:MM" (the next time it is that o'clock, local) or an ISO 8601 date.
        public var until: String?
        public var minutes: Double?
        public var speech: Bool?
        public var sounds: Bool?
        public var banners: Bool?
        public init(until: String? = nil, minutes: Double? = nil, speech: Bool? = nil, sounds: Bool? = nil, banners: Bool? = nil) {
            self.until = until; self.minutes = minutes; self.speech = speech; self.sounds = sounds; self.banners = banners
        }
    }
    public var windows: [QuietWindow]?
    public var adHoc: AdHoc?
    public var resume: Bool?
    public init(windows: [QuietWindow]? = nil, adHoc: AdHoc? = nil, resume: Bool? = nil) {
        self.windows = windows; self.adHoc = adHoc; self.resume = resume
    }
}
