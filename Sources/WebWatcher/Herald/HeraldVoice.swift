import Foundation

/// How a notification is presented (DESIGN section 7.9): the usual banner, speech only (a history entry and
/// no banner), or both.
public enum HeraldPresentation: String, Codable, CaseIterable, Sendable {
    case banner, voice, both
}

/// `speak` on a notification. On the wire it is `true` (speak the title, then the body) or an object
/// `{"text":"…","voice":"af_heart","speed":1.1,"lang":"en-us"}`; every field is optional. `false` is handled by
/// the router (it drops the key), so a decoded `HeraldSpeak` always means "speak".
public struct HeraldSpeak: Codable, Equatable, Sendable {
    /// What to say. Nil means the notification's title, then its body.
    public var text: String?
    public var voice: String?
    /// 0.5 ... 2.0, default 1.0.
    public var speed: Double?
    /// Kokoro language code such as `en-us` or `en-gb`.
    public var lang: String?

    public init(text: String? = nil, voice: String? = nil, speed: Double? = nil, lang: String? = nil) {
        self.text = text; self.voice = voice; self.speed = speed; self.lang = lang
    }

    private enum CodingKeys: String, CodingKey { case text, voice, speed, lang }

    public init(from decoder: Decoder) throws {
        if let single = try? decoder.singleValueContainer() {
            if let flag = try? single.decode(Bool.self) {
                guard flag else {
                    throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                        debugDescription: "speak: false is not an object; omit the field instead"))
                }
                self.init(); return
            }
            if let text = try? single.decode(String.self) { self.init(text: text); return }
        }
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(text: try c.decodeIfPresent(String.self, forKey: .text),
                  voice: try c.decodeIfPresent(String.self, forKey: .voice),
                  speed: try c.decodeIfPresent(Double.self, forKey: .speed),
                  lang: try c.decodeIfPresent(String.self, forKey: .lang))
    }

    public func encode(to encoder: Encoder) throws {
        if text == nil, voice == nil, speed == nil, lang == nil {
            var single = encoder.singleValueContainer()
            try single.encode(true)
            return
        }
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(text, forKey: .text)
        try c.encodeIfPresent(voice, forKey: .voice)
        try c.encodeIfPresent(speed, forKey: .speed)
        try c.encodeIfPresent(lang, forKey: .lang)
    }

    /// Longest text Herald will speak; the rest is dropped.
    public static let maxTextLength = 2_000
    public static let speedRange: ClosedRange<Double> = 0.5...2.0

    /// Collapses markdown links to their label, squeezes whitespace and cuts at `maxTextLength`.
    public static func clean(_ text: String) -> String {
        var s = text
        if let link = try? NSRegularExpression(pattern: #"\[([^\]]*)\]\([^)]*\)"#) {
            s = link.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "$1")
        }
        s = s.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        if s.count > maxTextLength { s = String(s.prefix(maxTextLength)) }
        return s
    }

    /// The text to say for a notification: `text` if given, else title then body.
    public func resolvedText(title: String, body: String?) -> String {
        if let text, !text.trimmingCharacters(in: .whitespaces).isEmpty { return Self.clean(text) }
        let parts = [title, body ?? ""].map { Self.clean($0) }.filter { !$0.isEmpty }
        return Self.clean(parts.map { $0.hasSuffix(".") || $0.hasSuffix("!") || $0.hasSuffix("?") ? $0 : $0 + "." }.joined(separator: " "))
    }

    /// Voice names are model identifiers (`af_heart`); anything else is rejected before it reaches the worker.
    public static func isValidVoice(_ v: String) -> Bool {
        !v.isEmpty && v.count <= 64 && v.allSatisfy { $0.isLetter && $0.isASCII || $0.isNumber && $0.isASCII || $0 == "_" || $0 == "-" || $0 == "." }
    }

    public static func isValidLang(_ l: String) -> Bool {
        !l.isEmpty && l.count <= 16 && l.allSatisfy { $0.isLetter && $0.isASCII || $0 == "-" || $0 == "_" }
    }
}

/// What was spoken for a history entry (DESIGN section 7.9).
public struct HeraldSpeech: Codable, Equatable, Sendable {
    public var text: String
    public var voice: String?
    /// The cached WAV, absent for the system voice (which speaks directly) or when synthesis failed.
    public var audioPath: String?
    public var durationSeconds: Double?
    /// Why the speech was not played: "quiet-hours" (DESIGN section 7.9.1). Nil when it was.
    public var suppressed: String?
    public init(text: String, voice: String? = nil, audioPath: String? = nil, durationSeconds: Double? = nil,
                suppressed: String? = nil) {
        self.text = text; self.voice = voice; self.audioPath = audioPath; self.durationSeconds = durationSeconds
        self.suppressed = suppressed
    }
}

/// `POST /v1/speak`: say `text` aloud for `app`. A shortcut for a notification with presentation `voice`: it
/// leaves a history entry (the text, searchable) and no banner.
public struct HeraldSpeakRequest: Codable, Equatable, Sendable {
    public var app: String
    public var text: String
    public var id: String?
    public var voice: String?
    public var speed: Double?
    public var lang: String?
    public init(app: String, text: String, id: String? = nil, voice: String? = nil, speed: Double? = nil, lang: String? = nil) {
        self.app = app; self.text = text; self.id = id; self.voice = voice; self.speed = speed; self.lang = lang
    }

    /// The notification this request stands for. The title is a short form of the text (history rows show it).
    public func notification() -> HeraldNotification {
        let clean = HeraldSpeak.clean(text)
        let title = clean.count > 80 ? String(clean.prefix(79)) + "\u{2026}" : clean
        var n = HeraldNotification(app: app, id: id, title: title)
        n.speak = HeraldSpeak(text: clean, voice: voice, speed: speed, lang: lang)
        n.presentation = .voice
        return n
    }
}
