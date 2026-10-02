import Foundation

// The component half of the v2 grid template (DESIGN section 7.2). A `HeraldCell` (HeraldTemplate.swift)
// holds exactly one `HeraldComponent`. On the wire a component is one flat JSON object with a `type`
// discriminator: {"type":"text","binding":"{title}","style":"title"}.
//
// Every payload struct decodes leniently (missing optional keys take the documented default) and
// encodes only what is set, so hand-written and agent-written templates stay short.

// MARK: - Shared enums

/// What happens to a component whose bindings are all absent (DESIGN 7.2 "collapse").
public enum HeraldEmptyBehavior: String, Codable, CaseIterable, Sendable {
    /// The component disappears; a row or column left with nothing collapses to zero size.
    case collapse
    /// The component stays and its cell keeps its size, blank.
    case keep
}

public enum HeraldTextStyle: String, Codable, CaseIterable, Sendable {
    case title, subtitle, body, caption, mono
}

public enum HeraldFontWeight: String, Codable, CaseIterable, Sendable {
    case regular, medium, semibold, bold
}

public enum HeraldTextAlignment: String, Codable, CaseIterable, Sendable {
    case leading, center, trailing
}

public enum HeraldImageFit: String, Codable, CaseIterable, Sendable {
    /// Whole image visible, letterboxed.
    case fit
    /// Stretched to the cell, distorting it.
    case fill
    /// Fills the cell and crops the overflow (what v1 thumbnails did).
    case cover
}

public enum HeraldIconShape: String, Codable, CaseIterable, Sendable {
    case circle, rounded
}

/// Which actions an `actions` component lists.
public enum HeraldActionSource: String, Codable, CaseIterable, Sendable {
    /// Only what the issuer sent (payload `buttons` / manifest actions), after the template's rules.
    case issuer
    /// Only actions the template adds (`actionRules[].add`).
    case template
    /// Both, in resolved order.
    case merged

    public func includes(_ origin: HeraldActionOrigin) -> Bool {
        switch self {
        case .merged: return true
        case .issuer: return origin == .issuer
        case .template: return origin == .template
        }
    }
}

public enum HeraldActionsLayout: String, Codable, CaseIterable, Sendable {
    /// One line; buttons beyond what fits are cut by `maxVisible`.
    case row
    /// Buttons flow onto further lines (v1 behaviour).
    case wrap
    /// One button per line.
    case stack
}

// MARK: - Payload structs

/// Text bound to fields: `{"type":"text","binding":"{title} - {count}","style":"title","maxLines":2}`.
public struct HeraldTextComponent: Codable, Equatable, Sendable {
    /// Text with `{token}` placeholders. The component is empty when every token is absent.
    public var binding: String
    public var style: HeraldTextStyle
    /// nil lets the style decide.
    public var maxLines: Int?
    /// `#RGB` / `#RRGGBB` / `#RRGGBBAA`, or `accent`, `primary`, `secondary`. nil lets the style decide.
    public var color: String?
    /// Points; nil lets the style decide.
    public var fontSize: Double?
    public var weight: HeraldFontWeight?
    public var alignment: HeraldTextAlignment?
    /// Render inline Markdown (`[text](url)` links). nil means true for style `body`, false otherwise.
    public var markdown: Bool?
    public var emptyBehavior: HeraldEmptyBehavior?

    public var rendersMarkdown: Bool { markdown ?? (style == .body) }

    public init(binding: String, style: HeraldTextStyle = .body, maxLines: Int? = nil, color: String? = nil,
                fontSize: Double? = nil, weight: HeraldFontWeight? = nil, alignment: HeraldTextAlignment? = nil,
                markdown: Bool? = nil, emptyBehavior: HeraldEmptyBehavior? = nil) {
        self.binding = binding; self.style = style; self.maxLines = maxLines; self.color = color
        self.fontSize = fontSize; self.weight = weight; self.alignment = alignment
        self.markdown = markdown; self.emptyBehavior = emptyBehavior
    }

