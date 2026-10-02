import Foundation
import CoreGraphics

/// Why a probe could not produce an observation.
///
/// The whole point of this type is that "I could not look" is never representable
/// as a number. Anything that used to collapse into `"0"` now lands here instead.
enum CannotReason: String, Codable, CaseIterable {
    // Environment — the user can fix these, and they recur normally.
    case noTab
    case safariClosed
    case notLoaded
    case signedOut
    case challenge
    case anchorMissing
    /// Safari unloaded the tab (its document is `about:blank`) while the AppleScript
    /// `URL of tab` still reports the real URL — a transient suspension, not a dead
    /// selector (F1). WebWatcher reloads the tab in place rather than opening a new one.
    case tabSuspended
    // Configuration — the watcher itself is wrong.
    case selectorMiss
    case badSelector
    // Machinery — our plumbing failed.
    case scriptError
    case timeout
    case permission
    case jsDisabled
    case protocolError

    enum Kind { case environment, configuration, machinery }

    var kind: Kind {
        switch self {
        case .noTab, .safariClosed, .notLoaded, .signedOut, .challenge, .anchorMissing, .tabSuspended:
            return .environment
        case .selectorMiss, .badSelector:
            return .configuration
        case .scriptError, .timeout, .permission, .jsDisabled, .protocolError:
            return .machinery
        }
    }

    /// Short status for the menu row. Must never contain the words "nothing" or "new".
    var shortStatus: String {
        switch self {
        case .noTab:         return "No tab open"
        case .safariClosed:  return "Safari not running"
        case .notLoaded:     return "Page still loading"
        case .signedOut:     return "Signed out"
        case .challenge:     return "Blocked by bot check"
        case .anchorMissing: return "Page not recognized"
        case .tabSuspended:  return "Tab unloaded by Safari"
        case .selectorMiss:  return "Can't confirm — no anchor set"
        case .badSelector:   return "Invalid selector"
        case .scriptError:   return "Check failed"
        case .timeout:       return "Timed out"
        case .permission:    return "Automation permission needed"
        case .jsDisabled:    return "Enable JS from Apple Events"
        case .protocolError: return "Unreadable response"
        }
    }

    /// What the user should actually do about it.
    var remedy: String? {
        switch self {
        case .noTab:         return "Open the page in Safari, or let WebWatcher open it for you."
        case .safariClosed:  return "Launch Safari."
        case .signedOut:     return "Sign in to the site in Safari."
        case .challenge:     return "Open the tab and clear the site's verification prompt."
        case .anchorMissing: return "The page layout changed. Re-pick the anchor element."
        case .tabSuspended:  return "WebWatcher reloads it automatically. If this keeps happening, keep the page in a visible tab."
        case .selectorMiss:  return "Set an anchor so a zero can be confirmed."
        case .badSelector:   return "Fix the selector — the browser rejected it."
        case .permission:    return "Allow WebWatcher to control Safari in Privacy & Security → Automation."
        case .jsDisabled:    return "Enable Safari → Settings → Developer → Allow JavaScript from Apple Events."
        default:             return nil
        }
    }

    /// Multiplier applied to the interval while this reason persists.
    var backoffFactor: Double {
        switch kind {
        case .environment:   return 2.0
        case .configuration: return 4.0
        case .machinery:     return 1.5
        }
    }

    /// Whether repeated occurrences deserve a "this watcher is broken" notification.
    var isWorthEscalating: Bool {
        switch self {
        case .notLoaded, .timeout: return false
        default: return true
        }
    }
}

/// A badge reading, preserving whether the site capped the displayed value ("9+", "99+").
enum BadgeValue: Equatable {
    case exact(Int)
    case atLeast(Int)

    var number: Int {
        switch self {
        case .exact(let n), .atLeast(let n): return n
        }
    }

    var isCapped: Bool {
        if case .atLeast = self { return true }
        return false
    }

