import Foundation

// Pure text edits behind the Designer's formatting bar (issue #64): each takes the markup text and the selection
// (UTF-16 offsets, as NSTextView reports them) and returns new text and a new selection. They live here, not in
// the app target, so they are unit-tested.

public extension HeraldRichText {
    enum Mark: CaseIterable, Sendable {
        case bold, italic, mono, underline, strike
        var delimiter: String {
            switch self { case .bold: return "**"; case .italic: return "*"; case .mono: return "`"; case .underline: return "__"; case .strike: return "~~" }
        }
    }

    struct Edit: Equatable, Sendable {
        public var text: String
        public var selection: NSRange
    }

    // MARK: Marks

    /// Toggles `mark` on the selection: wraps it, or unwraps it when it is already marked. An empty selection
    /// inserts a pair and puts the caret between.
    static func toggle(_ mark: Mark, in text: String, selection: NSRange) -> Edit {
        let ns = text as NSString
        let sel = clamp(selection, ns.length)
        let d = mark.delimiter, dl = (d as NSString).length
        if sel.length == 0 {
            return Edit(text: ns.replacingCharacters(in: sel, with: d + d), selection: NSRange(location: sel.location + dl, length: 0))
        }
        let parts = ns.substring(with: sel).components(separatedBy: "\n")
        // Unwrap outside the selection (single line): `**[x]**`.
        if parts.count == 1 {
            let before = ns.substring(to: sel.location), after = ns.substring(from: sel.location + sel.length)
            if marked(before: before, after: after, mark) {
                let r = NSRange(location: sel.location - dl, length: sel.length + 2 * dl)
                return Edit(text: ns.replacingCharacters(in: r, with: parts[0]), selection: NSRange(location: sel.location - dl, length: sel.length))
            }
        }
        let content = parts.filter { !$0.isEmpty }
        let allMarked = !content.isEmpty && content.allSatisfy { insideMarked($0, mark) }
        let out = parts.map { p -> String in
            if p.isEmpty { return p }
            if allMarked { return String(p.dropFirst(dl).dropLast(dl)) }
            return d + p + d
        }.joined(separator: "\n")
        return Edit(text: ns.replacingCharacters(in: sel, with: out), selection: NSRange(location: sel.location, length: (out as NSString).length))
    }

    private static func starRun<S: Sequence>(_ s: S, _ c: Character) -> Int where S.Element == Character {
        var n = 0; for ch in s { if ch == c { n += 1 } else { break } }; return n
    }

    private static func active(_ run: Int, _ mark: Mark) -> Bool {
        switch mark { case .bold: return run >= 2; case .italic: return run % 2 == 1; default: return run >= 1 }
    }

    private static func marked(before: String, after: String, _ mark: Mark) -> Bool {
        let d = mark.delimiter
        guard before.hasSuffix(d), after.hasPrefix(d) else { return false }
        guard mark == .bold || mark == .italic else { return true }
        let b = starRun(before.reversed(), "*"), a = starRun(after, "*")
        return active(min(a, b), mark)
    }

    private static func insideMarked(_ s: String, _ mark: Mark) -> Bool {
        let d = mark.delimiter
        guard s.count >= 2 * d.count, s.hasPrefix(d), s.hasSuffix(d) else { return false }
        guard mark == .bold || mark == .italic else { return true }
        return active(min(starRun(s, "*"), starRun(s.reversed(), "*")), mark)
    }

    // MARK: Spans (size, colour)

    /// The enclosing `{{...}}` ... `{{/}}` around `range`, if any: (open tag range, tag text inside the braces).
    private static func enclosingSpan(_ ns: NSString, _ range: NSRange) -> (open: NSRange, inner: String)? {
        guard ns.substring(from: range.location + range.length).hasPrefix("{{/}}"),
              ns.substring(to: range.location).hasSuffix("}}") else { return nil }
        let r = ns.range(of: "{{", options: .backwards, range: NSRange(location: 0, length: range.location))
        guard r.location != NSNotFound else { return nil }
        let open = NSRange(location: r.location, length: range.location - r.location)
        let tag = ns.substring(with: open)
        let inner = String(tag.dropFirst(2).dropLast(2))
        guard inner != "/", !inner.contains("{") , !inner.contains("align=") || inner.contains(" ") else { return nil }
        return (open, inner)
    }

    private static func value(of key: String, in inner: String) -> String? {
        inner.split(whereSeparator: { $0 == " " || $0 == "," }).first { $0.hasPrefix(key + "=") }.map { String($0.dropFirst(key.count + 1)) }
    }