    private enum CodingKeys: String, CodingKey {
        case binding, style, maxLines, color, fontSize, weight, alignment, markdown, emptyBehavior
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(binding: try c.decode(String.self, forKey: .binding),
                  style: try c.decodeIfPresent(HeraldTextStyle.self, forKey: .style) ?? .body,
                  maxLines: try c.decodeIfPresent(Int.self, forKey: .maxLines),
                  color: try c.decodeIfPresent(String.self, forKey: .color),
                  fontSize: try c.decodeIfPresent(Double.self, forKey: .fontSize),
                  weight: try c.decodeIfPresent(HeraldFontWeight.self, forKey: .weight),
                  alignment: try c.decodeIfPresent(HeraldTextAlignment.self, forKey: .alignment),
                  markdown: try c.decodeIfPresent(Bool.self, forKey: .markdown),
                  emptyBehavior: try c.decodeIfPresent(HeraldEmptyBehavior.self, forKey: .emptyBehavior))
    }
}

/// An image: `{"type":"image","binding":"{image}","fit":"cover","cornerRadius":10,"aspectRatio":1}`.
public struct HeraldImageComponent: Codable, Equatable, Sendable {
    /// A file path, `data:` URI or https URL once substituted. Default `{image}`.
    public var binding: String
    public var fit: HeraldImageFit
    public var cornerRadius: Double
    /// Width / height. With a fixed-width column this fixes the height (1 = square, 1.7778 = 16:9).
    public var aspectRatio: Double?
    /// Fixed height in points; wins over `aspectRatio`.
    public var height: Double?
    public var emptyBehavior: HeraldEmptyBehavior?

    public init(binding: String = "{image}", fit: HeraldImageFit = .cover, cornerRadius: Double = 0,
                aspectRatio: Double? = nil, height: Double? = nil, emptyBehavior: HeraldEmptyBehavior? = nil) {
        self.binding = binding; self.fit = fit; self.cornerRadius = cornerRadius
        self.aspectRatio = aspectRatio; self.height = height; self.emptyBehavior = emptyBehavior
    }

    private enum CodingKeys: String, CodingKey { case binding, fit, cornerRadius, aspectRatio, height, emptyBehavior }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(binding: try c.decodeIfPresent(String.self, forKey: .binding) ?? "{image}",
                  fit: try c.decodeIfPresent(HeraldImageFit.self, forKey: .fit) ?? .cover,
                  cornerRadius: try c.decodeIfPresent(Double.self, forKey: .cornerRadius) ?? 0,
                  aspectRatio: try c.decodeIfPresent(Double.self, forKey: .aspectRatio),
                  height: try c.decodeIfPresent(Double.self, forKey: .height),
                  emptyBehavior: try c.decodeIfPresent(HeraldEmptyBehavior.self, forKey: .emptyBehavior))
    }
}

/// The issuing app's icon: `{"type":"issuerIcon","size":22,"shape":"rounded"}`. Never empty.
public struct HeraldIssuerIconComponent: Codable, Equatable, Sendable {
    public var size: Double
    /// nil means 22% of `size` for `rounded`; ignored for `circle`.
    public var cornerRadius: Double?
    public var shape: HeraldIconShape
    public var emptyBehavior: HeraldEmptyBehavior?
    /// An SF Symbol drawn instead of the app's icon (the icon is the fallback when the name is unknown).
    public var symbol: HeraldSymbol?

    public static let defaultSize = 22.0

    public init(size: Double = HeraldIssuerIconComponent.defaultSize, cornerRadius: Double? = nil,
                shape: HeraldIconShape = .rounded, emptyBehavior: HeraldEmptyBehavior? = nil, symbol: HeraldSymbol? = nil) {
        self.size = size; self.cornerRadius = cornerRadius; self.shape = shape; self.emptyBehavior = emptyBehavior
        self.symbol = symbol
    }

    private enum CodingKeys: String, CodingKey { case size, cornerRadius, shape, emptyBehavior, symbol }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(size: try c.decodeIfPresent(Double.self, forKey: .size) ?? Self.defaultSize,
                  cornerRadius: try c.decodeIfPresent(Double.self, forKey: .cornerRadius),
                  shape: try c.decodeIfPresent(HeraldIconShape.self, forKey: .shape) ?? .rounded,
                  emptyBehavior: try c.decodeIfPresent(HeraldEmptyBehavior.self, forKey: .emptyBehavior),
                  symbol: try c.decodeIfPresent(HeraldSymbol.self, forKey: .symbol))
    }
}