    /// Parse a raw badge string. Handles thousands separators and "9+" style caps.
    static func parse(_ raw: String) -> BadgeValue? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let capped = trimmed.contains("+")
        // Keep digits only; drops separators (1,281 / 1.281 / 1 281) and any suffix.
        var digits = ""
        for ch in trimmed {
            if ch.isNumber { digits.append(ch) }
            else if !digits.isEmpty && ch != "," && ch != "." && ch != " " && ch != "\u{00A0}" { break }
        }
        guard let n = Int(digits) else { return nil }
        return capped ? .atLeast(n) : .exact(n)
    }

    /// Should a change from `old` to `new` notify?
    ///
    /// A capped value that stays capped is not news: "9+" to "9+" could be 10 or 500,
    /// but the site is telling us nothing changed that it is willing to show.
    static func shouldNotify(old: BadgeValue?, new: BadgeValue) -> Bool {
        guard let old else { return false } // first conclusive reading is a baseline, never an alert
        switch (old, new) {
        case (.atLeast(let a), .atLeast(let b)):
            return b > a
        case (.exact(let a), .atLeast(let b)):
            return b >= a
        case (.atLeast(let a), .exact(let b)):
            return b > a
        case (.exact(let a), .exact(let b)):
            return b > a
        }
    }

    var display: String {
        switch self {
        case .exact(let n):   return "\(n)"
        case .atLeast(let n): return "\(n)+"
        }
    }
}

/// The result of a single probe. Exactly three shapes, and only two of them are observations.
enum Observation {
    /// A real reading. For badge watchers this is the raw badge text.
    case value(String)
    /// Structurally confirmed zero: the anchor was present and the badge was absent.
    case zero
    /// We could not look. Never a number, never "nothing new".
    case cannot(CannotReason, detail: String?)

    /// The load-bearing accessor: `nil` for `.cannot`, so a non-observation
    /// cannot be fed into a comparison by accident.
    var observedValue: String? {
        switch self {
        case .value(let v): return v
        case .zero:         return "0"
        case .cannot:       return nil
        }
    }

    var isConclusive: Bool { observedValue != nil }

    var cannotReason: CannotReason? {
        if case .cannot(let r, _) = self { return r }
        return nil
    }

    var detail: String? {
        if case .cannot(_, let d) = self { return d }
        return nil
    }
}

/// One step of the Selector Doctor report.
struct DoctorStep: Identifiable {
    let id = UUID()
    let label: String
    let passed: Bool
    let note: String?
}

/// Everything a probe can tell us, including diagnostics when running in test mode.
struct ProbeReport {
    var observation: Observation
    var steps: [DoctorStep] = []
    var suggestedAnchors: [AnchorSuggestion] = []
    var candidates: [ElementCandidate] = []
    var pick: ElementCandidate? = nil
    var pickState: PickState? = nil
    /// "iframe" while the cursor is over an embedded frame during a pick session.
    var note: String? = nil
    var pageTitle: String?
    var matchedURL: String?
    var tabVisible: Bool? = nil
    /// True while the page is still loading (`document.readyState !== 'complete'`),
    /// mirrored from the envelope's `loading` key (§9.2, `locate` mode). The model maps
    /// this to `.checking` and re-locates rather than treating an in-flight load as a
    /// failure.
    var isLoading: Bool? = nil
}

/// How the Element Picker Assistant reads a candidate's current value.
enum CandidateStrategy: String, Codable, CaseIterable {
    case badgeText, badgeAttr, ariaCount, autoBadge, title, text, exists, count
    /// "Anything changes inside" (G2) — a subtree fingerprint rather than a single value.
    case subtree
}

/// State of an in-progress "Pick in Safari" session, mirrored from `window.__ww` in the page.
enum PickState: String {
    case waiting
    /// A click has landed on an element (pick session v2, §3.5/9.2); `pick` carries the
    /// current selection while the user refines it (parent/child/siblings) before
    /// confirming with Enter or "Use this element".
    case selected
    case picked, cancelled, absent
}

