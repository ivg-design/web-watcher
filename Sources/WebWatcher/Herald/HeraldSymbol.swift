import Foundation
#if canImport(AppKit)
import AppKit
#endif

// SF Symbols on template components (button, iconButton, actions, issuerIcon, badge) and on actions: the name plus
// the symbol's full styling. The wire form is either a plain name ("bell.badge") or an object:
//
//   {"name":"bell.badge","weight":"semibold","scale":"large","placement":"leading",
//    "renderingMode":"palette","colors":["#FF3B30","accent"],"variableValue":"{progress}",
//    "effect":{"kind":"bounce","trigger":"onChange","speed":1.5}}

public enum HeraldSymbolWeight: String, Codable, CaseIterable, Sendable {
    case ultraLight, thin, light, regular, medium, semibold, bold, heavy, black
}

public enum HeraldSymbolScale: String, Codable, CaseIterable, Sendable { case small, medium, large }

/// Where the symbol sits next to a label (`only` drops the label).
public enum HeraldSymbolPlacement: String, Codable, CaseIterable, Sendable { case leading, trailing, only }

public enum HeraldSymbolRenderingMode: String, Codable, CaseIterable, Sendable {
    case monochrome, hierarchical, palette, multicolor
}

public enum HeraldSymbolEffectKind: String, Codable, CaseIterable, Sendable {
    case bounce, pulse, variableColor, scale, appear, disappear, replace
}

public enum HeraldSymbolTrigger: String, Codable, CaseIterable, Sendable {
    case onAppear, onChange, onHover, repeating
}

/// A symbol effect (macOS 14+; ignored on 13 and under Reduce Motion).
public struct HeraldSymbolEffect: Codable, Equatable, Sendable {
    public var kind: HeraldSymbolEffectKind
    /// nil means `onAppear`.
    public var trigger: HeraldSymbolTrigger?
    /// 0.25 to 4; nil is 1.
    public var speed: Double?
    /// `variableColor` only.
    public var cumulative: Bool?
    public var reversing: Bool?

    public init(kind: HeraldSymbolEffectKind, trigger: HeraldSymbolTrigger? = nil, speed: Double? = nil,
                cumulative: Bool? = nil, reversing: Bool? = nil) {
        self.kind = kind; self.trigger = trigger; self.speed = speed
        self.cumulative = cumulative; self.reversing = reversing
    }

    public var resolvedTrigger: HeraldSymbolTrigger { trigger ?? .onAppear }
    public var resolvedSpeed: Double { min(max(speed ?? 1, 0.25), 4) }
}

public struct HeraldSymbol: Codable, Equatable, Sendable {
    public var name: String
    public var weight: HeraldSymbolWeight?
    public var scale: HeraldSymbolScale?
    public var placement: HeraldSymbolPlacement?
    public var renderingMode: HeraldSymbolRenderingMode?
    /// 1 to 3 colours: `#RGB`/`#RRGGBB`/`#RRGGBBAA`, `accent`/`primary`/`secondary`, or a `{token}` whose value is one of those.
    public var colors: [String]?
    /// 0 to 1, or a `{token}` bound to a numeric field. Symbols that do not support it ignore it.
    public var variableValue: String?
    public var effect: HeraldSymbolEffect?

    public init(name: String, weight: HeraldSymbolWeight? = nil, scale: HeraldSymbolScale? = nil,
                placement: HeraldSymbolPlacement? = nil, renderingMode: HeraldSymbolRenderingMode? = nil,
                colors: [String]? = nil, variableValue: String? = nil, effect: HeraldSymbolEffect? = nil) {
        self.name = name; self.weight = weight; self.scale = scale; self.placement = placement
        self.renderingMode = renderingMode; self.colors = colors; self.variableValue = variableValue; self.effect = effect
    }

    /// Only a name: written as a plain string.
    public var isPlainName: Bool {
        weight == nil && scale == nil && placement == nil && renderingMode == nil && (colors ?? []).isEmpty
            && variableValue == nil && effect == nil
    }

    /// The styling without the name, for components that keep the name in their own field (iconButton).
    public var styled: Bool { !isPlainName }

    private enum CodingKeys: String, CodingKey {
        case name, weight, scale, placement, renderingMode, colors, variableValue, effect
    }

