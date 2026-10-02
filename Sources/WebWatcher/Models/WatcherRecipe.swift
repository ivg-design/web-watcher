import Foundation

/// The editor form fields the Element Picker Assistant writes into. A plain value type
/// so `WatcherRecipe.apply` stays pure and testable without a live `Watcher` or any
/// SwiftUI binding machinery.
struct WatcherDraftFields: Equatable {
    var name = ""
    var url = ""
    var selector = ""
    var selectorType: SelectorType = .css
    var watchType: WatchType = .badgeNumber
    var badgeAttribute = ""
    var anchorSelector = ""
    var profileId = ""
    var strategy: ProbeStrategy? = nil
    var forceRefresh = false
}

/// What `WatcherRecipe.apply` did to the monitored URL, so the editor can offer "Undo".
struct RecipeOutcome: Equatable {
    var urlChanged: Bool
    var previousURL: String?
}

/// One way a scanned/picked element could be watched, offered on the choice card
/// ("How should WebWatcher watch it?") whenever `watchChoices` returns more than one.
struct WatchChoice: Identifiable, Equatable {
    let id: CandidateStrategy
    let title: String
    let detail: String
    let recommended: Bool
}

/// Turns a picked/scanned `ElementCandidate` into watcher form fields. Pure and
/// unit-tested — no Safari, no AppleScript, no SwiftUI.
enum WatcherRecipe {

    /// Applies `c`'s strategy to `d` in place, returning what happened to the URL.
    ///
    /// `name` is deliberately left untouched: the editor only calls `suggestedName`
    /// when the name field is still empty, so it never clobbers something the user typed.
    static func apply(_ c: ElementCandidate, pageURL: String?, pageTitle: String?, to d: inout WatcherDraftFields) -> RecipeOutcome {
        d.selectorType = .css
        d.profileId = (c.strategy == .title) ? "generic.title" : ""

        switch c.strategy {
        case .badgeText:
            d.selector = c.selector
            d.anchorSelector = c.anchor ?? ""
            d.badgeAttribute = ""
            d.strategy = c.anchor != nil ? .anchoredBadge : nil
            d.watchType = .badgeNumber

        case .badgeAttr:
            d.selector = c.selector
            d.anchorSelector = c.anchor ?? ""
            d.badgeAttribute = c.attr ?? ""
            d.strategy = c.anchor != nil ? .anchoredBadge : nil
            d.watchType = .badgeNumber

        case .ariaCount:
            // The anchor IS the value element: its own accessibility label states the
            // count (and states zero explicitly), so anchor == selector.
            d.selector = c.selector
            d.anchorSelector = c.selector
            d.badgeAttribute = ""
            d.strategy = .ariaCount
            d.watchType = .badgeNumber

        case .autoBadge:
            // G3: the badge node is absent at zero, so there is nothing to point the
            // selector at except the anchor itself.
            let sel = c.anchor ?? c.selector
            d.selector = sel
            d.anchorSelector = sel
            d.badgeAttribute = ""
            d.strategy = .autoBadge
            d.watchType = .badgeNumber

        case .title:
            d.selector = "title"
            d.anchorSelector = ""
            d.badgeAttribute = ""
            d.strategy = nil
            d.watchType = .badgeNumber

        case .text:
            d.selector = c.selector
            d.anchorSelector = c.anchor ?? ""
            d.badgeAttribute = ""
            d.strategy = nil
            d.watchType = .textChange

        case .exists:
            d.selector = c.selector
            d.anchorSelector = c.anchor ?? ""
            d.badgeAttribute = ""
            d.strategy = nil
            d.watchType = .elementExists

        case .count:
            d.selector = c.selector
            d.anchorSelector = c.anchor ?? ""
            d.badgeAttribute = ""
            d.strategy = nil
            d.watchType = .elementCount

        case .subtree:
            // G2: watch the whole area, not a single value. The anchor (if any) becomes
            // the anchor selector, same as text/exists/count — there is no badge attribute
            // and no ProbeStrategy (that enum is for the badge-reading strategies only).
            d.selector = c.selector
            d.anchorSelector = c.anchor ?? ""
            d.badgeAttribute = ""
            d.strategy = nil
            d.watchType = .subtreeChange
        }

        // F2/9.4: a badge that isn't pushed live, and a subtree fingerprint that can only
        // be read from a fully loaded DOM, must be re-read from a freshly reloaded tab.
        switch c.strategy {
        case .badgeText, .badgeAttr, .ariaCount, .autoBadge, .subtree:
            d.forceRefresh = true
        case .title, .text, .exists, .count:
            break
        }

        var outcome = RecipeOutcome(urlChanged: false, previousURL: nil)
        if let pageURL {
            let normalized = normalizedPageURL(pageURL)
            if d.url.isEmpty {
                d.url = normalized
            } else if normalized != d.url {
                let previous = d.url
                d.url = normalized
                outcome = RecipeOutcome(urlChanged: true, previousURL: previous)
            }
        }
        return outcome
    }

