import Foundation

// Two-way actions (DESIGN section 7.3). The issuer sends buttons (payload `buttons` or manifest
// actions); the template, which the user owns, can hide, relabel, restyle and reorder them and add
// actions of its own (a shell command, a script, an Apple Shortcut, a URL, dismiss, snooze).
// `ActionResolver` merges the two into the list a banner shows.

/// What pressing an action does.
public enum HeraldActionKind: String, Codable, CaseIterable, Sendable {
    /// Open `url` (http, https or mailto).
    case url
    /// POST the callback event to the issuing app's callback URL.
    case callback
    /// Run `command` via `/bin/zsh -lc`.
    case command
    /// Run a file under Application Support/Herald/scripts with the notification JSON on stdin.
    case script
    /// Run the Apple Shortcut named `shortcut`.
    case shortcut
    /// Bring an application to the front: `bundleId`, else `path`, else the issuing application (from the
    /// manifest's `appBundleId` / `appPath`, the bundle id it registered with, or the app named `appName`).
    case openApp
    /// Dismiss the banner.
    case dismiss
    /// Snooze the banner for `snoozeMinutes`.
    case snooze
}

/// One action. Exactly the fields its `kind` needs are used; the rest stay nil.
public struct HeraldAction: Codable, Equatable, Identifiable, Sendable {
    /// Stable name that `actionRules[].match` and a component's `actionRef` refer to.
    public var id: String
    public var label: String
    public var kind: HeraldActionKind
    /// `default`, `destructive` or `cancel`.
    public var style: String?
    /// kind url. May contain `{token}` placeholders.
    public var url: String?
    /// kind callback; the issuer's own callback payload.
    public var callback: HeraldCallback?
    /// kind command: a shell command line.
    public var command: String?
    /// kind script: a file name under Application Support/Herald/scripts.
    public var script: String?
    /// kind shortcut: the name of an installed Shortcut (`shortcuts list`).
    public var shortcut: String?
    /// kind shortcut: the text handed to the Shortcut, with `{token}` placeholders. nil hands it the full
    /// merged payload as JSON.
    public var input: String?
    /// kind snooze; nil means `defaultSnoozeMinutes`.
    public var snoozeMinutes: Int?
    /// An SF Symbol (a name or full styling) drawn on this action's button.
    public var symbol: HeraldSymbol?
    /// kind openApp: the bundle identifier of the application to bring to the front (`com.example.App`).
    public var bundleId: String?
    /// kind openApp: the path of the application (`/Applications/Example.app`; `~` is expanded). Used when no
    /// `bundleId` finds an application.
    public var path: String?

    public static let defaultSnoozeMinutes = 15

    public init(id: String, label: String, kind: HeraldActionKind, style: String? = nil, url: String? = nil,
                callback: HeraldCallback? = nil, command: String? = nil, script: String? = nil,
                shortcut: String? = nil, input: String? = nil, snoozeMinutes: Int? = nil, symbol: HeraldSymbol? = nil,
                bundleId: String? = nil, path: String? = nil) {
        self.bundleId = bundleId; self.path = path
        self.id = id; self.label = label; self.kind = kind; self.style = style; self.url = url
        self.callback = callback; self.command = command; self.script = script; self.shortcut = shortcut
        self.input = input; self.snoozeMinutes = snoozeMinutes; self.symbol = symbol
    }

    /// The v1 button an issuer-style action corresponds to (url, callback, command), so the existing button
    /// path can run it. nil for kinds a v1 button cannot express.
    public var legacyButton: HeraldButton? {
        switch kind {
        case .url: return HeraldButton(label: label, style: style, url: url)
        case .command: return HeraldButton(label: label, style: style, command: command)
        case .callback: return HeraldButton(label: label, style: style, callback: callback ?? HeraldCallback())
        case .openApp: return HeraldButton(label: label, style: style, openApp: HeraldOpenApp(bundleId: bundleId, path: path))
        case .script, .shortcut, .dismiss, .snooze: return nil
        }
    }

    /// An action for a v1 button: url, callback, command, otherwise dismiss. `id` defaults to a slug of the label.
    public init(button b: HeraldButton, id: String? = nil) {
        let kind: HeraldActionKind = b.callback != nil ? .callback : b.url != nil ? .url : b.command != nil ? .command
            : b.openApp != nil ? .openApp : .dismiss
        self.init(id: id ?? Self.slug(b.label), label: b.label, kind: kind, style: b.style, url: b.url,
                  callback: b.callback, command: b.command, bundleId: b.openApp?.bundleId, path: b.openApp?.path)
    }