    public init(from decoder: Decoder) throws {
        if let s = try? decoder.singleValueContainer().decode(String.self) { self.init(name: s); return }
        let c = try decoder.container(keyedBy: CodingKeys.self)
        var variable: String?
        if let d = try? c.decodeIfPresent(Double.self, forKey: .variableValue) { variable = Self.format(d) }
        else if let s = try c.decodeIfPresent(String.self, forKey: .variableValue) { variable = s }
        self.init(name: try c.decode(String.self, forKey: .name),
                  weight: try c.decodeIfPresent(HeraldSymbolWeight.self, forKey: .weight),
                  scale: try c.decodeIfPresent(HeraldSymbolScale.self, forKey: .scale),
                  placement: try c.decodeIfPresent(HeraldSymbolPlacement.self, forKey: .placement),
                  renderingMode: try c.decodeIfPresent(HeraldSymbolRenderingMode.self, forKey: .renderingMode),
                  colors: try c.decodeIfPresent([String].self, forKey: .colors),
                  variableValue: variable,
                  effect: try c.decodeIfPresent(HeraldSymbolEffect.self, forKey: .effect))
    }

    public func encode(to encoder: Encoder) throws {
        if isPlainName { var s = encoder.singleValueContainer(); try s.encode(name); return }
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(weight, forKey: .weight)
        try c.encodeIfPresent(scale, forKey: .scale)
        try c.encodeIfPresent(placement, forKey: .placement)
        try c.encodeIfPresent(renderingMode, forKey: .renderingMode)
        try c.encodeIfPresent(colors, forKey: .colors)
        if let v = variableValue {
            if let d = Double(v) { try c.encode(d, forKey: .variableValue) } else { try c.encode(v, forKey: .variableValue) }
        }
        try c.encodeIfPresent(effect, forKey: .effect)
    }

    private static func format(_ d: Double) -> String { d == d.rounded() ? String(Int(d)) : String(d) }

    // MARK: Token use

    /// `{token}` names the symbol reads (colours and variable value).
    public var referencedTokens: [String] {
        var out: [String] = []
        for s in (colors ?? []) + [variableValue].compactMap({ $0 }) { out += TemplateResolver.placeholders(in: s) }
        return out
    }

    // MARK: Validation

    /// True when this Mac has a symbol of that name (always true where AppKit is not available, e.g. Linux CI).
    public static func isKnown(_ name: String) -> Bool {
        #if canImport(AppKit)
        return NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil
        #else
        return true
        #endif
    }

    /// Problems with this symbol, as (key, message, isError). Unknown names and out-of-range values are warnings:
    /// the renderer falls back instead of failing.
    public func problems() -> [(key: String, message: String, isError: Bool)] {
        var out: [(String, String, Bool)] = []
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            out.append(("name", "a symbol needs an SF Symbol name, for example \"bell.badge\"", true))
        } else if !name.contains("{"), !Self.isKnown(name) {
            out.append(("name", "'\(name)' is not an SF Symbol on this Mac; the default look is drawn instead", false))
        }
        let cs = colors ?? []
        if cs.count > 3 { out.append(("colors", "at most 3 colours are used; the rest are ignored", false)) }
        for (i, c) in cs.enumerated() where !c.contains("{") && !Self.isColor(c) {
            out.append(("colors[\(i)]", "'\(c)' is not a colour (#RGB, #RRGGBB, #RRGGBBAA, accent, primary, secondary or a {token})", false))
        }
        if let m = renderingMode, cs.isEmpty, m == .palette {
            out.append(("colors", "palette rendering needs 2 or 3 colours; the foreground colour is used", false))
        }
        if renderingMode == .multicolor, !cs.isEmpty {
            out.append(("colors", "multicolor symbols draw their own colours; colors is ignored", false))
        }
        if let v = variableValue, !v.contains("{") {
            if let d = Double(v) { if !(0...1).contains(d) { out.append(("variableValue", "variableValue must be 0 to 1 (it is clamped)", false)) } }
            else { out.append(("variableValue", "'\(v)' is not a number between 0 and 1 or a {token}", false)) }
        }
        if let e = effect {
            if let s = e.speed, !(0.25...4).contains(s) { out.append(("effect.speed", "speed must be 0.25 to 4 (it is clamped)", false)) }
            if (e.cumulative != nil || e.reversing != nil), e.kind != .variableColor {
                out.append(("effect", "cumulative and reversing only apply to variableColor", false))
            }
            if e.kind == .appear || e.kind == .disappear, e.resolvedTrigger == .repeating {
                out.append(("effect.trigger", "\(e.kind.rawValue) plays once; repeating is treated as onAppear", false))
            }
            if e.kind == .replace, e.resolvedTrigger != .onChange {
                out.append(("effect.trigger", "replace swaps the symbol when its bound value changes; use onChange", false))
            }
        }
        if placement == .only { /* label dropped on purpose */ }
        return out
    }

    private static func isColor(_ s: String) -> Bool {
        if ["accent", "primary", "secondary"].contains(s) { return true }
        guard s.hasPrefix("#") else { return false }
        let hex = s.dropFirst()
        return [3, 4, 6, 8].contains(hex.count) && hex.allSatisfy { $0.isHexDigit }
    }
}