    /// "<Site> <Thing>" — e.g. "Rive Community Notifications", "Contra Messages".
    static func suggestedName(for c: ElementCandidate, pageURL: String?, pageTitle: String?) -> String {
        "\(siteName(pageURL: pageURL, pageTitle: pageTitle)) \(thingName(for: c))"
    }

    /// Mirrors `Watcher.canConfirmZero` but for a candidate that has not been applied yet,
    /// so the picker can show "zero confirmed by anchor" before the user commits to it.
    static func canConfirmZero(_ c: ElementCandidate) -> Bool {
        switch c.strategy {
        case .ariaCount, .autoBadge, .title, .subtree:
            // A subtree watcher is "conclusive" whenever the element is found — there is
            // no separate zero/non-zero state to confirm, just a fingerprint.
            return true
        case .badgeText, .badgeAttr, .text, .exists, .count:
            return c.anchor != nil
        }
    }

    static func summary(for c: ElementCandidate) -> String {
        let anchor = anchorName(from: c)
        switch c.strategy {
        case .badgeText, .badgeAttr, .ariaCount:
            let value = c.value ?? ""
            let place = anchor.map { " inside \($0)" } ?? ""
            let zero = canConfirmZero(c) ? "zero confirmed by anchor" : "zero can't be confirmed (no anchor)"
            return "Watching “\(value)”\(place) · \(zero)"

        case .autoBadge:
            let place = anchor.map { " next to \($0)" } ?? ""
            return "Watching for a number\(place) · zero confirmed by anchor"

        case .title:
            return "Watching the (N) in the tab title"

        case .text:
            return "Watching the text “\(c.value ?? "")”"

        case .exists:
            return "Watching whether the element is present"

        case .count:
            return "Watching how many matching elements appear"

        case .subtree:
            let area = anchor ?? c.selector
            return "Watching for any change inside \(area)"
        }
    }

    /// The ways this element can be watched, recommended first (§3.3, amended §9.4).
    static func watchChoices(for c: ElementCandidate) -> [WatchChoice] {
        let subtreeInsideItDetail = "Best for an icon with no counter yet — fires on the first new badge or item, even before anything is visible."
        let existsChoice = WatchChoice(
            id: .exists,
            title: "It appears or disappears",
            detail: "Notify when this element shows up or goes away.",
            recommended: false
        )
        let subtreeInsideItChoice = WatchChoice(
            id: .subtree,
            title: "Anything changes inside it",
            detail: subtreeInsideItDetail,
            recommended: false
        )
        let plainSubtreeChoice = WatchChoice(
            id: .subtree,
            title: "Anything changes inside",
            detail: "Notify on any change inside — not just this reading.",
            recommended: false
        )

        switch c.strategy {
        case .badgeText, .badgeAttr, .ariaCount, .title:
            return [
                WatchChoice(id: c.strategy, title: "Track the number",
                            detail: "Notify when the number changes.", recommended: true),
                plainSubtreeChoice
            ]

        case .autoBadge:
            return [
                WatchChoice(id: .autoBadge, title: "A number appears next to it",
                            detail: "Confirmed zero while there is no number", recommended: true),
                subtreeInsideItChoice,
                existsChoice
            ]

        case .text:
            return [
                WatchChoice(id: .text, title: "The text changes",
                            detail: "Notify when the text changes.", recommended: true),
                plainSubtreeChoice
            ]

        case .exists:
            return [
                WatchChoice(id: .exists, title: "It appears or disappears",
                            detail: "Notify when this element shows up or goes away.", recommended: true),
                subtreeInsideItChoice
            ]

        case .count:
            return [
                WatchChoice(id: .count, title: "The count changes",
                            detail: "Notify when the number of matching elements changes.", recommended: true),
                subtreeInsideItChoice
            ]

        case .subtree:
            // Re-scanning/re-picking an already-subtree candidate: nothing to choose
            // between, so `useCandidate` (ui) auto-confirms this single option.
            return [
                WatchChoice(id: .subtree, title: "Anything changes inside",
                            detail: "Notify on any change inside.", recommended: true)
            ]
        }
    }

