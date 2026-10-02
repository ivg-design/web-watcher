import Foundation

/// How a probe extracts a count from a page.
enum ProbeStrategy: String, Codable, CaseIterable {
    /// The count lives in the anchor's own accessibility label, e.g.
    /// `aria-label="Notifications, 4 new notifications"`. Anchor and value are the
    /// same element, so zero is stated explicitly rather than inferred.
    case ariaCount
    /// A stable always-present anchor plus a badge node that exists only when non-zero.
    /// Anchor present + badge absent is a *confirmed* zero.
    case anchoredBadge
    /// The count is in the tab title as a `(3)` prefix. Needs no selector at all,
    /// survives redesigns, and is immune to shadow DOM.
    case documentTitle
    /// The badge node is absent entirely at zero (Circle.so/Rive, Reddit chat), so there
    /// is no fixed badge selector to watch. Instead: anchor present + any short number
    /// found in the anchor's wrapper = the value; anchor present + no number = confirmed
    /// zero. See G3.
    case autoBadge

    var displayName: String {
        switch self {
        case .ariaCount:     return "Accessibility label"
        case .anchoredBadge: return "Anchor + badge"
        case .documentTitle: return "Tab title (N)"
        case .autoBadge:     return "Anchor + any number"
        }
    }

    var explanation: String {
        switch self {
        case .ariaCount:
            return "Reads the number out of the element's accessibility label. Most reliable when the site provides it — zero is stated explicitly."
        case .anchoredBadge:
            return "Watches a badge next to an always-present anchor. If the anchor is there and the badge isn't, that's a confirmed zero."
        case .documentTitle:
            return "Reads the (N) prefix most sites put in the tab title. Needs no selector and survives redesigns."
        case .autoBadge:
            return "Watches for any number that appears next to the anchor. Anchor present with no number is a confirmed zero. Use this when the badge disappears entirely at zero."
        }
    }
}

/// A per-site detection recipe. Deliberately flat: no merge algebra, no condition DSL.
struct SiteProfile: Codable, Identifiable, Equatable {
    var id: String
    var displayName: String
    /// Matched against the tab's host, as a suffix (so `www.` and subdomains match).
    var hostSuffix: String
    /// Canonical page to open when no tab is present.
    var watchURL: String
    var actionURL: String?
    var strategy: ProbeStrategy
    var anchorSelector: String?
    var badgeSelector: String?
    var badgeAttribute: String?
    /// If this selector matches, the user is signed out. Checked only when the anchor is missing.
    var signedOutSelector: String?
    var pierceShadow: Bool
    /// Reloading before reading. Off by default — most modern sites push updates live.
    var needsRefresh: Bool

    init(
        id: String,
        displayName: String,
        hostSuffix: String,
        watchURL: String,
        actionURL: String? = nil,
        strategy: ProbeStrategy,
        anchorSelector: String? = nil,
        badgeSelector: String? = nil,
        badgeAttribute: String? = nil,
        signedOutSelector: String? = nil,
        pierceShadow: Bool = true,
        needsRefresh: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.hostSuffix = hostSuffix
        self.watchURL = watchURL
        self.actionURL = actionURL
        self.strategy = strategy
        self.anchorSelector = anchorSelector
        self.badgeSelector = badgeSelector
        self.badgeAttribute = badgeAttribute
        self.signedOutSelector = signedOutSelector
        self.pierceShadow = pierceShadow
        self.needsRefresh = needsRefresh
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        displayName = try c.decode(String.self, forKey: .displayName)
        hostSuffix = try c.decode(String.self, forKey: .hostSuffix)
        watchURL = try c.decode(String.self, forKey: .watchURL)
        actionURL = try c.decodeIfPresent(String.self, forKey: .actionURL)
        strategy = try c.decodeIfPresent(ProbeStrategy.self, forKey: .strategy) ?? .anchoredBadge
        anchorSelector = try c.decodeIfPresent(String.self, forKey: .anchorSelector)
        badgeSelector = try c.decodeIfPresent(String.self, forKey: .badgeSelector)
        badgeAttribute = try c.decodeIfPresent(String.self, forKey: .badgeAttribute)
        signedOutSelector = try c.decodeIfPresent(String.self, forKey: .signedOutSelector)
        pierceShadow = try c.decodeIfPresent(Bool.self, forKey: .pierceShadow) ?? true
        needsRefresh = try c.decodeIfPresent(Bool.self, forKey: .needsRefresh) ?? false
    }
}

