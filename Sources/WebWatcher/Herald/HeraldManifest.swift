import Foundation

/// What a field of a notification holds. The designer uses it to pick a palette icon and a sensible
/// component (an `image` field offers an image component, a `date` a timestamp, and so on).
public enum HeraldFieldType: String, Codable, CaseIterable, Sendable {
    case text, number, date, url, image, bool, list
}

/// A field value as it travels in a manifest sample or in a resolved notification (`HeraldHistoryItem.fields`):
/// a JSON string, number, boolean or array of strings. Decoding is by JSON type, so it needs no tag.
/// Numbers and booleans inside an array are kept as their text; `null` entries are dropped; a nested
/// array or object is rejected.
public enum HeraldFieldValue: Codable, Equatable, Sendable {
    case text(String)
    case number(Double)
    case bool(Bool)
    case list([String])

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        // Bool before number: JSONDecoder will not read a number as a Bool, nor a Bool as a number.
        if let b = try? c.decode(Bool.self) { self = .bool(b); return }
        if let n = try? c.decode(Double.self) { self = .number(n); return }
        if let s = try? c.decode(String.self) { self = .text(s); return }
        if let items = try? c.decode([JSONValue].self) {
            var out: [String] = []
            for item in items {
                switch item {
                case .string(let s): out.append(s)
                case .number(let n): out.append(Self.format(n))
                case .bool(let b): out.append(b ? "true" : "false")
                case .null: continue
                case .array, .object:
                    throw DecodingError.typeMismatch(
                        HeraldFieldValue.self,
                        .init(codingPath: decoder.codingPath,
                              debugDescription: "list items must be strings, numbers or booleans"))
                }
            }
            self = .list(out)
            return
        }
        throw DecodingError.typeMismatch(
            HeraldFieldValue.self,
            .init(codingPath: decoder.codingPath,
                  debugDescription: "a field value is a string, number, boolean or array of strings"))
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .text(let s): try c.encode(s)
        case .number(let n): try c.encode(n)
        case .bool(let b): try c.encode(b)
        case .list(let l): try c.encode(l)
        }
    }

    /// 2 rather than 2.0 for whole numbers.
    private static func format(_ n: Double) -> String {
        if n == n.rounded(), abs(n) < 1e15 { return String(Int64(n)) }
        return String(n)
    }
}

/// One thing the issuer can send: `key` is the payload name (a top-level key or a `metadata` key) and the
/// token a template binds to (`{key}`). `sample` drives the designer preview.
public struct HeraldField: Codable, Equatable, Sendable {
    public var key: String
    public var type: HeraldFieldType
    public var required: Bool?
    public var sample: HeraldFieldValue?

    public init(key: String, type: HeraldFieldType = .text, required: Bool? = nil, sample: HeraldFieldValue? = nil) {
        self.key = key; self.type = type; self.required = required; self.sample = sample
    }

    private enum CodingKeys: String, CodingKey { case key, type, required, sample }

    /// `type` defaults to text, so `{"key":"subject"}` is a complete field declaration.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        key = try c.decode(String.self, forKey: .key)
        type = try c.decodeIfPresent(HeraldFieldType.self, forKey: .type) ?? .text
        required = try c.decodeIfPresent(Bool.self, forKey: .required)
        sample = try c.decodeIfPresent(HeraldFieldValue.self, forKey: .sample)
    }
}

/// A file the issuer ships for templates to use. Today that is a Rive animation (`type: "rive"`) whose
/// `inputs` name the state machine inputs a `rive` component may bind.
public struct HeraldAsset: Codable, Equatable, Sendable {
    public var id: String
    public var type: String
    public var path: String
    public var stateMachine: String?
    public var inputs: [String]?

    public init(id: String, type: String, path: String, stateMachine: String? = nil, inputs: [String]? = nil) {
        self.id = id; self.type = type; self.path = path; self.stateMachine = stateMachine; self.inputs = inputs
    }
}

