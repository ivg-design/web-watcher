// Vendored from ~/github/herald (Sources/HeraldClient/JSON.swift), keep in sync.

import Foundation

/// Free-form JSON value used for `metadata` and callback `payload`.
public enum JSONValue: Codable, Equatable, Sendable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let b = try? c.decode(Bool.self) { self = .bool(b) }
        else if let n = try? c.decode(Double.self) { self = .number(n) }
        else if let s = try? c.decode(String.self) { self = .string(s) }
        else if let a = try? c.decode([JSONValue].self) { self = .array(a) }
        else if let o = try? c.decode([String: JSONValue].self) { self = .object(o) }
        else { throw DecodingError.dataCorruptedError(in: c, debugDescription: "Unsupported JSON value") }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let b): try c.encode(b)
        case .number(let n): try c.encode(n)
        case .string(let s): try c.encode(s)
        case .array(let a): try c.encode(a)
        case .object(let o): try c.encode(o)
        }
    }
}

/// Shared JSON coding configuration (ISO 8601 dates).
public enum HeraldJSON {
    public static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        e.dateEncodingStrategy = .custom { date, enc in
            var c = enc.singleValueContainer()
            try c.encode(ISODate.string(from: date))
        }
        return e
    }

    public static func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { dec in
            let c = try dec.singleValueContainer()
            let s = try c.decode(String.self)
            guard let date = ISODate.parse(s) else {
                throw DecodingError.dataCorruptedError(in: c, debugDescription: "Invalid ISO 8601 date: \(s)")
            }
            return date
        }
        return d
    }
}

/// ISO 8601 helpers. `parse` also accepts a zone-less "2026-10-02T09:00" (local time)
/// and a plain "2026-10-02" (09:00 local).
public enum ISODate {
    // ISO8601DateFormatter is thread-safe; sharing avoids a costly allocation per date.
    private static let fractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return f
    }()
    private static let plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime]; return f
    }()

    public static func string(from date: Date) -> String { fractional.string(from: date) }

    public static func parse(_ s: String, calendar: Calendar = .current) -> Date? {
        if let d = fractional.date(from: s) { return d }
        if let d = plain.date(from: s) { return d }
        let local = DateFormatter()
        local.calendar = calendar
        local.timeZone = calendar.timeZone
        local.locale = Locale(identifier: "en_US_POSIX")
        for fmt in ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd'T'HH:mm", "yyyy-MM-dd HH:mm"] {
            local.dateFormat = fmt
            if let d = local.date(from: s) { return d }
        }
        local.dateFormat = "yyyy-MM-dd"
        if let d = local.date(from: s) {
            return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: d)
        }
        return nil
    }
}
