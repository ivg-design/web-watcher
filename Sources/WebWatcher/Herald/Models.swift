// Vendored from ~/github/herald (Sources/HeraldClient/Models.swift), keep in sync.

import Foundation

public enum HeraldCorner: String, Codable, CaseIterable, Sendable {
    case topRight, topLeft, bottomRight, bottomLeft
}

public struct HeraldCallback: Codable, Equatable, Sendable {
    public var url: String?
    public var payload: JSONValue?
    public init(url: String? = nil, payload: JSONValue? = nil) { self.url = url; self.payload = payload }
}

public struct HeraldButton: Codable, Equatable, Sendable {
    public var label: String
    /// "default" | "destructive" | "cancel"
    public var style: String?
    public var url: String?
    public var command: String?
    public var callback: HeraldCallback?
    public init(label: String, style: String? = nil, url: String? = nil,
                command: String? = nil, callback: HeraldCallback? = nil) {
        self.label = label; self.style = style; self.url = url
        self.command = command; self.callback = callback
    }
}

public struct HeraldReminder: Codable, Equatable, Sendable {
    public var title: String?
    /// ISO 8601
    public var due: String?
    public init(title: String? = nil, due: String? = nil) { self.title = title; self.due = due }
}

public struct HeraldNotification: Codable, Equatable, Sendable {
    public var app: String
    public var id: String?
    public var title: String
    public var subtitle: String?
    public var body: String?
    /// File path, `data:` URI or https URL.
    public var image: String?
    public var url: String?
    public var sound: String?
    public var persistent: Bool?
    public var timeout: Double?
    public var priority: String?
    public var buttons: [HeraldButton]?
    /// Ids of actions the issuer's manifest declares (`HeraldManifest.actionID(at:)`). When the payload sends no
    /// `buttons` (or its alias `actions`), each id here is looked up in the manifest, so the issuer need not
    /// repeat the whole button. `ActionResolver.issuerSource` is the one place that resolves them.
    public var actionIds: [String]?
    public var snooze: Bool?
    public var reminder: HeraldReminder?
    public var metadata: JSONValue?
    /// The stacking key for `bySender` stacking (DESIGN section 9): an email sender, a watched site, a bid id.
    /// Notifications of one app with the same `group` fold into one stacked banner. Absent: the issuer id.
    public var group: String?

    // Presentation (DESIGN section 6). All optional: a notification that sets none of them renders
    // with the app-wide look, and a named `template` supplies defaults for whatever it leaves out
    // (see `TemplateResolver`). A resolved notification carries the final values, so the banner,
    // the composer preview and history previews all read the same fields.
    /// Name of a template saved for `app` (`HeraldTemplate.name`).
    public var template: String?
    public var layout: HeraldLayout?
    /// Hex colour such as `#34C759`.
    public var accentColor: String?
    public var showSubtitle: Bool?
    public var showBody: Bool?
    public var showTimestamp: Bool?
    public var maxBodyLines: Int?

    // Voice (DESIGN section 7.9). `speak` says the text aloud, `audio` plays a voice message (path, `data:` URI
    // or https URL), `presentation` picks banner (default), voice (no banner) or both.
    public var speak: HeraldSpeak?
    public var audio: String?
    public var presentation: HeraldPresentation?

    public init(app: String, id: String? = nil, title: String, subtitle: String? = nil,
                body: String? = nil, image: String? = nil, url: String? = nil,
                sound: String? = nil, persistent: Bool? = nil, timeout: Double? = nil,
                priority: String? = nil, buttons: [HeraldButton]? = nil, snooze: Bool? = nil,
                reminder: HeraldReminder? = nil, metadata: JSONValue? = nil,
                template: String? = nil, layout: HeraldLayout? = nil, accentColor: String? = nil,
                showSubtitle: Bool? = nil, showBody: Bool? = nil, showTimestamp: Bool? = nil,
                maxBodyLines: Int? = nil, actionIds: [String]? = nil, group: String? = nil) {
        self.app = app; self.id = id; self.title = title; self.subtitle = subtitle
        self.body = body; self.image = image; self.url = url; self.sound = sound
        self.persistent = persistent; self.timeout = timeout; self.priority = priority
        self.buttons = buttons; self.actionIds = actionIds; self.snooze = snooze; self.reminder = reminder
        self.metadata = metadata; self.group = group
        self.template = template; self.layout = layout; self.accentColor = accentColor
        self.showSubtitle = showSubtitle; self.showBody = showBody
        self.showTimestamp = showTimestamp; self.maxBodyLines = maxBodyLines
    }
}

public struct HeraldAppDefaults: Codable, Equatable, Sendable {
    public var sound: String?
    public var persistent: Bool?
    public var timeout: Double?
    public var corner: HeraldCorner?
    public init(sound: String? = nil, persistent: Bool? = nil, timeout: Double? = nil, corner: HeraldCorner? = nil) {
        self.sound = sound; self.persistent = persistent; self.timeout = timeout; self.corner = corner
    }
}

public struct HeraldAppRegistration: Codable, Equatable, Sendable {
    public var app: String
    public var appName: String?
    /// File path or `data:image/png;base64,...`
    public var icon: String?
    public var bundleId: String?
    public var callbackURL: String?
    public var allowCommands: Bool?
    public var defaults: HeraldAppDefaults?
    public init(app: String, appName: String? = nil, icon: String? = nil, bundleId: String? = nil,
                callbackURL: String? = nil, allowCommands: Bool? = nil, defaults: HeraldAppDefaults? = nil) {
        self.app = app; self.appName = appName; self.icon = icon; self.bundleId = bundleId
        self.callbackURL = callbackURL; self.allowCommands = allowCommands; self.defaults = defaults
    }
}

/// A delivered notification as stored in history ("full record").
public struct HeraldHistoryItem: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var app: String
    public var notification: HeraldNotification
    public var deliveredAt: Date
    public var dismissedAt: Date?
    /// Label of the button used, "open" for a banner click, "timeout" for auto-dismiss.
    public var actionUsed: String?
    public var snoozedUntil: Date?
    /// Local cached copy of the preview image.
    public var imagePath: String?
    /// The data a grid template binds to, resolved when the notification was delivered (payload fields,
    /// then `metadata`, see `TemplateResolver.fields`). Nil for items delivered before Herald 1.1.
    public var fields: [String: HeraldFieldValue]?
    /// What was spoken or played for this notification (DESIGN section 7.9). Nil when nothing was.
    public var speech: HeraldSpeech?
    public init(id: String, app: String, notification: HeraldNotification, deliveredAt: Date,
                dismissedAt: Date? = nil, actionUsed: String? = nil, snoozedUntil: Date? = nil,
                imagePath: String? = nil, fields: [String: HeraldFieldValue]? = nil) {
        self.id = id; self.app = app; self.notification = notification; self.deliveredAt = deliveredAt
        self.dismissedAt = dismissedAt; self.actionUsed = actionUsed
        self.snoozedUntil = snoozedUntil; self.imagePath = imagePath
        self.fields = fields
    }
}

/// Body POSTed to a callback URL when a `callback` button is pressed.
public struct HeraldCallbackEvent: Codable, Equatable, Sendable {
    public var notificationId: String
    public var app: String
    public var action: String
    public var payload: JSONValue?
    public init(notificationId: String, app: String, action: String, payload: JSONValue? = nil) {
        self.notificationId = notificationId; self.app = app; self.action = action; self.payload = payload
    }
}