/// What an issuer declares about itself (DESIGN section 7.1): the data it can send, the actions it
/// offers and the assets it ships. One per `app`, stored by `ManifestStore`, served by `/v1/manifest`.
///
/// `actions` are the issuer's own buttons and so can only be what `HeraldButton` can express: open a
/// URL, call the issuer back, run a command (the user confirms commands per app as for any payload) or
/// plain dismiss. Script, Shortcuts and snooze actions are authored in templates, by the user.
/// On the wire an action also carries an `id` (what a template's `actionRules` match) and a `kind`;
/// `actionIDs` keeps the ids, parallel to `actions`.
public struct HeraldManifest: Codable, Equatable, Sendable {
    public var app: String
    public var appName: String
    public var icon: String?
    public var version: Int
    public var fields: [HeraldField]
    public var actions: [HeraldButton]
    /// Wire ids of `actions`, same order. Shorter than `actions` only when a caller appended actions
    /// by hand; `actionID(at:)` covers that.
    public var actionIDs: [String]
    public var assets: [HeraldAsset]
    /// Name of the template (of this app) used when a notification names none.
    public var defaultTemplate: String?
    /// The product family this issuer belongs to (`"webwatcher"` for `webwatcher.web` and `webwatcher.email`).
    /// `byApp` stacking (DESIGN section 9) folds every issuer of one family into one stack; without it the issuer
    /// id's prefix before the first dot is the family.
    public var family: String?
    /// The issuing application's bundle identifier and path, so an `openApp` action (and a template's
    /// `onClick: openApp`) can bring it to the front. Both optional; see `HeraldOpenAppResolver` for the order.
    public var appBundleId: String?
    public var appPath: String?

    public init(app: String, appName: String? = nil, icon: String? = nil, version: Int = 1,
                fields: [HeraldField] = [], actions: [HeraldButton] = [], actionIDs: [String]? = nil,
                assets: [HeraldAsset] = [], defaultTemplate: String? = nil, family: String? = nil,
                appBundleId: String? = nil, appPath: String? = nil) {
        self.appBundleId = appBundleId; self.appPath = appPath
        self.app = app; self.appName = appName ?? app; self.icon = icon; self.version = version
        self.fields = fields; self.actions = actions
        self.actionIDs = actionIDs ?? Self.derivedIDs(for: actions)
        self.assets = assets; self.defaultTemplate = defaultTemplate; self.family = family
    }

    /// The id of the action at `index`: the declared one, else one made from its label.
    public func actionID(at index: Int) -> String {
        if actionIDs.indices.contains(index), !actionIDs[index].isEmpty { return actionIDs[index] }
        return Self.slug(actions[index].label)
    }

    /// The field with this key, if declared.
    public func field(_ key: String) -> HeraldField? { fields.first { $0.key == key } }

    // MARK: Coding

    private enum CodingKeys: String, CodingKey {
        case app, appName, icon, version, fields, actions, assets, defaultTemplate, family, appBundleId, appPath
    }

    /// The wire shape of one action.
    private struct ActionWire: Codable {
        var id: String?
        var label: String
        var kind: String?
        var style: String?
        var url: String?
        var command: String?
        var callback: HeraldCallback?
        var bundleId: String?
        var path: String?
        /// kind reply: the field's hint. A `callback` on a reply action also receives the reply.
        var placeholder: String?
    }

    private static let issuerKinds = ["url", "callback", "command", "openApp", "reply", "dismiss"]

    /// Only `app` is required: a bare `{"app":"x"}` is a valid (empty) manifest. `appName` defaults to
    /// the app id, `version` to 1.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let app = try c.decode(String.self, forKey: .app)
        let wires = try c.decodeIfPresent([ActionWire].self, forKey: .actions) ?? []

        var buttons: [HeraldButton] = []
        var ids: [String] = []
        var explicit = Set<String>()
        for (i, w) in wires.enumerated() {
            let path = decoder.codingPath + [CodingKeys.actions, IndexKey(i)]
            if let kind = w.kind, !Self.issuerKinds.contains(kind) {
                let why = ["script", "shortcut", "snooze"].contains(kind)
                    ? "'\(kind)' actions are authored in templates, not declared by an issuer"
                    : "unknown kind '\(kind)'"
                throw DecodingError.dataCorrupted(.init(
                    codingPath: path + [AnyKey("kind")],
                    debugDescription: "\(why) (an issuer action is one of \(Self.issuerKinds.joined(separator: ", ")))"))
            }
            var callback = w.callback
            if w.kind == "callback", callback == nil { callback = HeraldCallback() }   // "call the issuer back" needs no payload
            let open = (w.kind == "openApp" || w.bundleId != nil || w.path != nil) ? HeraldOpenApp(bundleId: w.bundleId, path: w.path) : nil
            var reply: HeraldReply?
            if w.kind == "reply" { reply = HeraldReply(placeholder: w.placeholder, callback: callback); callback = nil }
            buttons.append(HeraldButton(label: w.label, style: w.style, url: w.url, command: w.command, callback: callback, openApp: open,
                                        reply: reply))
            if let id = w.id?.trimmingCharacters(in: .whitespaces), !id.isEmpty {
                guard explicit.insert(id).inserted else {
                    throw DecodingError.dataCorrupted(.init(codingPath: path + [AnyKey("id")],
                                                            debugDescription: "duplicate action id '\(id)'"))
                }
                ids.append(id)
            } else {
                ids.append("")
            }
        }
        // Label-derived ids fill the gaps, kept unique against the declared ones and each other.
        var taken = explicit
        for i in ids.indices where ids[i].isEmpty {
            var candidate = Self.slug(buttons[i].label), n = 2
            let base = candidate
            while taken.contains(candidate) { candidate = "\(base)-\(n)"; n += 1 }
            taken.insert(candidate)
            ids[i] = candidate
        }