/// A date. `binding` names a date field (`{receivedAt}`, ISO 8601 or epoch seconds); when it is nil or blank
/// the banner's own delivery time is shown (what v1 did), so such a timestamp is never empty.
public struct HeraldTimestampComponent: Codable, Equatable, Sendable {
    public var binding: String?
    /// "3 min ago" instead of a clock time.
    public var relative: Bool
    public var style: HeraldTextStyle
    public var color: String?
    public var fontSize: Double?
    public var emptyBehavior: HeraldEmptyBehavior?

    public init(binding: String? = nil, relative: Bool = false, style: HeraldTextStyle = .caption,
                color: String? = nil, fontSize: Double? = nil, emptyBehavior: HeraldEmptyBehavior? = nil) {
        self.binding = binding; self.relative = relative; self.style = style
        self.color = color; self.fontSize = fontSize; self.emptyBehavior = emptyBehavior
    }

    private enum CodingKeys: String, CodingKey { case binding, relative, style, color, fontSize, emptyBehavior }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(binding: try c.decodeIfPresent(String.self, forKey: .binding),
                  relative: try c.decodeIfPresent(Bool.self, forKey: .relative) ?? false,
                  style: try c.decodeIfPresent(HeraldTextStyle.self, forKey: .style) ?? .caption,
                  color: try c.decodeIfPresent(String.self, forKey: .color),
                  fontSize: try c.decodeIfPresent(Double.self, forKey: .fontSize),
                  emptyBehavior: try c.decodeIfPresent(HeraldEmptyBehavior.self, forKey: .emptyBehavior))
    }
}

/// One button. Either an inline `action` (an object, or just a string naming a resolved action's id) or an
/// `actionRef` naming the id of an issuer or template action in the resolved list. A ref to an action that is
/// not in the list (hidden by a rule, or the issuer did not send it) makes the button empty.
public struct HeraldButtonComponent: Codable, Equatable, Sendable {
    public var action: HeraldAction?
    public var actionRef: String?
    /// `default`, `destructive` or `cancel`; overrides the action's own style.
    public var style: String?
    public var emptyBehavior: HeraldEmptyBehavior?
    /// An SF Symbol drawn with the label (a name, or the full styling); an action's own `symbol` wins.
    public var symbol: HeraldSymbol?

    public init(action: HeraldAction? = nil, actionRef: String? = nil, style: String? = nil,
                emptyBehavior: HeraldEmptyBehavior? = nil, symbol: HeraldSymbol? = nil) {
        self.action = action; self.actionRef = actionRef; self.style = style; self.emptyBehavior = emptyBehavior
        self.symbol = symbol
    }

    private enum CodingKeys: String, CodingKey { case action, actionRef, style, emptyBehavior, symbol }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let slot = try ActionSlot.decode(c, action: .action, ref: .actionRef)
        self.init(action: slot.action, actionRef: slot.ref,
                  style: try c.decodeIfPresent(String.self, forKey: .style),
                  emptyBehavior: try c.decodeIfPresent(HeraldEmptyBehavior.self, forKey: .emptyBehavior),
                  symbol: try c.decodeIfPresent(HeraldSymbol.self, forKey: .symbol))
    }
}

/// The action row: every resolved action from `source`, laid out as `layout`.
public struct HeraldActionsComponent: Codable, Equatable, Sendable {
    public var source: HeraldActionSource
    public var layout: HeraldActionsLayout
    /// Most buttons shown; nil shows all. The rest are not shown.
    public var maxVisible: Int?
    public var emptyBehavior: HeraldEmptyBehavior?
    /// A symbol every button of the row gets unless its action has its own `symbol`.
    public var symbol: HeraldSymbol?

    public init(source: HeraldActionSource = .merged, layout: HeraldActionsLayout = .wrap,
                maxVisible: Int? = nil, emptyBehavior: HeraldEmptyBehavior? = nil, symbol: HeraldSymbol? = nil) {
        self.source = source; self.layout = layout; self.maxVisible = maxVisible
        self.emptyBehavior = emptyBehavior; self.symbol = symbol
    }

