import Foundation

// What WebWatcher tells Herald about itself (Herald DESIGN 7.8): two issuers, each with a manifest
// (the fields it sends, the actions it offers, samples for the designer) and a default grid template, so a
// banner can be redesigned in Herald without WebWatcher knowing. Everything here is pure data.

/// The two issuers WebWatcher registers. A notification's `app` is the issuer id, which is how Herald finds
/// the manifest and default template that go with it.
enum HeraldIssuer: String, CaseIterable {
    case web = "webwatcher.web"
    case email = "webwatcher.email"

    var appId: String { rawValue }

    var appName: String {
        switch self {
        case .web: return "WebWatcher · Web"
        case .email: return "WebWatcher · Email"
        }
    }

    /// The template Herald uses when a notification names none (`HeraldManifest.defaultTemplate`).
    var defaultTemplateName: String {
        switch self {
        case .web: return "web-default"
        case .email: return "email-default"
        }
    }

    /// The manifest's field names, in declaration order.
    var fieldKeys: [String] { HeraldManifests.manifest(for: self, icon: nil).fields.map(\.key) }

    static func issuer(forApp app: String) -> HeraldIssuer? { HeraldIssuer(rawValue: app) }
}

enum HeraldManifests {

    // MARK: Manifests

    /// The manifest for `issuer`. `icon` is the exported WebWatcher icon (also the sample for `image`).
    ///
    /// Field notes. `count` is only sent when it means something (a numeric badge or element count for
    /// web, more than one unread message for email), so a count badge collapses when there is nothing to
    /// count. `previous`, `image`, `snippet` and the like are left out when empty, never sent blank.
    /// Actions are declared as callbacks: the buttons themselves are built per notification (they carry
    /// the account, message ids or watcher the click acts on), and Herald matches them to these ids by label.
    static func manifest(for issuer: HeraldIssuer, icon: String?) -> HeraldManifest {
        switch issuer {
        case .web:
            return HeraldManifest(
                app: issuer.appId, appName: issuer.appName, icon: icon, version: 1,
                fields: [
                    HeraldField(key: "title", type: .text, required: true, sample: .text("Inbox")),
                    HeraldField(key: "value", type: .text, sample: .text("3")),
                    HeraldField(key: "previous", type: .text, sample: .text("1")),
                    HeraldField(key: "url", type: .url, sample: .text("https://example.com/inbox")),
                    HeraldField(key: "image", type: .image, sample: icon.map { .text($0) }),
                    HeraldField(key: "watcherName", type: .text, sample: .text("Inbox")),
                    HeraldField(key: "site", type: .text, sample: .text("example.com")),
                    // Beyond the core set: the count behind a badge/element-count watcher, and the two
                    // standard texts, declared so the designer's sample preview has something to show.
                    HeraldField(key: "count", type: .number, sample: .number(3)),
                    HeraldField(key: "subtitle", type: .text, sample: .text("Orders")),
                    HeraldField(key: "body", type: .text, sample: .text("You have 3 new messages")),
                ],
                actions: [
                    callback("Open", style: "default"),
                ],
                actionIDs: ["open"],
                defaultTemplate: issuer.defaultTemplateName, family: "webwatcher")

        case .email:
            return HeraldManifest(
                app: issuer.appId, appName: issuer.appName, icon: icon, version: 1,
                fields: [
                    HeraldField(key: "title", type: .text, required: true, sample: .text("2 new from Acme Billing")),
                    HeraldField(key: "subject", type: .text, sample: .text("Invoice #4021")),
                    HeraldField(key: "sender", type: .text, sample: .text("Acme Billing")),
                    HeraldField(key: "address", type: .text, sample: .text("billing@acme.example")),
                    HeraldField(key: "count", type: .number, sample: .number(2)),
                    HeraldField(key: "receivedAt", type: .date, sample: .text("2026-10-01T14:14:00Z")),
                    HeraldField(key: "image", type: .image, sample: icon.map { .text($0) }),
                    HeraldField(key: "url", type: .url, sample: .text("https://mail.google.com/mail/u/0/#inbox")),
                    HeraldField(key: "snippet", type: .text, sample: .text("Your invoice for September is attached. Payment is due in 14 days.")),
                ],
                actions: [
                    callback("Mark as Read", style: "default"),
                    callback("Archive", style: "destructive"),
                    callback("Delete", style: "destructive"),
                    callback("Spam", style: "destructive"),
                ],
                actionIDs: ["markRead", "archive", "delete", "spam"],
                defaultTemplate: issuer.defaultTemplateName, family: "webwatcher")
        }
    }

    private static func callback(_ label: String, style: String) -> HeraldButton {
        HeraldButton(label: label, style: style, callback: HeraldCallback())
    }

    // MARK: Default templates