/// A ranked candidate produced by "Scan page" or "Pick in Safari": a robust selector,
/// an always-present anchor when one exists, and how to read the value.
struct ElementCandidate: Identifiable, Equatable {
    let id: UUID
    /// Robust selector of the value element (the anchor itself for ariaCount/autoBadge;
    /// the literal string "title" for the document-title strategy).
    let selector: String
    /// Robust selector of the always-present container, nil if none was found.
    let anchor: String?
    let strategy: CandidateStrategy
    /// Attribute name to read when `strategy == .badgeAttr`.
    let attr: String?
    /// Current reading as the probe would return it ("2", "9+", "true", "Feed | Rive").
    let value: String?
    /// "2 · inside Notifications"
    let label: String
    /// Plain language: "Small red circle in the page header, found by its unique name".
    let detail: String
    /// Raw: "data-testid=unread-notifications-count · 16×16 · top 12 px".
    let technical: String
    /// 1 = test id, 2 = accessibility label/id, 3 = link target, 4 = stable class, 5 = positional.
    let tier: Int
    let score: Int
    let inShadow: Bool
    let rect: CGRect

    init(
        selector: String,
        anchor: String? = nil,
        strategy: CandidateStrategy,
        attr: String? = nil,
        value: String? = nil,
        label: String,
        detail: String,
        technical: String,
        tier: Int,
        score: Int,
        inShadow: Bool = false,
        rect: CGRect = .zero
    ) {
        self.id = UUID()
        self.selector = selector
        self.anchor = anchor
        self.strategy = strategy
        self.attr = attr
        self.value = value
        self.label = label
        self.detail = detail
        self.technical = technical
        self.tier = tier
        self.score = score
        self.inShadow = inShadow
        self.rect = rect
    }

    /// `id` is a fresh identity per instance, not part of the candidate's meaning —
    /// two decodes of the same envelope entry must compare equal.
    static func == (a: ElementCandidate, b: ElementCandidate) -> Bool {
        a.selector == b.selector && a.strategy == b.strategy && a.attr == b.attr
    }

    /// Same wording as `AnchorSuggestion.tierName`.
    var tierName: String {
        switch tier {
        case 1: return "Excellent (test id)"
        case 2: return "Good (accessibility label)"
        case 3: return "Good (link target)"
        case 4: return "Fair (id)"
        default: return "Fragile (positional)"
        }
    }

    var isFragile: Bool { tier >= 5 }

    var displayValue: String {
        switch strategy {
        case .autoBadge:
            return "none yet"
        case .subtree:
            return "changes"
        case .title:
            guard let value else { return "—" }
            return "(\(value))"
        default:
            return value ?? "—"
        }
    }
}

/// A ranked candidate for an anchor selector, produced by "Suggest anchor".
struct AnchorSuggestion: Identifiable, Equatable {
    let id = UUID()
    let selector: String
    let label: String
    let tier: Int          // 1 = best (data-testid), 5 = worst (positional)
    let sample: String?

    static func == (a: AnchorSuggestion, b: AnchorSuggestion) -> Bool {
        a.selector == b.selector && a.tier == b.tier
    }

    var tierName: String {
        switch tier {
        case 1: return "Excellent (test id)"
        case 2: return "Good (accessibility label)"
        case 3: return "Good (link target)"
        case 4: return "Fair (id)"
        default: return "Fragile (positional)"
        }
    }

    var isFragile: Bool { tier >= 5 }
}

// MARK: - Wire protocol