    private enum CodingKeys: String, CodingKey { case source, layout, maxVisible, emptyBehavior, symbol }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(source: try c.decodeIfPresent(HeraldActionSource.self, forKey: .source) ?? .merged,
                  layout: try c.decodeIfPresent(HeraldActionsLayout.self, forKey: .layout) ?? .wrap,
                  maxVisible: try c.decodeIfPresent(Int.self, forKey: .maxVisible),
                  emptyBehavior: try c.decodeIfPresent(HeraldEmptyBehavior.self, forKey: .emptyBehavior),
                  symbol: try c.decodeIfPresent(HeraldSymbol.self, forKey: .symbol))
    }
}

/// A round icon-only button: `{"type":"iconButton","symbol":"xmark","action":{"kind":"dismiss","label":"Dismiss"}}`.
public struct HeraldIconButtonComponent: Codable, Equatable, Sendable {
    /// An SF Symbol name.
    public var symbol: String
    public var action: HeraldAction?
    public var actionRef: String?
    /// Diameter in points; nil lets the renderer decide (18).
    public var size: Double?
    public var color: String?
    public var tooltip: String?
    public var emptyBehavior: HeraldEmptyBehavior?
    /// The symbol's styling (weight, rendering mode, colours, effect...). On the wire `symbol` is the name, or an
    /// object with a `name`; `symbol` above is always the name.
    public var symbolStyle: HeraldSymbol?

    public init(symbol: String, action: HeraldAction? = nil, actionRef: String? = nil, size: Double? = nil,
                color: String? = nil, tooltip: String? = nil, emptyBehavior: HeraldEmptyBehavior? = nil,
                symbolStyle: HeraldSymbol? = nil) {
        self.symbol = symbol; self.action = action; self.actionRef = actionRef; self.size = size
        self.color = color; self.tooltip = tooltip; self.emptyBehavior = emptyBehavior
        self.symbolStyle = symbolStyle
    }

    /// The name and styling as one value.
    public var fullSymbol: HeraldSymbol {
        var s = symbolStyle ?? HeraldSymbol(name: symbol)
        s.name = symbol
        return s
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(fullSymbol, forKey: .symbol)
        try c.encodeIfPresent(action, forKey: .action)
        try c.encodeIfPresent(actionRef, forKey: .actionRef)
        try c.encodeIfPresent(size, forKey: .size)
        try c.encodeIfPresent(color, forKey: .color)
        try c.encodeIfPresent(tooltip, forKey: .tooltip)
        try c.encodeIfPresent(emptyBehavior, forKey: .emptyBehavior)
    }

    private enum CodingKeys: String, CodingKey {
        case symbol, action, actionRef, size, color, tooltip, emptyBehavior
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let slot = try ActionSlot.decode(c, action: .action, ref: .actionRef)
        let sym = try c.decode(HeraldSymbol.self, forKey: .symbol)
        self.init(symbol: sym.name, action: slot.action, actionRef: slot.ref,
                  size: try c.decodeIfPresent(Double.self, forKey: .size),
                  color: try c.decodeIfPresent(String.self, forKey: .color),
                  tooltip: try c.decodeIfPresent(String.self, forKey: .tooltip),
                  emptyBehavior: try c.decodeIfPresent(HeraldEmptyBehavior.self, forKey: .emptyBehavior),
                  symbolStyle: sym.styled ? sym : nil)
    }
}

/// A small pill with a value, e.g. an unread count: `{"type":"badge","binding":"{count}","color":"#FF3B30"}`.
public struct HeraldBadgeComponent: Codable, Equatable, Sendable {
    public var binding: String
    /// Pill colour: hex or `accent`. nil uses the accent.
    public var color: String?
    /// Text colour: hex or `primary`. nil picks a legible colour for `color`.
    public var textColor: String?
    public var emptyBehavior: HeraldEmptyBehavior?
    /// An SF Symbol drawn before the value.
    public var symbol: HeraldSymbol?

    public init(binding: String, color: String? = nil, textColor: String? = nil,
                emptyBehavior: HeraldEmptyBehavior? = nil, symbol: HeraldSymbol? = nil) {
        self.binding = binding; self.color = color; self.textColor = textColor; self.emptyBehavior = emptyBehavior
        self.symbol = symbol
    }