    /// The size the selection is set to by an enclosing span, or nil.
    static func size(in text: String, selection: NSRange) -> Double? {
        let ns = text as NSString
        guard let sp = enclosingSpan(ns, clamp(selection, ns.length)) else { return nil }
        return value(of: "size", in: sp.inner).flatMap(Double.init)
    }

    /// Sets (or, with nil, clears) the span key `size` / `color` on the selection.
    static func setSpan(_ key: String, to value: String?, in text: String, selection: NSRange) -> Edit {
        let ns = text as NSString
        let sel = clamp(selection, ns.length)
        if let sp = enclosingSpan(ns, sel) {
            var kvs = sp.inner.split(whereSeparator: { $0 == " " || $0 == "," }).map(String.init).filter { !$0.hasPrefix(key + "=") }
            if let value { kvs.append("\(key)=\(value)") }
            let close = NSRange(location: sel.location + sel.length, length: 5)
            if kvs.isEmpty {
                var t = ns.replacingCharacters(in: close, with: "")
                t = (t as NSString).replacingCharacters(in: sp.open, with: "")
                return Edit(text: t, selection: NSRange(location: sp.open.location, length: sel.length))
            }
            let tag = "{{" + kvs.joined(separator: " ") + "}}"
            var t = ns.replacingCharacters(in: close, with: "{{/}}")
            t = (t as NSString).replacingCharacters(in: sp.open, with: tag)
            return Edit(text: t, selection: NSRange(location: sp.open.location + (tag as NSString).length, length: sel.length))
        }
        guard let value else { return Edit(text: text, selection: sel) }
        let open = "{{\(key)=\(value)}}", ol = (open as NSString).length
        let parts = ns.substring(with: sel).components(separatedBy: "\n")
        let out = parts.map { $0.isEmpty ? $0 : open + $0 + "{{/}}" }.joined(separator: "\n")
        if sel.length == 0 { return Edit(text: text, selection: sel) }
        return Edit(text: ns.replacingCharacters(in: sel, with: out), selection: NSRange(location: sel.location + (parts.count == 1 ? ol : 0),
                                                                                         length: parts.count == 1 ? sel.length : (out as NSString).length))
    }

    /// Grows or shrinks the selection's size by `delta` points from its current size (`base` if it has none).
    static func stepSize(by delta: Double, base: Double, in text: String, selection: NSRange) -> Edit {
        let cur = size(in: text, selection: selection) ?? base
        let next = min(max(cur + delta, 6), 72)
        let s = next == next.rounded() ? String(Int(next)) : String(next)
        return setSpan("size", to: s, in: text, selection: selection)
    }

    // MARK: Line alignment

    private static func lineRange(_ ns: NSString, caret: Int) -> NSRange {
        ns.lineRange(for: NSRange(location: min(max(caret, 0), ns.length), length: 0))
    }

    private static func alignPrefix(_ line: String) -> (HeraldTextAlignment, Int)? {
        for a in HeraldTextAlignment.allCases {
            let tag = "{{align=\(a.rawValue)}}"
            if line.hasPrefix(tag) { return (a, (tag as NSString).length) }
        }
        return nil
    }

    /// The alignment written on the line the caret is on.
    static func align(in text: String, caret: Int) -> HeraldTextAlignment? {
        let ns = text as NSString
        return alignPrefix(ns.substring(with: lineRange(ns, caret: caret)))?.0
    }

    /// Sets (nil clears) the alignment of the caret's line; the caret keeps its place in the line.
    static func setAlign(_ a: HeraldTextAlignment?, in text: String, caret: Int) -> Edit {
        let ns = text as NSString
        let lr = lineRange(ns, caret: caret)
        let line = ns.substring(with: lr)
        let old = alignPrefix(line)?.1 ?? 0
        let tag = a.map { "{{align=\($0.rawValue)}}" } ?? ""
        let t = ns.replacingCharacters(in: NSRange(location: lr.location, length: old), with: tag)
        return Edit(text: t, selection: NSRange(location: max(lr.location, caret + (tag as NSString).length - old), length: 0))
    }

    // MARK: Token

    /// Inserts `{key}` at the selection (replacing it), caret after it.
    static func insertToken(_ key: String, in text: String, selection: NSRange) -> Edit {
        let ns = text as NSString
        let sel = clamp(selection, ns.length)
        let tok = "{\(key)}"
        return Edit(text: ns.replacingCharacters(in: sel, with: tok), selection: NSRange(location: sel.location + (tok as NSString).length, length: 0))
    }

    private static func clamp(_ r: NSRange, _ len: Int) -> NSRange {
        let l = min(max(r.location, 0), len)
        return NSRange(location: l, length: min(max(r.length, 0), len - l))
    }
}