    /// The grid template Herald stores for `issuer` when it has none of that name. Both share one skeleton
    /// (4 rows by 4 columns, as the built-in imageLeft look), so a banner reads the same in either:
    ///
    ///     image | title             | icon | close
    ///     image | subtitle (2 cols)        | count
    ///     image | body     (2 cols)        | time
    ///           | actions (3 cols)
    ///
    /// The actions start in the second column, not the first: a cell that spans the image column would keep
    /// it alive, and a banner without a picture (every per-message email) would keep a blank 72 pt strip.
    /// Web binds the notification's title, subtitle and body and badges the count. Email binds the notification's
    /// `{title}` and `{body}` too, so whatever the builders wrote reaches the banner: the user's own title and body
    /// text from the email-watcher editor, the "[Preview] " marker, the bullet list of recent subjects. Its
    /// subtitle is the subject, and it adds the received time and the four Gmail actions. Empty components
    /// collapse: no image column without an image, no badge without a count, no action row without buttons.
    /// The actions are a `wrap` row: one line when the four buttons fit, a second when they do not.
    ///
    /// `legacy` is the email template WebWatcher 1.10 and earlier stored (sender, subject and snippet bindings).
    /// It exists only so `supersededDefaults` can recognise an install that still has that one untouched.
    static func defaultTemplate(for issuer: HeraldIssuer, legacy: Bool = false) -> HeraldTemplate {
        let title: HeraldComponent, subtitle: HeraldComponent, body: HeraldComponent, time: HeraldComponent
        switch issuer {
        case .web:
            title = .text(HeraldTextComponent(binding: "{title}", style: .title, maxLines: 2))
            subtitle = .text(HeraldTextComponent(binding: "{subtitle}", style: .subtitle, maxLines: 2))
            body = .text(HeraldTextComponent(binding: "{body}", style: .body, maxLines: 4, markdown: true))
            time = .timestamp(HeraldTimestampComponent(style: .caption, fontSize: 10))
        case .email where legacy:
            title = .text(HeraldTextComponent(binding: "{sender}", style: .title, maxLines: 1))
            subtitle = .text(HeraldTextComponent(binding: "{subject}", style: .subtitle, maxLines: 2))
            body = .text(HeraldTextComponent(binding: "{snippet}", style: .body, maxLines: 3, markdown: false))
            time = .timestamp(HeraldTimestampComponent(binding: "{receivedAt}", style: .caption, fontSize: 10))
        case .email:
            title = .text(HeraldTextComponent(binding: "{title}", style: .title, maxLines: 2))
            subtitle = .text(HeraldTextComponent(binding: "{subject}", style: .subtitle, maxLines: 2))
            // Up to three subject bullets, the snippet and the received line.
            body = .text(HeraldTextComponent(binding: "{body}", style: .body, maxLines: 5, markdown: false))
            time = .timestamp(HeraldTimestampComponent(binding: "{receivedAt}", style: .caption, fontSize: 10))
        }
        let image = HeraldComponent.image(HeraldImageComponent(binding: "{image}", fit: .cover, cornerRadius: 10, aspectRatio: 1))
        let icon = HeraldComponent.issuerIcon(HeraldIssuerIconComponent(size: 18, cornerRadius: 4, shape: .rounded))
        let close = HeraldComponent.iconButton(HeraldIconButtonComponent(
            symbol: "xmark", action: HeraldAction(id: "dismiss", label: "Dismiss", kind: .dismiss, style: "cancel"),
            size: 18, tooltip: "Dismiss"))
        let badge = HeraldComponent.badge(HeraldBadgeComponent(binding: "{count}"))
        let actions = HeraldComponent.actions(HeraldActionsComponent(source: .merged, layout: .wrap))

        func cell(_ id: String, _ row: Int, _ col: Int, rows: Int = 1, cols: Int = 1,
                  align: HeraldAlign = .topLeading, _ component: HeraldComponent) -> HeraldCell {
            HeraldCell(id: id, row: row, col: col, rowSpan: rows, colSpan: cols, align: align, component: component)
        }
        let grid = HeraldGrid(rows: 4, cols: 4, rowSizes: Array(repeating: .auto, count: 4),
                              colSizes: [.points(72), .fill, .auto, .auto], gap: 6, padding: 12, width: 400)
        let cells = [
            cell("image", 0, 0, rows: 3, image),
            cell("title", 0, 1, title),
            cell("icon", 0, 2, align: .topTrailing, icon),
            cell("close", 0, 3, align: .topTrailing, close),
            cell("subtitle", 1, 1, cols: 2, subtitle),
            cell("count", 1, 3, align: .topTrailing, badge),
            cell("body", 2, 1, cols: 2, body),
            cell("time", 2, 3, align: .topTrailing, time),
            cell("actions", 3, 1, cols: 3, actions),
        ]
        var template = HeraldTemplate(name: issuer.defaultTemplateName, app: issuer.appId, grid: grid, cells: cells)
        template.layout = .imageLeft
        return template
    }

    /// Earlier versions of the default template for `template`'s app and name. Herald keeps a template that is
    /// already stored under a name, so an install that still holds one of these untouched is given the current
    /// one; a template the user changed in Herald matches none of them and is left alone.
    static func supersededDefaults(for template: HeraldTemplate) -> [HeraldTemplate] {
        guard let issuer = HeraldIssuer.issuer(forApp: template.app), template.name == issuer.defaultTemplateName,
              issuer == .email else { return [] }
        return [defaultTemplate(for: issuer, legacy: true)]
    }

    /// Should the stored template (nil when Herald has none under that name) be replaced by `wanted`?
    static func shouldStore(_ wanted: HeraldTemplate, over stored: HeraldTemplate?) -> Bool {
        guard let stored else { return true }
        return stored != wanted && supersededDefaults(for: wanted).contains(stored)
    }
}