    private enum CodingKeys: String, CodingKey { case binding, color, textColor, emptyBehavior, symbol }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(binding: try c.decode(String.self, forKey: .binding),
                  color: try c.decodeIfPresent(String.self, forKey: .color),
                  textColor: try c.decodeIfPresent(String.self, forKey: .textColor),
                  emptyBehavior: try c.decodeIfPresent(HeraldEmptyBehavior.self, forKey: .emptyBehavior),
                  symbol: try c.decodeIfPresent(HeraldSymbol.self, forKey: .symbol))
    }
}

/// The stack counter (DESIGN section 9): a pill showing `{stack.count}`, the number of notifications folded into
/// this banner's stack. It has no content (so it collapses, or keeps its blank cell, like any empty component)
/// while the banner is alone, and clicking it expands the stack. A template without one gets the counter at the
/// top right of the stacked card: `{"type":"stackBadge","color":"#FF3B30"}`.
public struct HeraldStackBadgeComponent: Codable, Equatable, Sendable {
    /// What the pill binds to.
    public static let binding = "{stack.count}"
    /// Pill colour: hex or `accent`. nil uses the accent.
    public var color: String?
    /// Text colour: hex or `primary`. nil picks a legible colour for `color`.
    public var textColor: String?
    public var emptyBehavior: HeraldEmptyBehavior?

    public init(color: String? = nil, textColor: String? = nil, emptyBehavior: HeraldEmptyBehavior? = nil) {
        self.color = color; self.textColor = textColor; self.emptyBehavior = emptyBehavior
    }

    private enum CodingKeys: String, CodingKey { case color, textColor, emptyBehavior }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(color: try c.decodeIfPresent(String.self, forKey: .color),
                  textColor: try c.decodeIfPresent(String.self, forKey: .textColor),
                  emptyBehavior: try c.decodeIfPresent(HeraldEmptyBehavior.self, forKey: .emptyBehavior))
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(color, forKey: .color)
        try c.encodeIfPresent(textColor, forKey: .textColor)
        try c.encodeIfPresent(emptyBehavior, forKey: .emptyBehavior)
    }

    /// The pill as a plain badge, which is how it is drawn.
    public var asBadge: HeraldBadgeComponent {
        HeraldBadgeComponent(binding: Self.binding, color: color, textColor: textColor, emptyBehavior: emptyBehavior)
    }
}

/// A progress bar: `{"type":"progress","binding":"{percent}"}`. The bound value is a fraction 0...1, or a
/// percentage when it is greater than 1.
public struct HeraldProgressComponent: Codable, Equatable, Sendable {
    public var binding: String
    public var color: String?
    /// Bar thickness in points; nil lets the renderer decide (4).
    public var height: Double?
    public var emptyBehavior: HeraldEmptyBehavior?

    public init(binding: String, color: String? = nil, height: Double? = nil,
                emptyBehavior: HeraldEmptyBehavior? = nil) {
        self.binding = binding; self.color = color; self.height = height; self.emptyBehavior = emptyBehavior
    }

    private enum CodingKeys: String, CodingKey { case binding, color, height, emptyBehavior }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(binding: try c.decode(String.self, forKey: .binding),
                  color: try c.decodeIfPresent(String.self, forKey: .color),
                  height: try c.decodeIfPresent(Double.self, forKey: .height),
                  emptyBehavior: try c.decodeIfPresent(HeraldEmptyBehavior.self, forKey: .emptyBehavior))
    }
}

/// A Rive animation: `{"type":"rive","asset":"bell","stateMachine":"Main","inputBindings":{"count":"{count}","hover":"hover"}}`.
/// `asset` names a manifest asset; `path` is an explicit .riv file. Each `inputBindings` entry maps a state
/// machine input to a `{token}` (numeric, boolean or trigger by the token's value) or to the keywords
/// `hover` / `pressed`, which the banner's pointer tracking drives.
public struct HeraldRiveComponent: Codable, Equatable, Sendable {
    public var asset: String?
    public var path: String?
    public var stateMachine: String?
    public var artboard: String?
    public var inputBindings: [String: String]
    /// Clicking the animation runs this action.
    public var action: HeraldAction?
    public var actionRef: String?
    /// nil means the animation's own setting.
    public var loop: Bool?
    public var aspectRatio: Double?
    public var height: Double?
    public var emptyBehavior: HeraldEmptyBehavior?