/// The JSON envelope the injected JavaScript returns.
///
/// Decoding is deliberately fail-safe: anything unrecognized becomes `.cannot`,
/// never a value and never a zero.
struct ProbeEnvelope: Decodable {
    let status: String
    let value: String?
    let code: String?
    let detail: String?
    let title: String?
    let href: String?
    let steps: [EnvelopeStep]?
    let anchors: [EnvelopeAnchor]?
    let candidates: [EnvelopeCandidate]?
    let pick: EnvelopeCandidate?
    let pickState: String?
    /// "iframe" while the cursor is over an embedded frame during a pick session.
    let note: String?
    /// "live" | "blank" — mirrors `CannotReason.tabSuspended` detection on the JS side.
    let tabState: String?
    let visible: Bool?
    /// `document.readyState !== 'complete'` at the time of the probe (§9.2, `locate` mode).
    let loading: Bool?

    struct EnvelopeStep: Decodable {
        let label: String
        let ok: Bool
        let note: String?
    }

    struct EnvelopeAnchor: Decodable {
        let selector: String
        let label: String
        let tier: Int
        let sample: String?
    }

    struct EnvelopeCandidate: Decodable {
        let selector: String
        let anchor: String?
        let strategy: String
        let attr: String?
        let value: String?
        let label: String
        let detail: String?
        let technical: String?
        let tier: Int
        let score: Int?
        let inShadow: Bool?
        let rect: EnvelopeRect?

        struct EnvelopeRect: Decodable {
            let x: Double
            let y: Double
            let w: Double
            let h: Double
        }
    }

    private enum CodingKeys: String, CodingKey {
        case status, value, code, detail, title, href, steps, anchors
        case candidates, pick, pickState, note, tabState, visible, loading
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = try c.decode(String.self, forKey: .status)
        value = try c.decodeIfPresent(String.self, forKey: .value)
        code = try c.decodeIfPresent(String.self, forKey: .code)
        detail = try c.decodeIfPresent(String.self, forKey: .detail)
        title = try c.decodeIfPresent(String.self, forKey: .title)
        href = try c.decodeIfPresent(String.self, forKey: .href)
        steps = try c.decodeIfPresent([EnvelopeStep].self, forKey: .steps)
        anchors = try c.decodeIfPresent([EnvelopeAnchor].self, forKey: .anchors)
        // Lossy: one malformed candidate must never sink the whole scan/pick result.
        candidates = try c.decodeIfPresent(LossyArray<EnvelopeCandidate>.self, forKey: .candidates)?.elements
        pick = try c.decodeIfPresent(EnvelopeCandidate.self, forKey: .pick)
        pickState = try c.decodeIfPresent(String.self, forKey: .pickState)
        note = try c.decodeIfPresent(String.self, forKey: .note)
        tabState = try c.decodeIfPresent(String.self, forKey: .tabState)
        visible = try c.decodeIfPresent(Bool.self, forKey: .visible)
        loading = try c.decodeIfPresent(Bool.self, forKey: .loading)
    }
}

/// Decodes a JSON array leniently: an entry that fails to decode as `T` is dropped,
/// the rest survive. Without this, one candidate with an unexpected shape would fail
/// the whole envelope and turn a usable scan result into `.protocolError`.
private struct LossyArray<T: Decodable>: Decodable {
    let elements: [T]

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var result: [T] = []
        while !container.isAtEnd {
            // `Wrapper.init` never throws (it captures T's decode failure itself via
            // `try?`), so this call always consumes exactly one array element and
            // advances the cursor — one decode call per entry. A second, "defensive"
            // decode call here would silently consume the NEXT entry instead of
            // retrying this one, which is exactly the bug this type exists to avoid.
            let wrapped = try container.decode(Wrapper.self)
            if let value = wrapped.value {
                result.append(value)
            }
        }
        elements = result
    }

    /// Always succeeds so the outer unkeyed container's cursor advances past a bad
    /// entry instead of getting stuck re-decoding the same index.
    private struct Wrapper: Decodable {
        let value: T?
        init(from decoder: Decoder) throws {
            let single = try decoder.singleValueContainer()
            value = try? single.decode(T.self)
        }
    }
}