        self.init(app: app,
                  appName: try c.decodeIfPresent(String.self, forKey: .appName),
                  icon: try c.decodeIfPresent(String.self, forKey: .icon),
                  version: try c.decodeIfPresent(Int.self, forKey: .version) ?? 1,
                  fields: try c.decodeIfPresent([HeraldField].self, forKey: .fields) ?? [],
                  actions: buttons, actionIDs: ids,
                  assets: try c.decodeIfPresent([HeraldAsset].self, forKey: .assets) ?? [],
                  defaultTemplate: try c.decodeIfPresent(String.self, forKey: .defaultTemplate),
                  family: try c.decodeIfPresent(String.self, forKey: .family),
                  appBundleId: try c.decodeIfPresent(String.self, forKey: .appBundleId),
                  appPath: try c.decodeIfPresent(String.self, forKey: .appPath))
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(app, forKey: .app)
        try c.encode(appName, forKey: .appName)
        try c.encodeIfPresent(icon, forKey: .icon)
        try c.encode(version, forKey: .version)
        try c.encode(fields, forKey: .fields)
        var wires: [ActionWire] = []
        for (i, b) in actions.enumerated() {
            let kind = b.reply != nil ? "reply" : b.callback != nil ? "callback" : b.url != nil ? "url" : b.command != nil ? "command"
                : b.openApp != nil ? "openApp" : "dismiss"
            // A callback that only means "call the issuer back" is written as just its kind.
            let own = b.reply != nil ? b.reply?.callback : b.callback
            let callback = own == HeraldCallback() ? nil : own
            wires.append(ActionWire(id: actionID(at: i), label: b.label, kind: kind, style: b.style,
                                    url: b.url, command: b.command, callback: callback,
                                    bundleId: b.openApp?.bundleId, path: b.openApp?.path, placeholder: b.reply?.placeholder))
        }
        try c.encode(wires, forKey: .actions)
        try c.encode(assets, forKey: .assets)
        try c.encodeIfPresent(defaultTemplate, forKey: .defaultTemplate)
        try c.encodeIfPresent(family, forKey: .family)
        try c.encodeIfPresent(appBundleId, forKey: .appBundleId)
        try c.encodeIfPresent(appPath, forKey: .appPath)
    }

    // MARK: Ids

    private static func derivedIDs(for actions: [HeraldButton]) -> [String] {
        var taken = Set<String>()
        return actions.map { b in
            var candidate = slug(b.label), n = 2
            let base = candidate
            while taken.contains(candidate) { candidate = "\(base)-\(n)"; n += 1 }
            taken.insert(candidate)
            return candidate
        }
    }

    /// "Mark as Read" becomes "mark-as-read".
    static func slug(_ label: String) -> String {
        var out = ""
        var pendingDash = false
        for ch in label.lowercased() {
            if ch.isASCII, ch.isLetter || ch.isNumber {
                if pendingDash, !out.isEmpty { out.append("-") }
                pendingDash = false
                out.append(ch)
            } else {
                pendingDash = true
            }
        }
        return out.isEmpty ? "action" : out
    }
}

/// Coding-path keys for the index of an array element and for a plain name.
private struct IndexKey: CodingKey {
    var intValue: Int?
    var stringValue: String { "\(intValue ?? 0)" }
    init(_ i: Int) { intValue = i }
    init?(intValue: Int) { self.intValue = intValue }
    init?(stringValue: String) { intValue = Int(stringValue) }
}

private struct AnyKey: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }
    init(_ s: String) { stringValue = s }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}

// MARK: Validation

/// Size and shape limits for a manifest. The sender of a manifest is any caller with the token, so a
/// manifest is bounded like a notification is (`PayloadLimits`).
public extension HeraldManifest {
    enum Limits {
        public static let maxAppBytes = 128
        public static let maxFields = 200
        public static let maxKeyBytes = 128
        public static let maxActions = 32
        public static let maxAssets = 32
        public static let maxLabelBytes = 1024
        public static let maxSmallFieldBytes = 2048
        public static let maxIconBytes = 256 * 1024
        public static let maxSampleBytes = 16 * 1024
        public static let maxSampleListItems = 100
    }