    /// Keywords an input binding may use instead of a `{token}`.
    public static let pointerKeywords = ["hover", "pressed"]

    public init(asset: String? = nil, path: String? = nil, stateMachine: String? = nil, artboard: String? = nil,
                inputBindings: [String: String] = [:], action: HeraldAction? = nil, actionRef: String? = nil,
                loop: Bool? = nil, aspectRatio: Double? = nil, height: Double? = nil,
                emptyBehavior: HeraldEmptyBehavior? = nil) {
        self.asset = asset; self.path = path; self.stateMachine = stateMachine; self.artboard = artboard
        self.inputBindings = inputBindings; self.action = action; self.actionRef = actionRef
        self.loop = loop; self.aspectRatio = aspectRatio; self.height = height
        self.emptyBehavior = emptyBehavior
    }

    private enum CodingKeys: String, CodingKey {
        case asset, path, stateMachine, artboard, inputBindings, action, actionRef, loop
        case aspectRatio, height, emptyBehavior
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let slot = try ActionSlot.decode(c, action: .action, ref: .actionRef)
        self.init(asset: try c.decodeIfPresent(String.self, forKey: .asset),
                  path: try c.decodeIfPresent(String.self, forKey: .path),
                  stateMachine: try c.decodeIfPresent(String.self, forKey: .stateMachine),
                  artboard: try c.decodeIfPresent(String.self, forKey: .artboard),
                  inputBindings: try c.decodeIfPresent([String: String].self, forKey: .inputBindings) ?? [:],
                  action: slot.action, actionRef: slot.ref,
                  loop: try c.decodeIfPresent(Bool.self, forKey: .loop),
                  aspectRatio: try c.decodeIfPresent(Double.self, forKey: .aspectRatio),
                  height: try c.decodeIfPresent(Double.self, forKey: .height),
                  emptyBehavior: try c.decodeIfPresent(HeraldEmptyBehavior.self, forKey: .emptyBehavior))
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(asset, forKey: .asset)
        try c.encodeIfPresent(path, forKey: .path)
        try c.encodeIfPresent(stateMachine, forKey: .stateMachine)
        try c.encodeIfPresent(artboard, forKey: .artboard)
        if !inputBindings.isEmpty { try c.encode(inputBindings, forKey: .inputBindings) }
        try c.encodeIfPresent(action, forKey: .action)
        try c.encodeIfPresent(actionRef, forKey: .actionRef)
        try c.encodeIfPresent(loop, forKey: .loop)
        try c.encodeIfPresent(aspectRatio, forKey: .aspectRatio)
        try c.encodeIfPresent(height, forKey: .height)
        try c.encodeIfPresent(emptyBehavior, forKey: .emptyBehavior)
    }
}

/// `action` may be an inline object or a bare string naming a resolved action's id; both slots are encoded
/// as `action` (object) and `actionRef` (string).
private struct ActionSlot {
    var action: HeraldAction?
    var ref: String?

    static func decode<K: CodingKey>(_ c: KeyedDecodingContainer<K>, action: K, ref: K) throws -> ActionSlot {
        var slot = ActionSlot()
        if let s = try? c.decode(String.self, forKey: action) {
            slot.ref = s
        } else {
            slot.action = try c.decodeIfPresent(HeraldAction.self, forKey: action)
        }
        if let r = try c.decodeIfPresent(String.self, forKey: ref) { slot.ref = r }
        return slot
    }
}

// MARK: - HeraldComponent

/// One cell's content. Encoded as `{"type":"text", ...fields}`; `spacer` has no fields.
public enum HeraldComponent: Codable, Equatable, Sendable {
    case text(HeraldTextComponent)
    case image(HeraldImageComponent)
    case issuerIcon(HeraldIssuerIconComponent)
    case timestamp(HeraldTimestampComponent)
    case button(HeraldButtonComponent)
    case actions(HeraldActionsComponent)
    case iconButton(HeraldIconButtonComponent)
    case badge(HeraldBadgeComponent)
    case stackBadge(HeraldStackBadgeComponent)
    case progress(HeraldProgressComponent)
    case rive(HeraldRiveComponent)
    case spacer