private extension ProbeEnvelope.EnvelopeCandidate {
    /// Unknown strategy strings become `.text` rather than failing the candidate.
    func toElementCandidate() -> ElementCandidate {
        let cgRect = rect.map { CGRect(x: $0.x, y: $0.y, width: $0.w, height: $0.h) } ?? .zero
        return ElementCandidate(
            selector: selector,
            anchor: anchor,
            strategy: CandidateStrategy(rawValue: strategy) ?? .text,
            attr: attr,
            value: value,
            label: label,
            detail: detail ?? "",
            technical: technical ?? "",
            tier: tier,
            score: score ?? 0,
            inShadow: inShadow ?? false,
            rect: cgRect
        )
    }
}

enum ProbeEnvelopeParser {
    /// Map a raw `do JavaScript` return into a report.
    ///
    /// `raw` may legitimately be empty: a thrown JS exception, an invalid selector,
    /// a returned DOM node and `undefined` all surface as empty output with no error.
    /// That case must never become an observation.
    static func parse(_ raw: String?) -> ProbeReport {
        guard let raw, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return ProbeReport(observation: .cannot(.protocolError, detail: "empty response"))
        }

        // Legacy sentinel from the older scraper, kept so an in-flight upgrade degrades safely.
        if raw.hasPrefix("ERROR:") {
            return ProbeReport(observation: .cannot(.scriptError, detail: String(raw.dropFirst(6))))
        }

        guard let data = raw.data(using: .utf8),
              let env = try? JSONDecoder().decode(ProbeEnvelope.self, from: data) else {
            return ProbeReport(
                observation: .cannot(.protocolError, detail: String(raw.prefix(120)))
            )
        }

        let observation: Observation
        switch env.status.uppercased() {
        case "OK":
            if let v = env.value {
                observation = .value(v)
            } else if env.candidates != nil || env.pick != nil || env.pickState != nil {
                // Interactive envelopes (scan / pickStart / pickPoll / pickStop) carry
                // their payload in the dedicated fields and have no reading to report.
                // Treating them as a protocol error silently discarded every scan and
                // pick result in 1.6.0/1.7.0 — the assistant looked like it did nothing.
                observation = .value("")
            } else {
                observation = .cannot(.protocolError, detail: "OK without value")
            }
        case "ZERO":
            observation = .zero
        case "MISS", "ERR":
            observation = .cannot(reason(for: env.code), detail: env.detail)
        default:
            observation = .cannot(.protocolError, detail: "unknown status \(env.status)")
        }

        return ProbeReport(
            observation: observation,
            steps: (env.steps ?? []).map { DoctorStep(label: $0.label, passed: $0.ok, note: $0.note) },
            suggestedAnchors: (env.anchors ?? []).map {
                AnchorSuggestion(selector: $0.selector, label: $0.label, tier: $0.tier, sample: $0.sample)
            },
            candidates: (env.candidates ?? []).map { $0.toElementCandidate() },
            pick: env.pick?.toElementCandidate(),
            pickState: env.pickState.flatMap { PickState(rawValue: $0) },
            note: env.note,
            pageTitle: env.title,
            matchedURL: env.href,
            tabVisible: env.visible,
            isLoading: env.loading
        )
    }

    /// Unknown codes deliberately fall through to `.scriptError` rather than a value.
    static func reason(for code: String?) -> CannotReason {
        switch (code ?? "").uppercased() {
        case "NO_TAB":         return .noTab
        case "SAFARI_CLOSED":  return .safariClosed
        case "NOT_LOADED":     return .notLoaded
        case "SIGNED_OUT":     return .signedOut
        case "CHALLENGE":      return .challenge
        case "ANCHOR_MISSING": return .anchorMissing
        case "TAB_BLANK":      return .tabSuspended
        case "NO_MATCH":       return .selectorMiss
        case "BAD_SELECTOR":   return .badSelector
        case "TIMEOUT":        return .timeout
        case "PERMISSION":     return .permission
        case "JS_DISABLED":    return .jsDisabled
        default:               return .scriptError
        }
    }
}