/// Built-in profiles plus user overrides.
///
/// Every built-in below was captured from the live logged-in page, not inferred.
/// Sites that could not be captured get no profile rather than a guess — a wrong
/// built-in fails in a way the user did not author and cannot debug.
@MainActor
final class SiteProfileStore: ObservableObject {
    static let shared = SiteProfileStore()

    @Published private(set) var profiles: [SiteProfile] = []

    private let fileURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folder = appSupport.appendingPathComponent("WebWatcher", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        self.fileURL = folder.appendingPathComponent("site_profiles.json")
        reload()
    }

    /// User overrides replace a built-in with the same id; new ids are appended.
    func reload() {
        var merged = Self.builtIns
        if let data = try? Data(contentsOf: fileURL),
           let overrides = try? JSONDecoder().decode([SiteProfile].self, from: data) {
            for override in overrides {
                if let idx = merged.firstIndex(where: { $0.id == override.id }) {
                    merged[idx] = override
                } else {
                    merged.append(override)
                }
            }
        }
        profiles = merged
    }

    /// Persist a profile as a user override so a broken built-in can be repaired
    /// by editing config, with no app release.
    func saveOverride(_ profile: SiteProfile) {
        var overrides: [SiteProfile] = []
        if let data = try? Data(contentsOf: fileURL),
           let existing = try? JSONDecoder().decode([SiteProfile].self, from: data) {
            overrides = existing
        }
        if let idx = overrides.firstIndex(where: { $0.id == profile.id }) {
            overrides[idx] = profile
        } else {
            overrides.append(profile)
        }
        if let data = try? JSONEncoder().encode(overrides) {
            try? data.write(to: fileURL, options: .atomic)
        }
        reload()
    }

    var overridesFileURL: URL { fileURL }

    /// Profiles whose host matches a URL, best (longest suffix) first.
    func profiles(matching urlString: String) -> [SiteProfile] {
        guard let host = URL(string: urlString)?.host?.lowercased() else { return [] }
        return profiles
            .filter { host == $0.hostSuffix || host.hasSuffix("." + $0.hostSuffix) }
            .sorted { $0.hostSuffix.count > $1.hostSuffix.count }
    }

    func profile(id: String) -> SiteProfile? { profiles.first { $0.id == id } }

    // MARK: - Built-ins (captured live, 2026-07-27)