    /// Same element, different strategy: selector/anchor (the element's identity) are
    /// kept; `value` is cleared since a reading taken under the old strategy no longer
    /// means anything under the new one; `displayValue` follows automatically since it is
    /// computed from `strategy`. `label` is kept as-is — `anchorName(from:)` only reads
    /// the `" inside "`/`"next to "` suffix, so the anchor name it extracts survives the
    /// switch regardless of which strategy produced the label.
    static func candidate(_ c: ElementCandidate, switchedTo s: CandidateStrategy) -> ElementCandidate {
        guard s != c.strategy else { return c }
        return ElementCandidate(
            selector: c.selector,
            anchor: c.anchor,
            strategy: s,
            attr: c.attr,
            value: nil,
            label: c.label,
            detail: c.detail,
            technical: c.technical,
            tier: c.tier,
            score: c.score,
            inShadow: c.inShadow,
            rect: c.rect
        )
    }

    /// Strips the fragment, keeps the query — the fragment is only ever UI state
    /// (an open tab, a scroll anchor), never part of what page is being monitored.
    static func normalizedPageURL(_ href: String) -> String {
        guard var comps = URLComponents(string: href) else { return href }
        comps.fragment = nil
        return comps.string ?? href
    }

    // MARK: - Naming helpers

    /// Pulls the human-readable anchor name back out of a candidate's `label`, which the
    /// injected JS writes as "<value> · inside <Anchor Name>" (badge strategies) or
    /// "Number next to <Anchor Name>" (autoBadge). Returns nil when the label carries no
    /// anchor name (e.g. no anchor was found).
    private static func anchorName(from c: ElementCandidate) -> String? {
        let markers = [" inside ", "Number next to "]
        for marker in markers {
            if let range = c.label.range(of: marker) {
                let name = String(c.label[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                if !name.isEmpty { return name }
            }
        }
        return nil
    }

    /// "Notifications" stays as-is; Contra's aria-label "Go to Messages" loses its
    /// imperative prefix so the watcher name reads as a noun phrase.
    private static func humanize(_ raw: String) -> String {
        if raw.hasPrefix("Go to ") {
            return String(raw.dropFirst("Go to ".count))
        }
        return raw
    }

    private static func thingName(for c: ElementCandidate) -> String {
        if let anchor = anchorName(from: c) {
            return humanize(anchor)
        }
        switch c.strategy {
        case .badgeText, .badgeAttr, .ariaCount, .autoBadge:
            return "Badge"
        case .text:
            return "Text"
        case .title, .exists, .count:
            return "Element"
        case .subtree:
            return "Area"
        }
    }

    /// Host without `www.`/TLD, title-cased. A host with a subdomain (e.g.
    /// "community.rive.app") prefers "<second-level domain> <subdomain>" (e.g.
    /// "Rive Community") when the page title actually spells that out; otherwise it
    /// falls back to the subdomain alone ("Community") rather than guessing.
    private static func siteName(pageURL: String?, pageTitle: String?) -> String {
        guard let pageURL, let host = URL(string: pageURL)?.host?.lowercased() else {
            return "This Site"
        }
        var labels = host.split(separator: ".").map(String.init)
        if labels.first == "www" { labels.removeFirst() }
        guard !labels.isEmpty else { return "This Site" }

        if labels.count <= 2 {
            return titleCase(labels[0])
        }

        let secondLevelDomain = labels[labels.count - 2]
        let subdomain = labels[0]
        let combined = "\(titleCase(secondLevelDomain)) \(titleCase(subdomain))"
        if let pageTitle, pageTitle.contains(combined) {
            return combined
        }
        return titleCase(subdomain)
    }

    private static func titleCase(_ s: String) -> String {
        guard let first = s.first else { return s }
        return first.uppercased() + s.dropFirst()
    }
}