    /// "Mark as Read" becomes "mark-as-read"; a label with no letters or digits becomes "action".
    public static func slug(_ label: String) -> String {
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

    private enum CodingKeys: String, CodingKey {
        case id, label, kind, style, url, callback, command, script, shortcut, input, snoozeMinutes, symbol, bundleId, path
    }

    /// Lenient: `kind` is inferred from the fields that are present when it is omitted, `label` falls back to
    /// `id` and `id` to a slug of the label, so {"label":"Open","url":"https://x"} is a complete action.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let url = try c.decodeIfPresent(String.self, forKey: .url)
        let callback = try c.decodeIfPresent(HeraldCallback.self, forKey: .callback)
        let command = try c.decodeIfPresent(String.self, forKey: .command)
        let script = try c.decodeIfPresent(String.self, forKey: .script)
        let shortcut = try c.decodeIfPresent(String.self, forKey: .shortcut)
        let bundleId = try c.decodeIfPresent(String.self, forKey: .bundleId)
        let path = try c.decodeIfPresent(String.self, forKey: .path)
        let explicitID = try c.decodeIfPresent(String.self, forKey: .id)
        let explicitLabel = try c.decodeIfPresent(String.self, forKey: .label)

        let kind: HeraldActionKind
        if let k = try c.decodeIfPresent(HeraldActionKind.self, forKey: .kind) {
            kind = k
        } else if shortcut != nil { kind = .shortcut }
        else if script != nil { kind = .script }
        else if command != nil { kind = .command }
        else if callback != nil { kind = .callback }
        else if url != nil { kind = .url }
        else if bundleId != nil || path != nil { kind = .openApp }
        else {
            throw DecodingError.keyNotFound(
                CodingKeys.kind,
                .init(codingPath: decoder.codingPath,
                      debugDescription: "an action needs a 'kind' (\(HeraldActionKind.allCases.map(\.rawValue).joined(separator: ", ")))"))
        }

        guard let label = explicitLabel ?? explicitID else {
            throw DecodingError.keyNotFound(
                CodingKeys.label,
                .init(codingPath: decoder.codingPath, debugDescription: "an action needs a 'label'"))
        }
        self.init(id: explicitID ?? Self.slug(label), label: label, kind: kind,
                  style: try c.decodeIfPresent(String.self, forKey: .style), url: url, callback: callback,
                  command: command, script: script, shortcut: shortcut,
                  input: try c.decodeIfPresent(String.self, forKey: .input),
                  snoozeMinutes: try c.decodeIfPresent(Int.self, forKey: .snoozeMinutes),
                  symbol: try c.decodeIfPresent(HeraldSymbol.self, forKey: .symbol),
                  bundleId: bundleId, path: path)
    }
}

/// Where a resolved action came from. Issuer actions need the app's command permission; template actions
/// are the user's own (a template command is confirmed once per template).
public enum HeraldActionOrigin: String, Codable, CaseIterable, Sendable {
    case issuer, template
}

/// An action in the resolved list, with its origin.
public struct HeraldResolvedAction: Equatable, Identifiable, Sendable {
    public var action: HeraldAction
    public var origin: HeraldActionOrigin
    public var id: String { action.id }
    public init(action: HeraldAction, origin: HeraldActionOrigin) { self.action = action; self.origin = origin }
}

/// One template rule over the issuer's actions (DESIGN 7.3). Rules run in order.
///
/// - `match` selects actions by id or label (case-insensitive), or every action with `"*"`.
/// - On the matched actions: `hide: true` removes them; otherwise `relabel` and `style` replace those fields
///   and `position` moves them to that 0-based index (clamped).
/// - `add` appends a new template-owned action (at `position` when the rule has no `match`). An added action
///   whose id already exists replaces that action.
public struct HeraldActionRule: Codable, Equatable, Sendable {
    public var match: String?
    public var hide: Bool?
    public var relabel: String?
    public var style: String?
    public var position: Int?
    public var add: HeraldAction?
    /// Gives the matched actions this SF Symbol (a name or full styling).
    public var symbol: HeraldSymbol?

    public init(match: String? = nil, hide: Bool? = nil, relabel: String? = nil, style: String? = nil,
                position: Int? = nil, add: HeraldAction? = nil, symbol: HeraldSymbol? = nil) {
        self.match = match; self.hide = hide; self.relabel = relabel; self.style = style
        self.position = position; self.add = add; self.symbol = symbol
    }
}

/// Merges issuer actions with template rules.
public enum ActionResolver {
    /// The resolved action list: issuer buttons mapped to actions (url -> url, callback -> callback,
    /// command -> command, nothing -> dismiss), then every rule applied in order. Ids are slugs of the labels
    /// ("Mark as Read" is `mark-as-read`); use the `ids` overload when the issuer declared its own.
    public static func resolve(issuer: [HeraldButton], rules: [HeraldActionRule]) -> [HeraldAction] {
        resolveDetailed(issuer: issuer, ids: nil, rules: rules).map(\.action)
    }