    /// Every `type` string, in the order the schema lists them.
    public static let typeNames = ["text", "image", "issuerIcon", "timestamp", "button", "actions",
                                   "iconButton", "badge", "stackBadge", "progress", "rive", "spacer"]

    private enum Discriminator: String, CodingKey { case type }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Discriminator.self)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "text": self = .text(try HeraldTextComponent(from: decoder))
        case "image": self = .image(try HeraldImageComponent(from: decoder))
        case "issuerIcon": self = .issuerIcon(try HeraldIssuerIconComponent(from: decoder))
        case "timestamp": self = .timestamp(try HeraldTimestampComponent(from: decoder))
        case "button": self = .button(try HeraldButtonComponent(from: decoder))
        case "actions": self = .actions(try HeraldActionsComponent(from: decoder))
        case "iconButton": self = .iconButton(try HeraldIconButtonComponent(from: decoder))
        case "badge": self = .badge(try HeraldBadgeComponent(from: decoder))
        case "stackBadge": self = .stackBadge(try HeraldStackBadgeComponent(from: decoder))
        case "progress": self = .progress(try HeraldProgressComponent(from: decoder))
        case "rive": self = .rive(try HeraldRiveComponent(from: decoder))
        case "spacer": self = .spacer
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: c,
                debugDescription: "unknown component type '\(type)' (one of \(Self.typeNames.joined(separator: ", ")))")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Discriminator.self)
        try c.encode(typeName, forKey: .type)
        switch self {
        case .text(let p): try p.encode(to: encoder)
        case .image(let p): try p.encode(to: encoder)
        case .issuerIcon(let p): try p.encode(to: encoder)
        case .timestamp(let p): try p.encode(to: encoder)
        case .button(let p): try p.encode(to: encoder)
        case .actions(let p): try p.encode(to: encoder)
        case .iconButton(let p): try p.encode(to: encoder)
        case .badge(let p): try p.encode(to: encoder)
        case .stackBadge(let p): try p.encode(to: encoder)
        case .progress(let p): try p.encode(to: encoder)
        case .rive(let p): try p.encode(to: encoder)
        case .spacer: break
        }
    }

    /// The `type` discriminator.
    public var typeName: String {
        switch self {
        case .text: return "text"
        case .image: return "image"
        case .issuerIcon: return "issuerIcon"
        case .timestamp: return "timestamp"
        case .button: return "button"
        case .actions: return "actions"
        case .iconButton: return "iconButton"
        case .badge: return "badge"
        case .stackBadge: return "stackBadge"
        case .progress: return "progress"
        case .rive: return "rive"
        case .spacer: return "spacer"
        }
    }

    /// The component's own empty-behaviour override, if it sets one (always nil for `spacer`).
    public var emptyBehavior: HeraldEmptyBehavior? {
        switch self {
        case .text(let p): return p.emptyBehavior
        case .image(let p): return p.emptyBehavior
        case .issuerIcon(let p): return p.emptyBehavior
        case .timestamp(let p): return p.emptyBehavior
        case .button(let p): return p.emptyBehavior
        case .actions(let p): return p.emptyBehavior
        case .iconButton(let p): return p.emptyBehavior
        case .badge(let p): return p.emptyBehavior
        case .stackBadge(let p): return p.emptyBehavior
        case .progress(let p): return p.emptyBehavior
        case .rive(let p): return p.emptyBehavior
        case .spacer: return nil
        }
    }

    /// The strings whose `{token}` placeholders decide whether the component has content.
    public var bindingStrings: [String] {
        switch self {
        case .text(let p): return [p.binding]
        case .image(let p): return [p.binding]
        case .timestamp(let p): return p.binding.map { [$0] } ?? []
        case .badge(let p): return [p.binding]
        case .stackBadge: return [HeraldStackBadgeComponent.binding]
        case .progress(let p): return [p.binding]
        case .rive(let p): return p.inputBindings.keys.sorted().compactMap { p.inputBindings[$0] }
            .filter { !HeraldRiveComponent.pointerKeywords.contains($0) }
        case .issuerIcon, .button, .actions, .iconButton, .spacer: return []
        }
    }

    /// Every distinct field token the component reads, in order of first appearance: its bindings plus the
    /// `label`, `url` and `input` of an inline action.
    public var referencedTokens: [String] {
        var strings = bindingStrings
        for a in inlineActions { strings += [a.label, a.url, a.input].compactMap { $0 } }
        for sym in symbols + inlineActions.compactMap(\.symbol) { strings += (sym.colors ?? []) + [sym.variableValue].compactMap { $0 } }
        var seen: [String] = []
        for s in strings { for t in TemplateResolver.placeholders(in: s) where !seen.contains(t) { seen.append(t) } }
        return seen
    }

    /// The symbols the component carries itself (inline actions' symbols are checked with the action).
    public var symbols: [HeraldSymbol] {
        var out: [HeraldSymbol] = []
        switch self {
        case .button(let p): if let s = p.symbol { out.append(s) }
        case .actions(let p): if let s = p.symbol { out.append(s) }
        case .issuerIcon(let p): if let s = p.symbol { out.append(s) }
        case .badge(let p): if let s = p.symbol { out.append(s) }
        case .iconButton(let p): out.append(p.fullSymbol)
        default: break
        }
        return out
    }

    /// The inline action(s) the component carries (button, iconButton, rive click).
    public var inlineActions: [HeraldAction] {
        switch self {
        case .button(let p): return p.action.map { [$0] } ?? []
        case .iconButton(let p): return p.action.map { [$0] } ?? []
        case .rive(let p): return p.action.map { [$0] } ?? []
        default: return []
        }
    }

    /// The id of the resolved action the component points at, if it uses a reference.
    public var actionRef: String? {
        switch self {
        case .button(let p): return p.actionRef
        case .iconButton(let p): return p.actionRef
        case .rive(let p): return p.actionRef
        default: return nil
        }
    }

    /// Does the component have something to show? `fields` are the resolved fields of the notification
    /// (`TemplateResolver.fields`, or `sampleFields` for a preview); `actions` the resolved action list
    /// (`ActionResolver.resolveDetailed`). An empty component collapses or keeps its cell according to
    /// `HeraldTemplate.behavior(for:)`.
    ///
    /// text, image, badge, progress: some token present (a binding with no tokens at all counts as present
    /// when it is not blank). timestamp: a blank binding shows the delivery time, so it has content; else
    /// its token must be present. button, iconButton: an inline action always counts; a reference needs that
    /// action in the list. actions: at least one action from its `source`. rive: an `asset` or a `path`.
    /// issuerIcon and spacer always count.
    public func hasContent(fields: [String: HeraldFieldValue], actions: [HeraldResolvedAction]) -> Bool {
        func bound(_ s: String) -> Bool { TemplateResolver.bind(s, fields: fields) != nil }
        switch self {
        case .text(let p): return bound(p.binding)
        case .image(let p): return bound(p.binding)
        case .badge(let p): return bound(p.binding)
        case .stackBadge: return bound(HeraldStackBadgeComponent.binding)
        case .progress(let p): return bound(p.binding)
        case .timestamp(let p):
            guard let b = p.binding, !b.trimmingCharacters(in: .whitespaces).isEmpty else { return true }
            return bound(b)
        case .issuerIcon, .spacer: return true
        case .button(let p): return Self.hasAction(p.action, p.actionRef, in: actions)
        case .iconButton(let p): return Self.hasAction(p.action, p.actionRef, in: actions)
        case .actions(let p): return actions.contains { p.source.includes($0.origin) }
        case .rive(let p):
            return !(p.asset ?? "").isEmpty || !(p.path ?? "").isEmpty
        }
    }

    private static func hasAction(_ inline: HeraldAction?, _ ref: String?, in actions: [HeraldResolvedAction]) -> Bool {
        if inline != nil { return true }
        guard let ref, !ref.isEmpty else { return false }
        return actions.contains { $0.action.id == ref }
    }
}
