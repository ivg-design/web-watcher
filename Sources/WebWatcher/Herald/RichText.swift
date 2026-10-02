import Foundation

// Rich text for the `text` component (issue #64): lines and runs, plus a tiny markdown-like markup that compiles
// to the same model. The model (`HeraldTextLine` / `HeraldTextRun`) is what the renderer, the Designer and the
// validator share; the markup is only a way to write it.
//
// Markup (inside `binding` and inside a run's `text`):
//   **bold**  *italic*  `mono`  __underline__  ~~strike~~
//   {{size=14 color=#FF0000 font=serif weight=medium}}text{{/}}   a span: size, color, font, weight
//   {{align=center}} at the very start of a line                  that line's alignment (leading|center|trailing)
//   \* \_ \~ \` \{ \\                                             a literal character
//   {token}                                                       a field, as everywhere else
// A line break is a real newline. An unmatched marker is shown literally (and `validate_template` warns).

public enum HeraldFontFamily: String, Codable, CaseIterable, Sendable {
    case sans, mono, serif, rounded
}

/// One styled piece of a line. `text` (markup-aware) and `token` (`"{field}"`) may both be set: the text comes
/// first. Every style key left nil inherits from the component.
public struct HeraldTextRun: Codable, Equatable, Sendable {
    public var text: String?
    public var token: String?
    public var weight: HeraldFontWeight?
    public var italic: Bool?
    public var font: HeraldFontFamily?
    public var size: Double?
    public var color: String?
    public var underline: Bool?
    public var strike: Bool?

    public init(text: String? = nil, token: String? = nil, weight: HeraldFontWeight? = nil, italic: Bool? = nil,
                font: HeraldFontFamily? = nil, size: Double? = nil, color: String? = nil,
                underline: Bool? = nil, strike: Bool? = nil) {
        self.text = text; self.token = token; self.weight = weight; self.italic = italic; self.font = font
        self.size = size; self.color = color; self.underline = underline; self.strike = strike
    }

    /// The same style with no content, for comparing and merging runs.
    var style: HeraldTextRun {
        var s = self; s.text = nil; s.token = nil
        if s.italic == false { s.italic = nil }
        if s.underline == false { s.underline = nil }
        if s.strike == false { s.strike = nil }
        return s
    }
    var hasStyle: Bool { style != HeraldTextRun() }
}

public struct HeraldTextLine: Codable, Equatable, Sendable {
    public var align: HeraldTextAlignment?
    public var runs: [HeraldTextRun]
    public init(align: HeraldTextAlignment? = nil, runs: [HeraldTextRun] = []) { self.align = align; self.runs = runs }

    private enum CodingKeys: String, CodingKey { case align, runs }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(align: try c.decodeIfPresent(HeraldTextAlignment.self, forKey: .align),
                  runs: try c.decodeIfPresent([HeraldTextRun].self, forKey: .runs) ?? [])
    }
}

/// A run after tokens are filled: literal text and a complete style.
public struct HeraldResolvedRun: Equatable, Sendable {
    public var text: String
    public var weight: HeraldFontWeight?
    public var italic: Bool
    public var font: HeraldFontFamily?
    public var size: Double?
    public var color: String?
    public var underline: Bool
    public var strike: Bool
}

public struct HeraldResolvedLine: Equatable, Sendable {
    public var align: HeraldTextAlignment?
    public var runs: [HeraldResolvedRun]
    public var text: String { runs.map(\.text).joined() }
}

public enum HeraldRichText {
    static let specials: Set<Character> = ["\\", "*", "_", "~", "`", "{"]

    public static func escape(_ s: String) -> String {
        var out = ""
        for ch in s { if specials.contains(ch) { out.append("\\") }; out.append(ch) }
        return out
    }

    // MARK: Parsing

    private struct Span { var size: Double?; var color: String?; var font: HeraldFontFamily?; var weight: HeraldFontWeight? }