    /// Same, with the issuer's declared action ids (parallel to `issuer`, as `HeraldManifest.actionIDs` is).
    public static func resolve(issuer: [HeraldButton], ids: [String]?, rules: [HeraldActionRule]) -> [HeraldAction] {
        resolveDetailed(issuer: issuer, ids: ids, rules: rules).map(\.action)
    }

    /// The resolved list with each action's origin. Issuer actions keep origin `.issuer` even when a rule
    /// relabels or moves them; actions added by a rule are `.template`. `issuerOrigin` is `.template` when the
    /// "issuer" buttons are really the template's own v1 default `buttons`.
    public static func resolveDetailed(issuer: [HeraldButton], ids: [String]? = nil,
                                       rules: [HeraldActionRule],
                                       issuerOrigin: HeraldActionOrigin = .issuer) -> [HeraldResolvedAction] {
        var taken = Set<String>()
        var list: [HeraldResolvedAction] = []
        for (i, b) in issuer.enumerated() {
            var id = (ids != nil && ids!.indices.contains(i) && !ids![i].isEmpty) ? ids![i] : HeraldAction.slug(b.label)
            if taken.contains(id) {
                let base = id; var n = 2
                while taken.contains("\(base)-\(n)") { n += 1 }
                id = "\(base)-\(n)"
            }
            taken.insert(id)
            list.append(HeraldResolvedAction(action: HeraldAction(button: b, id: id), origin: issuerOrigin))
        }
        return apply(rules, to: list)
    }

    /// For issuer actions that are already `HeraldAction`s (ids explicit).
    public static func resolveDetailed(issuerActions: [HeraldAction], rules: [HeraldActionRule]) -> [HeraldResolvedAction] {
        apply(rules, to: issuerActions.map { HeraldResolvedAction(action: $0, origin: .issuer) })
    }

    /// For issuer actions that already carry their origin (a template's default buttons are `.template`).
    public static func resolveDetailed(issuerResolved: [HeraldResolvedAction], rules: [HeraldActionRule]) -> [HeraldResolvedAction] {
        apply(rules, to: issuerResolved)
    }

    /// The issuer's buttons for a notification, with their ids: the one place the ways of naming them are
    /// resolved, so a live banner, a preview and the Designer cannot disagree.
    ///
    /// 1. `buttons` (the router folds the payload alias `actions` into it), as sent. An explicit empty array
    ///    means "no buttons".
    /// 2. Otherwise each of `actionIds`, looked up in the manifest by its declared id (unknown ids are skipped).
    /// 3. Otherwise none: the manifest's actions are never shown just because the manifest declares them. A
    ///    sample preview stands in for an issuer that names every declared action (`sampleSource`).
    public static func issuerSource(for n: HeraldNotification, manifest: HeraldManifest?) -> (buttons: [HeraldButton], ids: [String]) {
        if let b = n.buttons { return (b, issuerIDs(for: b, manifest: manifest)) }
        guard let wanted = n.actionIds, let m = manifest else { return ([], []) }
        var buttons: [HeraldButton] = [], ids: [String] = []
        for want in wanted {
            let w = want.trimmingCharacters(in: .whitespaces)
            guard let i = m.actions.indices.first(where: { m.actionID(at: $0).caseInsensitiveCompare(w) == .orderedSame }),
                  !ids.contains(m.actionID(at: i)) else { continue }
            buttons.append(m.actions[i]); ids.append(m.actionID(at: i))
        }
        return (buttons, ids)
    }

    /// What a sample (the manifest's sample data, no real payload) offers: every action the manifest declares.
    public static func sampleSource(manifest: HeraldManifest?) -> (buttons: [HeraldButton], ids: [String]) {
        guard let m = manifest else { return ([], []) }
        return (m.actions, m.actions.indices.map { m.actionID(at: $0) })
    }

    /// The notification with `actionIds` turned into `buttons` (when it sent no buttons of its own), so history
    /// and every later press see what was offered at delivery even if the manifest changes afterwards.
    public static func materializingActionIDs(_ n: HeraldNotification, manifest: HeraldManifest?) -> HeraldNotification {
        guard n.buttons == nil, n.actionIds != nil else { return n }
        var out = n
        out.buttons = issuerSource(for: n, manifest: manifest).buttons
        return out
    }

