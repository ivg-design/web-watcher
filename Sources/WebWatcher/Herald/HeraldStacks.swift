import Foundation

/// One live stack of banners, as `GET /v1/stacks` lists it (DESIGN section 9): the notifications that were folded
/// into one banner with a counter because they share a stacking key.
public struct HeraldStackInfo: Codable, Equatable, Sendable {
    /// One notification in the stack.
    public struct Member: Codable, Equatable, Sendable {
        public var app: String
        public var id: String
        public var title: String
        /// The payload's `group`, when it sent one.
        public var group: String?
        public var deliveredAt: Date

        public init(app: String, id: String, title: String, group: String? = nil, deliveredAt: Date) {
            self.app = app; self.id = id; self.title = title; self.group = group; self.deliveredAt = deliveredAt
        }
    }

    /// `byApp`, `byIssuer` or `bySender`: how the stack's notifications were grouped.
    public var level: String
    /// The issuer id (`byIssuer`, `bySender`) or the product family (`byApp`).
    public var app: String
    /// The `group` that keys the stack (`bySender`): the payload's, or the issuer id when it sent none.
    public var group: String?
    /// Where the stack's panel is on screen, in points (the top card, or the open list); nil when it has none.
    public struct Frame: Codable, Equatable, Sendable {
        public var x: Double
        public var y: Double
        public var width: Double
        public var height: Double
        public init(x: Double, y: Double, width: Double, height: Double) {
            self.x = x; self.y = y; self.width = width; self.height = height
        }
    }

    /// How many notifications are in the stack.
    public var count: Int
    /// The stack is open as a list rather than a stacked card.
    public var expanded: Bool
    /// The stack's notifications, newest first (the first is the card on top).
    public var members: [Member]
    public var frame: Frame?

    public init(level: String, app: String, group: String? = nil, count: Int, expanded: Bool = false, members: [Member],
                frame: Frame? = nil) {
        self.level = level; self.app = app; self.group = group
        self.count = count; self.expanded = expanded; self.members = members; self.frame = frame
    }
}

public extension HeraldHistoryItem {
    /// The stacking group the notification was sent with (`group` in the payload), recorded with every history item.
    var group: String? { notification.group }
}