    /// Everything wrong with this manifest, one human-readable line each, so an agent can fix them all in
    /// one go. Empty means it may be stored.
    func validationErrors() -> [String] {
        var errors: [String] = []
        func tooBig(_ name: String, _ s: String?, _ limit: Int) {
            if let s, s.utf8.count > limit { errors.append("\(name) is too large (at most \(limit) bytes)") }
        }

        if app.isEmpty { errors.append("app is required") }
        tooBig("app", app, Limits.maxAppBytes)
        tooBig("appName", appName, Limits.maxSmallFieldBytes)
        tooBig("icon", icon, Limits.maxIconBytes)
        tooBig("defaultTemplate", defaultTemplate, Limits.maxSmallFieldBytes)
        tooBig("family", family, Limits.maxSmallFieldBytes)
        if version < 1 { errors.append("version must be 1 or greater") }

        if fields.count > Limits.maxFields { errors.append("too many fields (at most \(Limits.maxFields))") }
        var keys = Set<String>()
        for (i, f) in fields.prefix(Limits.maxFields).enumerated() {
            let at = "fields[\(i)]"
            if !Self.isToken(f.key) {
                errors.append("\(at).key '\(f.key)' must be letters, digits, '_', '.' or '-' (it is the name used as {key} in bindings)")
            } else if f.key.utf8.count > Limits.maxKeyBytes {
                errors.append("\(at).key is too large (at most \(Limits.maxKeyBytes) bytes)")
            }
            if !keys.insert(f.key).inserted { errors.append("\(at).key '\(f.key)' is declared twice") }
            switch f.sample {
            case .text(let s)?: tooBig("\(at).sample", s, Limits.maxSampleBytes)
            case .list(let l)?:
                if l.count > Limits.maxSampleListItems {
                    errors.append("\(at).sample has too many items (at most \(Limits.maxSampleListItems))")
                }
                tooBig("\(at).sample", l.joined(), Limits.maxSampleBytes)
            default: break
            }
        }

        tooBig("appBundleId", appBundleId, Limits.maxSmallFieldBytes)
        tooBig("appPath", appPath, Limits.maxSmallFieldBytes)
        if let b = appBundleId, !b.isEmpty, !Self.isBundleId(b) { errors.append("appBundleId '\(b)' is not a bundle identifier (for example com.example.App)") }
        if let p = appPath, !p.isEmpty, !p.lowercased().hasSuffix(".app") { errors.append("appPath must be an application, ending in .app") }
        if actions.count > Limits.maxActions { errors.append("too many actions (at most \(Limits.maxActions))") }
        var ids = Set<String>()
        for (i, a) in actions.prefix(Limits.maxActions).enumerated() {
            let at = "actions[\(i)]"
            if a.label.isEmpty { errors.append("\(at).label is required") }
            tooBig("\(at).label", a.label, Limits.maxLabelBytes)
            for (name, value) in [("url", a.url), ("command", a.command), ("style", a.style),
                                  ("bundleId", a.openApp?.bundleId), ("path", a.openApp?.path)] {
                tooBig("\(at).\(name)", value, Limits.maxSmallFieldBytes)
            }
            if let style = a.style, !HeraldActionStyle.isAccepted(style) {
                errors.append("\(at).style '\(style)' must be normal, prominent, destructive or cancel")
            }
            let id = actionID(at: i)
            if !ids.insert(id).inserted { errors.append("\(at).id '\(id)' is declared twice") }
        }

        if assets.count > Limits.maxAssets { errors.append("too many assets (at most \(Limits.maxAssets))") }
        var assetIDs = Set<String>()
        for (i, a) in assets.prefix(Limits.maxAssets).enumerated() {
            let at = "assets[\(i)]"
            if !Self.isToken(a.id) { errors.append("\(at).id '\(a.id)' must be letters, digits, '_', '.' or '-'") }
            if !assetIDs.insert(a.id).inserted { errors.append("\(at).id '\(a.id)' is declared twice") }
            if a.type.isEmpty { errors.append("\(at).type is required (for example \"rive\")") }
            if a.path.isEmpty { errors.append("\(at).path is required") }
            tooBig("\(at).path", a.path, Limits.maxSmallFieldBytes)
        }
        return errors
    }

    /// `com.example.App`: dot-separated letters, digits, `-` and `_`, at least two parts.
    static func isBundleId(_ s: String) -> Bool {
        let parts = s.split(separator: ".", omittingEmptySubsequences: false)
        return parts.count >= 2 && parts.allSatisfy { !$0.isEmpty && $0.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") } }
    }

    /// The `{token}` name syntax bindings use.
    static func isToken(_ s: String) -> Bool {
        !s.isEmpty && s.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "." || $0 == "-" }
    }
}