    /// The declared ids for a notification's own `buttons`: a button whose label matches a manifest action
    /// takes that action's declared id (so a rule can say `"match":"markRead"`), others get nil here and a
    /// label slug in `resolve`.
    public static func issuerIDs(for buttons: [HeraldButton], manifest: HeraldManifest?) -> [String] {
        buttons.map { b in
            guard let m = manifest,
                  let i = m.actions.firstIndex(where: { $0.label.caseInsensitiveCompare(b.label) == .orderedSame })
            else { return "" }
            return m.actionID(at: i)
        }
    }

    // MARK: Rules

    private static func matches(_ m: String, _ a: HeraldAction) -> Bool {
        if m == "*" { return true }
        return a.id.caseInsensitiveCompare(m) == .orderedSame || a.label.caseInsensitiveCompare(m) == .orderedSame
    }

    private static func apply(_ rules: [HeraldActionRule], to start: [HeraldResolvedAction]) -> [HeraldResolvedAction] {
        var list = start
        for rule in rules {
            let m = rule.match?.trimmingCharacters(in: .whitespaces) ?? ""
            let hasMatch = !m.isEmpty
            if hasMatch {
                let matched = list.indices.filter { matches(m, list[$0].action) }
                if rule.hide == true {
                    let drop = Set(matched)
                    list = list.enumerated().filter { !drop.contains($0.offset) }.map(\.element)
                } else if !matched.isEmpty {
                    for i in matched {
                        if let r = rule.relabel, !r.isEmpty { list[i].action.label = r }
                        if let s = rule.style { list[i].action.style = s.isEmpty ? nil : s }
                        if let sym = rule.symbol { list[i].action.symbol = sym.name.isEmpty ? nil : sym }
                    }
                    if let p = rule.position {
                        let moving = matched.map { list[$0] }
                        let drop = Set(matched)
                        var rest = list.enumerated().filter { !drop.contains($0.offset) }.map(\.element)
                        rest.insert(contentsOf: moving, at: min(max(p, 0), rest.count))
                        list = rest
                    }
                }
            }
            if var add = rule.add {
                if add.id.isEmpty { add.id = HeraldAction.slug(add.label) }
                let entry = HeraldResolvedAction(action: add, origin: .template)
                let requested = hasMatch ? nil : rule.position
                if let existing = list.firstIndex(where: { $0.action.id == add.id }) {
                    list.remove(at: existing)
                    list.insert(entry, at: min(max(requested ?? existing, 0), list.count))
                } else {
                    list.insert(entry, at: min(max(requested ?? list.count, 0), list.count))
                }
            }
        }
        return list
    }

    // MARK: Running an action

    /// The text a shortcut (or script) action hands over: its `input` with `{token}` placeholders filled from
    /// `fields`. nil when the action has no `input`, meaning the caller sends the full merged payload as
    /// JSON (`mergedPayload`). Absent tokens become empty text.
    public static func inputText(for action: HeraldAction, fields: [String: HeraldFieldValue]) -> String? {
        guard let input = action.input, !input.isEmpty else { return nil }
        return TemplateResolver.fill(input, fields: fields)
    }

    /// The JSON every action receives (on stdin for a script, as the Shortcut's input when it has no `input`
    /// text, as the callback payload's context): the full notification, the resolved fields, the
    /// template-authored `extra` key/values, and the action that fired.
    ///
    /// ```
    /// {"app":"…","id":"…","action":{"id":"…","label":"…","kind":"…"},
    ///  "fields":{"title":"…","count":2,"customer.name":"…"},"extra":{"queue":"inbox"},"notification":{…}}
    /// ```
    public static func mergedPayload(notification n: HeraldNotification, fields: [String: HeraldFieldValue],
                                     extra: [String: String], action: HeraldAction?) -> JSONValue {
        var out: [String: JSONValue] = ["app": .string(n.app)]
        if let id = n.id { out["id"] = .string(id) }
        if let a = action {
            out["action"] = .object(["id": .string(a.id), "label": .string(a.label), "kind": .string(a.kind.rawValue)])
        }
        out["fields"] = .object(fields.mapValues(Self.json))
        out["extra"] = .object(extra.mapValues { .string($0) })
        if let data = try? HeraldJSON.encoder().encode(n),
           let v = try? HeraldJSON.decoder().decode(JSONValue.self, from: data) {
            out["notification"] = v
        }
        return .object(out)
    }

    /// A field value as JSON: text, number, bool, or an array of strings.
    public static func json(_ v: HeraldFieldValue) -> JSONValue {
        switch v {
        case .text(let s): return .string(s)
        case .number(let n): return .number(n)
        case .bool(let b): return .bool(b)
        case .list(let l): return .array(l.map { .string($0) })
        }
    }
}