    static let builtIns: [SiteProfile] = [
        // LinkedIn states the count in the nav link's aria-label, including "0 new
        // notifications" — so zero is explicit and no anchor inference is needed.
        // Verified on /feed/: aria-label="Messaging, 0 new notifications".
        SiteProfile(
            id: "linkedin.messages",
            displayName: "LinkedIn Messages",
            hostSuffix: "linkedin.com",
            watchURL: "https://www.linkedin.com/feed/",
            actionURL: "https://www.linkedin.com/messaging/",
            strategy: .ariaCount,
            anchorSelector: "a[href*=\"/messaging/\"]",
            signedOutSelector: "a[href*=\"/uas/login\"], a[href*=\"/login\"]",
            pierceShadow: false,
            needsRefresh: true
        ),
        SiteProfile(
            id: "linkedin.notifications",
            displayName: "LinkedIn Notifications",
            hostSuffix: "linkedin.com",
            watchURL: "https://www.linkedin.com/feed/",
            actionURL: "https://www.linkedin.com/notifications/",
            strategy: .ariaCount,
            anchorSelector: "a[href*=\"/notifications/\"]",
            signedOutSelector: "a[href*=\"/uas/login\"], a[href*=\"/login\"]",
            pierceShadow: false,
            needsRefresh: true
        ),

        // Circle.so removes the count node entirely at zero, so the always-present
        // bell button is the anchor. Verified: bell + DM buttons present, count node null.
        // needsRefresh: true — F2, hidden tabs do not repaint (rAF paused); measured
        // 2026-09-26 across 11 background Rive tabs reading stale/differing badge values
        // for the same account. A background tab must be reloaded before it is trusted.
        SiteProfile(
            id: "rive.notifications",
            displayName: "Rive Community Notifications",
            hostSuffix: "community.rive.app",
            watchURL: "https://community.rive.app/feed",
            actionURL: "https://community.rive.app/feed",
            strategy: .anchoredBadge,
            anchorSelector: "button[data-testid=\"notifications-menu-popover-button\"]",
            badgeSelector: "[data-testid=\"unread-notifications-count\"]",
            pierceShadow: false,
            needsRefresh: true
        ),
        // needsRefresh: true — F2, hidden tabs do not repaint; measured 2026-09-26.
        SiteProfile(
            id: "rive.messages",
            displayName: "Rive Community Direct Messages",
            hostSuffix: "community.rive.app",
            watchURL: "https://community.rive.app/feed",
            actionURL: "https://community.rive.app/feed",
            strategy: .anchoredBadge,
            anchorSelector: "button[data-testid=\"direct-messages-popover-button\"]",
            badgeSelector: "[data-testid=\"unread-direct-messages-count\"]",
            pierceShadow: false,
            needsRefresh: true
        ),

        // Reddit's header inbox link is a stable id; the count renders as a
        // <faceplate-number number="N"> inside it when non-zero.
        // Reddit's unread indicator is a <dynamic-badge> that is a SIBLING of the header
        // button, not a descendant, so it cannot be scoped to the button. Its
        // `initial-count` attribute is only the page-load value; the live count lives in
        // the element's shadow root, so we deliberately read text rather than the
        // attribute. At zero the element still exists but renders nothing, which the
        // empty-value path already treats as a confirmed zero.
        SiteProfile(
            id: "reddit.inbox",
            displayName: "Reddit Inbox",
            hostSuffix: "reddit.com",
            watchURL: "https://www.reddit.com/",
            actionURL: "https://www.reddit.com/notifications",
            strategy: .anchoredBadge,
            anchorSelector: "#notifications-inbox-button",
            badgeSelector: "[data-id=\"notification-count-element\"]",
            signedOutSelector: "a[href*=\"/login\"]",
            needsRefresh: true
        ),
        SiteProfile(
            id: "reddit.chat",
            displayName: "Reddit Chat",
            hostSuffix: "reddit.com",
            watchURL: "https://www.reddit.com/",
            actionURL: "https://chat.reddit.com/",
            strategy: .anchoredBadge,
            anchorSelector: "#header-action-item-chat-button",
            badgeSelector: "#header-action-item-chat-button-badge",
            signedOutSelector: "a[href*=\"/login\"]",
            needsRefresh: true
        ),

        // Contra's side nav is only rendered on app pages (a public profile page has
        // none), so the canonical watch URL matters as much as the selector here.
        // Counts render as a `number-flow-react` odometer, which keeps every digit in
        // shadow DOM and picks the visible one with a CSS variable — hence the
        // odometer-aware read rather than text scraping.
        SiteProfile(
            id: "contra.messages",
            displayName: "Contra Messages",
            hostSuffix: "contra.com",
            watchURL: "https://contra.com/community/for-you",
            actionURL: "https://contra.com/messages",
            strategy: .anchoredBadge,
            anchorSelector: "a[aria-label=\"Go to Messages\"]",
            badgeSelector: "a[aria-label=\"Go to Messages\"] number-flow-react",
            signedOutSelector: "a[href*=\"/log-in\"]"
        ),
        SiteProfile(
            id: "contra.notifications",
            displayName: "Contra Notifications",
            hostSuffix: "contra.com",
            watchURL: "https://contra.com/community/for-you",
            actionURL: "https://contra.com/community/for-you",
            strategy: .anchoredBadge,
            anchorSelector: "div[aria-label=\"Go to Notifications\"]",
            badgeSelector: "div[aria-label=\"Go to Notifications\"] number-flow-react",
            signedOutSelector: "a[href*=\"/log-in\"]"
        ),

        // Generic fallback: works on any site that puts "(3)" in the tab title.
        SiteProfile(
            id: "generic.title",
            displayName: "Any site — tab title (N)",
            hostSuffix: "",
            watchURL: "",
            strategy: .documentTitle,
            pierceShadow: false
        )
    ]
}