    private static func isToken(_ s: Substring) -> Bool {
        !s.isEmpty && s.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "." || $0 == "-" }
    }

    /// `{{...}}` contents -> (align, span), or an error message.
    private static func parseTag(_ inner: String) -> (align: HeraldTextAlignment?, span: Span?, errors: [String]) {
        var align: HeraldTextAlignment?, span = Span(), anySpan = false
        var errors: [String] = []
        for part in inner.split(whereSeparator: { $0 == " " || $0 == "," }) {
            let kv = part.split(separator: "=", maxSplits: 1).map(String.init)
            guard kv.count == 2 else { errors.append("'{{\(inner)}}': '\(part)' is not key=value"); continue }
            let v = kv[1]
            switch kv[0] {
            case "align":
                if let a = HeraldTextAlignment(rawValue: v) { align = a }
                else { errors.append("'{{align=\(v)}}': use leading, center or trailing") }
            case "size":
                if let d = Double(v), (6...72).contains(d) { span.size = d; anySpan = true }
                else { errors.append("'{{size=\(v)}}': size must be a number from 6 to 72") }
            case "color":
                if HeraldTemplate.isValidColor(v, allowKeywords: true) { span.color = v; anySpan = true }
                else { errors.append("'{{color=\(v)}}': not a colour (#RGB, #RRGGBB, #RRGGBBAA, accent, primary or secondary)") }
            case "font":
                if let f = HeraldFontFamily(rawValue: v) { span.font = f; anySpan = true }
                else { errors.append("'{{font=\(v)}}': use sans, mono, serif or rounded") }
            case "weight":
                if let w = HeraldFontWeight(rawValue: v) { span.weight = w; anySpan = true }
                else { errors.append("'{{weight=\(v)}}': use regular, medium, semibold or bold") }
            default: errors.append("'{{\(kv[0])=...}}': unknown key (align, size, color, font, weight)")
            }
        }
        return (align, anySpan ? span : nil, errors)
    }

    /// Parses markup into lines. Text pieces are in storage form (specials escaped, so the pieces can be stored in
    /// a run's `text`, which is itself markup). Adjacent runs of equal style are merged.
    public static func parse(_ markup: String) -> (lines: [HeraldTextLine], issues: [String]) {
        var issues: [String] = []
        var lines: [HeraldTextLine] = []
        for (n, raw) in markup.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let (line, iss) = parseLine(String(raw))
            lines.append(line)
            issues += iss.map { "line \(n + 1): \($0)" }
        }
        return (lines.map { normalized($0) }, issues)
    }

    private static func parseLine(_ s: String) -> (HeraldTextLine, [String]) {
        let chars = Array(s)
        var i = 0
        var issues: [String] = []
        var line = HeraldTextLine()
        struct Flags { var bold = false, italic = false, mono = false, under = false, strike = false }
        var f = Flags()
        var spans: [Span] = []
        var buf = ""

        func current() -> HeraldTextRun {
            var r = HeraldTextRun()
            for sp in spans {
                if let v = sp.size { r.size = v }; if let v = sp.color { r.color = v }
                if let v = sp.font { r.font = v }; if let v = sp.weight { r.weight = v }
            }
            if f.bold { r.weight = .bold }; if f.mono { r.font = .mono }
            if f.italic { r.italic = true }; if f.under { r.underline = true }; if f.strike { r.strike = true }
            return r
        }
        func flush() {
            guard !buf.isEmpty else { return }
            var r = current(); r.text = buf; line.runs.append(r); buf = ""
        }
        func ahead(_ d: String, from j: Int) -> Bool {
            let dc = Array(d)
            var k = j
            while k + dc.count <= chars.count {
                if chars[k] == "\\" { k += 2; continue }
                if Array(chars[k..<k + dc.count]) == dc { return true }
                k += 1
            }
            return false
        }
        func toggle(_ d: String, _ flag: WritableKeyPath<Flags, Bool>) -> Bool {
            let len = d.count
            if f[keyPath: flag] { flush(); f[keyPath: flag] = false; i += len; return true }
            if ahead(d, from: i + len) { flush(); f[keyPath: flag] = true; i += len; return true }
            issues.append("'\(d)' is never closed, shown as typed (write \\\(d.first!) for a literal)")
            return false
        }

        while i < chars.count {
            let c = chars[i]
            let next: Character? = i + 1 < chars.count ? chars[i + 1] : nil
            if c == "\\", let n = next, specials.contains(n) { buf += escape(String(n)); i += 2; continue }
            if c == "{", next == "{" {
                if let end = (i + 2..<max(i + 2, chars.count - 1)).first(where: { chars[$0] == "}" && chars[$0 + 1] == "}" }) {
                    let inner = String(chars[(i + 2)..<end])
                    if inner == "/" {
                        flush()
                        if spans.isEmpty { issues.append("'{{/}}' closes nothing") } else { spans.removeLast() }
                    } else {
                        let tag = parseTag(inner)
                        issues += tag.errors
                        if let a = tag.align {
                            if i == 0 { line.align = a } else { issues.append("'{{align=...}}' only works at the start of a line") }
                        }
                        flush()
                        if let sp = tag.span { spans.append(sp) }
                    }
                    i = end + 2; continue
                }
                issues.append("'{{' has no closing '}}'")
            }
            if c == "{", let close = chars[(i + 1)...].firstIndex(of: "}"), isToken(Substring(chars[(i + 1)..<close])) {
                flush()
                var r = current(); r.token = "{" + String(chars[(i + 1)..<close]) + "}"; line.runs.append(r)
                i = close + 1; continue
            }
            if c == "*", next == "*" {
                if toggle("**", \.bold) { continue }
                buf += "\\*\\*"; i += 2; continue
            }
            if c == "_", next == "_" {
                if toggle("__", \.under) { continue }
                buf += "\\_\\_"; i += 2; continue
            }
            if c == "~", next == "~" {
                if toggle("~~", \.strike) { continue }
                buf += "\\~\\~"; i += 2; continue
            }
            if c == "*", toggle("*", \.italic) { continue }
            if c == "`", toggle("`", \.mono) { continue }
            if specials.contains(c) { buf += escape(String(c)) } else { buf.append(c) }
            i += 1
        }
        flush()
        if f.bold || f.italic || f.mono || f.under || f.strike { issues.append("a marker is left open at the end of the line") }
        if !spans.isEmpty { issues.append("'{{...}}' is not closed with '{{/}}'") }
        return (line, issues)
    }

    // MARK: Normalising and serialising

    /// Drops empty runs and false flags, merges neighbouring text runs of the same style.
    public static func normalized(_ line: HeraldTextLine) -> HeraldTextLine {
        var out: [HeraldTextRun] = []
        for var r in line.runs {
            if r.italic == false { r.italic = nil }; if r.underline == false { r.underline = nil }; if r.strike == false { r.strike = nil }
            if (r.text ?? "").isEmpty && r.token == nil { continue }
            if (r.text ?? "").isEmpty { r.text = nil }
            if r.token == nil, let t = r.text, let last = out.last, last.token == nil, last.style == r.style {
                out[out.count - 1].text = (last.text ?? "") + t
            } else { out.append(r) }
        }
        return HeraldTextLine(align: line.align, runs: out)
    }

    /// True when anything beyond plain text is set: a line alignment or any run style.
    public static func hasStyling(_ lines: [HeraldTextLine]) -> Bool {
        lines.contains { $0.align != nil || $0.runs.contains { $0.hasStyle } }
    }

    private static func num(_ d: Double) -> String { d == d.rounded() ? String(Int(d)) : String(d) }

    private static func spanTag(_ r: HeraldTextRun) -> String? {
        var parts: [String] = []
        if let s = r.size { parts.append("size=\(num(s))") }
        if let c = r.color { parts.append("color=\(c)") }
        if let f = r.font, f != .mono { parts.append("font=\(f.rawValue)") }
        if let w = r.weight, w != .bold { parts.append("weight=\(w.rawValue)") }
        return parts.isEmpty ? nil : "{{" + parts.joined(separator: " ") + "}}"
    }

    /// Markup for lines. `parse(markup(for: x))` equals `x` for any normalised, storage-form `x`.
    public static func markup(for lines: [HeraldTextLine]) -> String {
        lines.map { l in
            var out = l.align.map { "{{align=\($0.rawValue)}}" } ?? ""
            var tag: String?, bold = false, italic = false, mono = false, under = false, strike = false
            func closeMarks() {
                if bold { out += "**" }; if italic { out += "*" }; if mono { out += "`" }
                if under { out += "__" }; if strike { out += "~~" }
                bold = false; italic = false; mono = false; under = false; strike = false
            }
            for r in l.runs {
                let t = spanTag(r)
                let b = r.weight == .bold, i = r.italic == true, m = r.font == .mono, u = r.underline == true, s = r.strike == true
                if t != tag { closeMarks(); if tag != nil { out += "{{/}}" }; if let t { out += t }; tag = t }
                if bold != b { out += "**"; bold = b }
                if italic != i { out += "*"; italic = i }
                if mono != m { out += "`"; mono = m }
                if under != u { out += "__"; under = u }
                if strike != s { out += "~~"; strike = s }
                out += (r.text ?? "") + (r.token ?? "")
            }
            closeMarks()
            if tag != nil { out += "{{/}}" }
            return out
        }.joined(separator: "\n")
    }

    /// The text of lines without any styling, tokens kept: the plain `binding` fallback.
    public static func plainText(_ lines: [HeraldTextLine]) -> String {
        lines.map { l in
            l.runs.map { r in
                var s = ""
                if let t = r.text { s += unescape(t) }
                s += r.token ?? ""
                return s
            }.joined()
        }.joined(separator: "\n")
    }

    public static func unescape(_ s: String) -> String {
        var out = "", esc = false
        for ch in s {
            if esc { out.append(ch); esc = false } else if ch == "\\" { esc = true } else { out.append(ch) }
        }
        return out
    }

    // MARK: Compiling

    /// Lines ready to resolve: every run's `text` is parsed as markup (so `**x**` inside a run works), tokens
    /// become their own runs, and text is literal. The run's own style is the base; markup inside overrides it.
    public static func compile(_ lines: [HeraldTextLine]) -> [HeraldTextLine] {
        lines.map { line in
            var out: [HeraldTextRun] = []
            for r in line.runs {
                var base = r; base.text = nil; base.token = nil
                if let t = r.text, !t.isEmpty {
                    let (parsed, _) = parseLine(t)
                    for var p in parsed.runs {
                        p.weight = p.weight ?? base.weight; p.font = p.font ?? base.font
                        p.italic = p.italic ?? base.italic; p.size = p.size ?? base.size; p.color = p.color ?? base.color
                        p.underline = p.underline ?? base.underline; p.strike = p.strike ?? base.strike
                        if let pt = p.text { p.text = unescape(pt) }
                        out.append(p)
                    }
                }
                if let tok = r.token, !tok.isEmpty {
                    var t = base; t.token = tok.contains("{") ? tok : "{\(tok)}"; out.append(t)
                }
            }
            return HeraldTextLine(align: line.align, runs: out)
        }
    }

    /// Problems in markup or structured runs, for the validator.
    public static func issues(binding: String, lines: [HeraldTextLine]?) -> [String] {
        guard let lines else { return parse(binding).issues }
        var out: [String] = []
        for (n, l) in lines.enumerated() {
            for (k, r) in l.runs.enumerated() {
                if let t = r.text { out += parseLine(t).1.map { "lines[\(n)].runs[\(k)].text: \($0)" } }
                if r.text == nil && r.token == nil { out.append("lines[\(n)].runs[\(k)] has neither text nor token") }
                if let s = r.size, !(6...72).contains(s) { out.append("lines[\(n)].runs[\(k)].size must be 6 to 72") }
                if let c = r.color, !HeraldTemplate.isValidColor(c, allowKeywords: true) {
                    out.append("lines[\(n)].runs[\(k)].color '\(c)' is not a colour")
                }
            }
        }
        return out
    }

    /// Every `{token}` name a text component reads (markup is looked through).
    public static func tokens(binding: String, lines: [HeraldTextLine]?) -> [String] {
        let compiled = compile(lines ?? parse(binding).lines)
        var seen: [String] = []
        for l in compiled { for r in l.runs { if let t = r.token { for n in TemplateResolver.placeholders(in: t) where !seen.contains(n) { seen.append(n) } } } }
        return seen
    }

    // MARK: Resolving

    /// The lines to draw once tokens are filled, or nil when the component is empty. A line that has tokens and
    /// whose tokens are all absent is empty: dropped, or kept as a blank line when `keepEmptyLines`. A line of
    /// literal text stays. Blank lines at the top and bottom are trimmed, as plain bindings are.
    public static func resolve(binding: String, lines: [HeraldTextLine]?, fields: [String: HeraldFieldValue],
                               keepEmptyLines: Bool) -> [HeraldResolvedLine]? {
        enum Kind { case content, blank, empty }
        var out: [(HeraldResolvedLine, Kind)] = []
        for line in compile(lines ?? parse(binding).lines) {
            var runs: [HeraldResolvedRun] = []
            var sawToken = false, anyPresent = false
            for r in line.runs {
                var text = r.text ?? ""
                if let tok = r.token {
                    sawToken = true
                    for name in TemplateResolver.placeholders(in: tok) {
                        if let v = fields[name], !TemplateResolver.string(for: v).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { anyPresent = true }
                    }
                    text += TemplateResolver.fill(tok, fields: fields)
                }
                runs.append(HeraldResolvedRun(text: text, weight: r.weight, italic: r.italic == true, font: r.font, size: r.size,
                                              color: r.color, underline: r.underline == true, strike: r.strike == true))
            }
            // Trim the line's ends the way a plain binding is trimmed.
            while let f = runs.first {
                let t = String(f.text.drop { $0.isWhitespace })
                if t.isEmpty { runs.removeFirst() } else { runs[0].text = t; break }
            }
            while let l = runs.last {
                var t = l.text
                while let c = t.last, c.isWhitespace { t.removeLast() }
                if t.isEmpty { runs.removeLast() } else { runs[runs.count - 1].text = t; break }
            }
            runs.removeAll { $0.text.isEmpty }
            let rl = HeraldResolvedLine(align: line.align, runs: runs)
            if sawToken && !anyPresent { out.append((rl.with(runs: []), .empty)) }
            else if runs.isEmpty { out.append((rl, .blank)) }
            else { out.append((rl, .content)) }
        }
        guard let first = out.firstIndex(where: { $0.1 == .content }), let last = out.lastIndex(where: { $0.1 == .content }) else { return nil }
        return out[first...last].compactMap { l, k in (k == .empty && !keepEmptyLines) ? nil : l }
    }
}

extension HeraldResolvedLine {
    fileprivate func with(runs: [HeraldResolvedRun]) -> HeraldResolvedLine { HeraldResolvedLine(align: align, runs: runs) }
}
