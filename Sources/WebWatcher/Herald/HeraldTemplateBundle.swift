import Foundation
import CryptoKit
#if canImport(Compression)
import Compression
#endif

// The `.heraldtemplate` bundle (DESIGN 7.4, issue #30): one template with the Rive files it plays, as a zip.
//
//     bundle.json         format, version, the template's name and app, the asset file names (optional on read)
//     template.json       the HeraldTemplate, as the template store writes it
//     assets/<file>.riv   every Rive file a `rive` component of the template plays
//
// This is the pure half, shared by Herald.app (`TemplateBundleService`) and the `herald` command line tool: the
// zip container (stored or deflate, no zip64, no encryption), packing a template with its assets, unpacking and
// validating one that came from elsewhere, and putting the assets into an app's folder without clobbering what
// is there. Nothing here talks to the stores or the network.
//
// A bundle is untrusted input. Reading it never creates a file from an entry name (names are only matched
// against the fixed layout above), never recreates links, refuses entry names that climb out of the archive,
// and caps the entry count and the inflated sizes before inflating anything.

// MARK: - Zip container

enum HeraldZip {
    struct Entry: Equatable {
        var name: String
        var data: Data
    }

    struct Limits {
        var maxEntries: Int
        var maxEntryBytes: Int
        var maxTotalBytes: Int
    }

    enum ZipError: Error, Equatable, LocalizedError {
        case notAZip
        case unsupported(String)
        case corrupt(String)
        case unsafeName(String)
        case tooManyEntries(Int)
        case tooLarge(String)

        var errorDescription: String? {
            switch self {
            case .notAZip: return "this is not a zip archive"
            case .unsupported(let why): return "unsupported zip feature: \(why)"
            case .corrupt(let why): return "the zip archive is damaged (\(why))"
            case .unsafeName(let n): return "the archive has an entry with an unsafe path: \(n)"
            case .tooManyEntries(let n): return "the archive has more than \(n) entries"
            case .tooLarge(let what): return "\(what) is larger than a template bundle may be"
            }
        }
    }

    // MARK: CRC-32

    private static let crcTable: [UInt32] = (0..<256).map { n -> UInt32 in
        var c = UInt32(n)
        for _ in 0..<8 { c = (c & 1) != 0 ? 0xEDB8_8320 ^ (c >> 1) : c >> 1 }
        return c
    }

    static func crc32(_ data: Data) -> UInt32 {
        data.withUnsafeBytes { raw -> UInt32 in
            var c: UInt32 = 0xFFFF_FFFF
            for b in raw.bindMemory(to: UInt8.self) { c = crcTable[Int((c ^ UInt32(b)) & 0xFF)] ^ (c >> 8) }
            return c ^ 0xFFFF_FFFF
        }
    }

    // MARK: Deflate (raw, as zip method 8 stores it)

    /// The deflated bytes when that is smaller than the input, else nil (the entry is then stored).
    static func deflate(_ data: Data) -> Data? {
        #if canImport(Compression)
        guard data.count > 64 else { return nil }
        let capacity = data.count
        var out = Data(count: capacity)
        let n = out.withUnsafeMutableBytes { dst in
            data.withUnsafeBytes { src in
                compression_encode_buffer(dst.bindMemory(to: UInt8.self).baseAddress!, capacity,
                                          src.bindMemory(to: UInt8.self).baseAddress!, data.count, nil, COMPRESSION_ZLIB)
            }
        }
        guard n > 0, n < data.count else { return nil }
        return out.prefix(n)
        #else
        return nil
        #endif
    }

    /// Inflates to exactly `expected` bytes, else nil.
    static func inflate(_ data: Data, expected: Int) -> Data? {
        #if canImport(Compression)
        guard expected > 0, !data.isEmpty else { return nil }
        var out = Data(count: expected)
        let n = out.withUnsafeMutableBytes { dst in
            data.withUnsafeBytes { src in
                compression_decode_buffer(dst.bindMemory(to: UInt8.self).baseAddress!, expected,
                                          src.bindMemory(to: UInt8.self).baseAddress!, data.count, nil, COMPRESSION_ZLIB)
            }
        }
        return n == expected ? out : nil
        #else
        return nil
        #endif
    }

    // MARK: Write

    private static func appendLE<T: FixedWidthInteger>(_ d: inout Data, _ v: T) {
        var x = v.littleEndian
        withUnsafeBytes(of: &x) { d.append(contentsOf: $0) }
    }

    private static func dos(_ date: Date) -> (time: UInt16, date: UInt16) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .current
        let c = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let year = min(max((c.year ?? 1980) - 1980, 0), 127)
        let t = ((c.hour ?? 0) << 11) | ((c.minute ?? 0) << 5) | ((c.second ?? 0) / 2)
        let d = (year << 9) | ((c.month ?? 1) << 5) | (c.day ?? 1)
        return (UInt16(truncatingIfNeeded: t), UInt16(truncatingIfNeeded: d))
    }

    static func write(_ entries: [Entry], date: Date = Date()) -> Data {
        var out = Data()
        var central = Data()
        let stamp = dos(date)
        for e in entries {
            let name = Data(e.name.utf8)
            let crc = crc32(e.data)
            let packed = deflate(e.data)
            let method: UInt16 = packed == nil ? 0 : 8
            let body = packed ?? e.data
            let offset = UInt32(out.count)

            appendLE(&out, UInt32(0x0403_4B50))
            appendLE(&out, UInt16(20))
            appendLE(&out, UInt16(0x0800))               // names are UTF-8
            appendLE(&out, method)
            appendLE(&out, stamp.time); appendLE(&out, stamp.date)
            appendLE(&out, crc)
            appendLE(&out, UInt32(body.count)); appendLE(&out, UInt32(e.data.count))
            appendLE(&out, UInt16(name.count)); appendLE(&out, UInt16(0))
            out.append(name); out.append(body)

            appendLE(&central, UInt32(0x0201_4B50))
            appendLE(&central, UInt16(0x031E))           // made by: unix, zip 3.0
            appendLE(&central, UInt16(20))
            appendLE(&central, UInt16(0x0800))
            appendLE(&central, method)
            appendLE(&central, stamp.time); appendLE(&central, stamp.date)
            appendLE(&central, crc)
            appendLE(&central, UInt32(body.count)); appendLE(&central, UInt32(e.data.count))
            appendLE(&central, UInt16(name.count))
            appendLE(&central, UInt16(0)); appendLE(&central, UInt16(0))   // extra, comment
            appendLE(&central, UInt16(0)); appendLE(&central, UInt16(0))   // disk, internal attributes
            appendLE(&central, UInt32(0o100644) << 16)                     // a regular file, rw-r--r--
            appendLE(&central, offset)
            central.append(name)
        }
        let centralOffset = UInt32(out.count)
        out.append(central)
        appendLE(&out, UInt32(0x0605_4B50))
        appendLE(&out, UInt16(0)); appendLE(&out, UInt16(0))
        appendLE(&out, UInt16(entries.count)); appendLE(&out, UInt16(entries.count))
        appendLE(&out, UInt32(central.count)); appendLE(&out, centralOffset)
        appendLE(&out, UInt16(0))
        return out
    }

    // MARK: Read

    /// Every file entry (directories are skipped). Sizes come from the central directory, which is also what
    /// archives written with data descriptors (Finder's Compress) fill in correctly.
    static func read(_ data: Data, limits: Limits) throws -> [Entry] {
        let b = [UInt8](data)
        func u16(_ o: Int) -> Int { Int(b[o]) | Int(b[o + 1]) << 8 }
        func u32(_ o: Int) -> Int { u16(o) | u16(o + 2) << 16 }

        guard b.count >= 22 else { throw ZipError.notAZip }
        // The end-of-central-directory record is the last 22+ bytes (a comment of up to 64 KB may follow it).
        var eocd = -1
        var o = b.count - 22
        let stop = max(0, b.count - 22 - 65_535)
        while o >= stop {
            if b[o] == 0x50, b[o + 1] == 0x4B, b[o + 2] == 5, b[o + 3] == 6 { eocd = o; break }
            o -= 1
        }
        guard eocd >= 0 else { throw ZipError.notAZip }
        let disk = u16(eocd + 4), cdDisk = u16(eocd + 6)
        let count = u16(eocd + 10), cdSize = u32(eocd + 12), cdOffset = u32(eocd + 16)
        guard disk == 0, cdDisk == 0 else { throw ZipError.unsupported("multi-part archives") }
        guard count != 0xFFFF, cdSize != 0xFFFF_FFFF, cdOffset != 0xFFFF_FFFF else { throw ZipError.unsupported("zip64") }
        guard count <= limits.maxEntries else { throw ZipError.tooManyEntries(limits.maxEntries) }
        guard cdOffset + cdSize <= eocd else { throw ZipError.corrupt("central directory out of range") }

        struct Raw { var name: String; var method: Int; var crc: UInt32; var csize: Int; var usize: Int; var local: Int }
        var raws: [Raw] = []
        var p = cdOffset
        for _ in 0..<count {
            guard p + 46 <= b.count, u32(p) == 0x0201_4B50 else { throw ZipError.corrupt("bad central directory entry") }
            let flags = u16(p + 8), method = u16(p + 10)
            let crc = UInt32(truncatingIfNeeded: u32(p + 16))
            let csize = u32(p + 20), usize = u32(p + 24)
            let nlen = u16(p + 28), xlen = u16(p + 30), clen = u16(p + 32)
            let local = u32(p + 42)
            guard p + 46 + nlen + xlen + clen <= b.count else { throw ZipError.corrupt("entry name out of range") }
            let name = String(decoding: b[(p + 46)..<(p + 46 + nlen)], as: UTF8.self)
            p += 46 + nlen + xlen + clen
            if flags & 1 != 0 { throw ZipError.unsupported("encrypted entries") }
            if csize == 0xFFFF_FFFF || usize == 0xFFFF_FFFF || local == 0xFFFF_FFFF { throw ZipError.unsupported("zip64") }
            try checkName(name)
            if name.hasSuffix("/") { continue }
            raws.append(Raw(name: name, method: method, crc: crc, csize: csize, usize: usize, local: local))
        }
        guard Set(raws.map(\.name)).count == raws.count else { throw ZipError.corrupt("duplicate entry names") }

        var total = 0
        for r in raws {
            guard r.usize <= limits.maxEntryBytes else { throw ZipError.tooLarge("\u{201C}\(r.name)\u{201D}") }
            total += r.usize
            guard total <= limits.maxTotalBytes else { throw ZipError.tooLarge("the archive") }
        }

        var out: [Entry] = []
        for r in raws {
            guard r.local + 30 <= b.count, u32(r.local) == 0x0403_4B50 else { throw ZipError.corrupt("bad local header for \(r.name)") }
            let start = r.local + 30 + u16(r.local + 26) + u16(r.local + 28)
            guard start + r.csize <= b.count else { throw ZipError.corrupt("data of \(r.name) out of range") }
            let packed = Data(b[start..<(start + r.csize)])
            let content: Data
            switch r.method {
            case 0:
                guard r.csize == r.usize else { throw ZipError.corrupt("size mismatch in \(r.name)") }
                content = packed
            case 8:
                if r.usize == 0 { content = Data() }
                else if let d = inflate(packed, expected: r.usize) { content = d }
                else { throw ZipError.corrupt("\(r.name) does not inflate to its declared size") }
            default:
                throw ZipError.unsupported("compression method \(r.method)")
            }
            guard crc32(content) == r.crc else { throw ZipError.corrupt("checksum mismatch in \(r.name)") }
            out.append(Entry(name: r.name, data: content))
        }
        return out
    }

    /// Entry names are only ever compared with the bundle layout, but a name that climbs out of the archive or
    /// carries a control character says the archive was built to cause trouble.
    private static func checkName(_ name: String) throws {
        if name.isEmpty || name.hasPrefix("/") || name.contains("\\") || name.unicodeScalars.contains(where: { $0.value < 0x20 }) {
            throw ZipError.unsafeName(name)
        }
        if name.split(separator: "/", omittingEmptySubsequences: false).contains(where: { $0 == ".." }) {
            throw ZipError.unsafeName(name)
        }
    }
}

// MARK: - Bundle

public enum HeraldTemplateBundle {
    public static let fileExtension = "heraldtemplate"
    public static let formatName = "heraldtemplate"
    public static let formatVersion = 1

    /// Largest template.json, the same cap `TemplateStore` puts on a template file.
    public static let maxTemplateBytes = 2 * 1024 * 1024
    /// Largest Rive file, the same cap `AssetStore` puts on an asset.
    public static let maxAssetBytes = 10 * 1024 * 1024
    /// Most Rive files in one bundle (an app may hold 32 copies).
    public static let maxAssets = 32
    public static let maxTotalBytes = 64 * 1024 * 1024
    public static let riveExtension = "riv"

    // MARK: Types

    /// One Rive file in a bundle. `file` is a bare, safe file name ending in `.riv`.
    public struct Asset: Equatable, Sendable {
        public var file: String
        public var data: Data
        public init(file: String, data: Data) { self.file = file; self.data = data }
    }

    /// What a bundle holds: the template and its Rive files.
    public struct Contents: Equatable, Sendable {
        public var template: HeraldTemplate
        public var assets: [Asset]
        public init(template: HeraldTemplate, assets: [Asset]) { self.template = template; self.assets = assets }
    }

    /// bundle.json: a human-readable header. Only `format` and `version` are checked on read.
    struct Info: Codable, Equatable {
        var format: String
        var version: Int
        var app: String
        var name: String
        var createdAt: String?
        var assets: [String]
    }

    /// A Rive file a template plays, as a `rive` component names it.
    public enum RiveRef: Hashable, Sendable {
        case asset(String)
        case path(String)
    }

    public enum BundleError: Error, Equatable, LocalizedError {
        case notABundle(String)
        case badTemplate(String)
        case badAsset(String)
        case tooManyAssets
        case unsupportedVersion(Int)
        case nameExists(String)
        case cannotWrite(String)

        public var errorDescription: String? {
            switch self {
            case .notABundle(let why): return "not a Herald template bundle: \(why)"
            case .badTemplate(let why): return "the bundle's template.json is not valid: \(why)"
            case .badAsset(let why): return why
            case .tooManyAssets: return "the bundle has more than \(HeraldTemplateBundle.maxAssets) animation files"
            case .unsupportedVersion(let v): return "the bundle is format version \(v); this Herald reads version \(HeraldTemplateBundle.formatVersion)"
            case .nameExists(let n): return "a template named \u{201C}\(n)\u{201D} already exists"
            case .cannotWrite(let why): return "could not write: \(why)"
            }
        }
    }

    // MARK: Rive references

    /// The Rive files the template's cells play, once each, in cell order. A component with an `asset` id plays
    /// that asset (the path is then ignored, as `AssetStore.resolve` does).
    public static func riveRefs(in t: HeraldTemplate) -> [RiveRef] {
        var seen = Set<RiveRef>()
        var out: [RiveRef] = []
        for c in t.cells {
            guard case .rive(let r) = c.component, let ref = ref(of: r), seen.insert(ref).inserted else { continue }
            out.append(ref)
        }
        return out
    }

    public static func ref(of r: HeraldRiveComponent) -> RiveRef? {
        if let a = r.asset?.trimmingCharacters(in: .whitespacesAndNewlines), !a.isEmpty { return .asset(a) }
        if let p = r.path?.trimmingCharacters(in: .whitespacesAndNewlines), !p.isEmpty { return .path(p) }
        return nil
    }

    /// Calls `body` on every `rive` component of the template.
    public static func mapRive(_ t: inout HeraldTemplate, _ body: (inout HeraldRiveComponent) -> Void) {
        for i in t.cells.indices {
            if case .rive(var r) = t.cells[i].component { body(&r); t.cells[i].component = .rive(r) }
        }
    }

    /// The file name a ref has inside a bundle (and, for an asset id, in the app's assets folder): the id or the
    /// path's last component with `.riv`, reduced to `[A-Za-z0-9._-]`. The same rule as `TemplateStore.component`,
    /// so `assets/<app>/<file>` is exactly where `AssetStore.storedURL` looks for an id.
    public static func fileName(for ref: RiveRef) -> String {
        switch ref {
        case .asset(let id): return safeFile(stem: id)
        case .path(let p): return safeFile(stem: (p as NSString).lastPathComponent)
        }
    }

    /// `stem` (a trailing `.riv`, any case, dropped) made safe as a single path component, plus `.riv`.
    public static func safeFile(stem raw: String) -> String {
        var stem = raw
        if stem.lowercased().hasSuffix("." + riveExtension) { stem.removeLast(riveExtension.count + 1) }
        return component(stem) + "." + riveExtension
    }

    /// Mirrors `TemplateStore.component` (a test pins them together): anything outside `[A-Za-z0-9._-]` becomes
    /// `_` and a short hash is appended so "a/b" and "a_b" differ; a leading dot cannot address a parent folder.
    public static func component(_ s: String) -> String {
        var safe = String(s.map { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "." || $0 == "-" || $0 == "_") ? $0 : "_" })
        if safe.hasPrefix(".") { safe = "_" + safe.dropFirst() }
        if safe.isEmpty { safe = "_" }
        guard safe != s else { return safe }
        return safe + "-" + sha256Prefix(Data(s.utf8))
    }

    // MARK: Names

    /// A template name that passes `DesignerModel.isValidName`: no `/` or `:`, no leading `.` or `_`, at most 100
    /// characters; "Imported template" when nothing is left.
    public static func sanitizedTemplateName(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        s = String(s.map { $0 == "/" || $0 == ":" || $0.unicodeScalars.contains(where: { $0.value < 0x20 }) ? "-" : $0 })
        while s.hasPrefix(".") || s.hasPrefix("_") { s.removeFirst() }
        s = String(s.prefix(100)).trimmingCharacters(in: .whitespaces)
        return s.isEmpty ? "Imported template" : s
    }

    /// `base`, or `base 2`, `base 3`, ... when `base` is taken (compared ignoring case, as the file system does).
    public static func uniqueName(_ base: String, taken: Set<String>) -> String {
        let lowered = Set(taken.map { $0.lowercased() })
        if !lowered.contains(base.lowercased()) { return base }
        var n = 2
        while lowered.contains("\(base) \(n)".lowercased()) { n += 1 }
        return "\(base) \(n)"
    }

    // MARK: Export

    public struct ExportResult: Sendable {
        public var data: Data
        /// The template as written into the bundle (paths of loose Rive files rewritten to bundle-relative names).
        public var template: HeraldTemplate
        /// File names of the assets that went in.
        public var assetFiles: [String]
        /// Things the user should know: an animation that could not be found, scripts and Shortcuts that stay behind.
        public var warnings: [String]
    }

    /// Packs `template` with the Rive files it plays. `locate` finds the file for a ref (nil when it cannot be
    /// found); a missing file is a warning, not an error, so a template whose animation moved can still be shared.
    public static func export(_ template: HeraldTemplate, locate: (RiveRef) -> URL?, now: Date = Date()) throws -> ExportResult {
        // Refused up front what `unpack` (and `PUT /v1/templates`) would refuse, so a bundle is never written
        // that cannot be read back.
        try requireValid(template)
        var t = template
        var warnings: [String] = []
        var assets: [Asset] = []
        var taken = Set<String>()

        // Asset ids first: their file name is fixed by the id. Loose paths then take a free name.
        let refs = riveRefs(in: template)
        let ordered = refs.filter { if case .asset = $0 { return true }; return false }
            + refs.filter { if case .path = $0 { return true }; return false }
        for ref in ordered {
            let label: String
            switch ref { case .asset(let id): label = id; case .path(let p): label = (p as NSString).lastPathComponent }
            guard let url = locate(ref) else { warnings.append("The animation \u{201C}\(label)\u{201D} was not found and is not in the bundle."); continue }
            let data: Data
            do { data = try readAsset(url) }
            catch let e as BundleError { warnings.append("\u{201C}\(label)\u{201D} is not in the bundle: \(e.localizedDescription)"); continue }
            catch { warnings.append("\u{201C}\(label)\u{201D} is not in the bundle: \(error.localizedDescription)"); continue }
            if let same = assets.first(where: { $0.data == data }), case .path = ref {
                rewrite(&t, ref, toFile: same.file)
                continue
            }
            var file = fileName(for: ref)
            if case .path = ref { file = uniqueFile(file, taken: taken) }
            taken.insert(file.lowercased())
            assets.append(Asset(file: file, data: data))
            if case .path = ref { rewrite(&t, ref, toFile: file) }
        }
        guard assets.count <= maxAssets else { throw BundleError.tooManyAssets }

        for a in t.actionRules.compactMap(\.add) + t.cells.compactMap(inlineAction) {
            if a.kind == .script { warnings.append("The script action \u{201C}\(a.label)\u{201D} runs a file from the scripts folder; the file is not in the bundle.") }
            if a.kind == .shortcut { warnings.append("The action \u{201C}\(a.label)\u{201D} runs the Shortcut \u{201C}\(a.shortcut ?? "")\u{201D}, which must exist on the other Mac.") }
        }

        let info = Info(format: formatName, version: formatVersion, app: t.app, name: t.name,
                        createdAt: ISODate.string(from: now), assets: assets.map(\.file))
        var entries: [HeraldZip.Entry] = []
        entries.append(.init(name: "bundle.json", data: try encode(info)))
        entries.append(.init(name: "template.json", data: try encode(t)))
        entries += assets.map { .init(name: "assets/" + $0.file, data: $0.data) }
        return ExportResult(data: HeraldZip.write(entries, date: now), template: t, assetFiles: assets.map(\.file),
                            warnings: Array(NSOrderedSet(array: warnings)) as? [String] ?? warnings)
    }

    /// The check `PUT /v1/templates` makes: a saved template is laid out on every delivery for its app.
    private static func requireValid(_ t: HeraldTemplate) throws {
        let errors = t.validate().filter(\.isError)
        guard errors.isEmpty else {
            throw BundleError.badTemplate(errors.map { (($0.cellId.map { "cell \($0): " }) ?? "") + $0.path + ": " + $0.message }.joined(separator: "; "))
        }
    }

    private static func inlineAction(_ c: HeraldCell) -> HeraldAction? {
        switch c.component {
        case .button(let b): return b.action
        case .iconButton(let b): return b.action
        case .rive(let r): return r.action
        default: return nil
        }
    }

    private static func rewrite(_ t: inout HeraldTemplate, _ ref: RiveRef, toFile file: String) {
        mapRive(&t) { r in if Self.ref(of: r) == ref { r.path = file; r.asset = nil } }
    }

    private static func uniqueFile(_ file: String, taken: Set<String>) -> String {
        guard taken.contains(file.lowercased()) else { return file }
        let stem = String(file.dropLast(riveExtension.count + 1))
        var n = 2
        while taken.contains("\(stem)-\(n).\(riveExtension)".lowercased()) { n += 1 }
        return "\(stem)-\(n).\(riveExtension)"
    }

    /// Reads a Rive file for a bundle: a regular `.riv` of 1 byte to `maxAssetBytes`.
    private static func readAsset(_ url: URL) throws -> Data {
        let resolved = url.resolvingSymlinksInPath()
        guard resolved.pathExtension.lowercased() == riveExtension else { throw BundleError.badAsset("\u{201C}\(url.lastPathComponent)\u{201D} is not a .riv file") }
        let attrs = try? FileManager.default.attributesOfItem(atPath: resolved.path)
        guard (attrs?[.type] as? FileAttributeType) == .typeRegular, let size = (attrs?[.size] as? NSNumber)?.intValue else {
            throw BundleError.badAsset("\u{201C}\(url.lastPathComponent)\u{201D} is not a regular file")
        }
        guard size > 0 else { throw BundleError.badAsset("\u{201C}\(url.lastPathComponent)\u{201D} is empty") }
        guard size <= maxAssetBytes else { throw BundleError.badAsset("\u{201C}\(url.lastPathComponent)\u{201D} is larger than \(maxAssetBytes / 1_048_576) MB") }
        guard let data = try? Data(contentsOf: resolved) else { throw BundleError.badAsset("could not read \u{201C}\(url.lastPathComponent)\u{201D}") }
        return data
    }

    private static func encode<T: Encodable>(_ v: T) throws -> Data {
        let e = HeraldJSON.encoder()
        e.outputFormatting.insert(.prettyPrinted)
        do { return try e.encode(v) } catch { throw BundleError.cannotWrite(error.localizedDescription) }
    }

    // MARK: Unpack

    /// Parses and validates a bundle. The template is decoded and its name made valid; the assets are the
    /// `assets/*.riv` entries (anything else is ignored), each non-empty and within `maxAssetBytes`.
    public static func unpack(_ data: Data) throws -> Contents {
        let limits = HeraldZip.Limits(maxEntries: maxAssets * 2 + 16, maxEntryBytes: maxAssetBytes, maxTotalBytes: maxTotalBytes)
        let entries: [HeraldZip.Entry]
        do { entries = try HeraldZip.read(data, limits: limits) }
        catch let e as HeraldZip.ZipError { throw BundleError.notABundle(e.localizedDescription) }

        // Finder's Compress wraps a folder's contents in a folder of the same name, and adds __MACOSX junk.
        let real = entries.filter { e in
            !e.name.hasPrefix("__MACOSX/") && !e.name.split(separator: "/").contains { $0.hasPrefix("._") || $0 == ".DS_Store" }
        }
        let root: String
        if real.contains(where: { $0.name == "template.json" }) { root = "" }
        else {
            let nested = real.filter { $0.name.split(separator: "/").count == 2 && $0.name.hasSuffix("/template.json") }
            guard nested.count == 1, let n = nested.first else { throw BundleError.notABundle("there is no template.json") }
            root = String(n.name.dropLast("template.json".count))
        }
        func entry(_ name: String) -> HeraldZip.Entry? { real.first { $0.name == root + name } }

        if let raw = entry("bundle.json"), let info = try? JSONDecoder().decode(Info.self, from: raw.data) {
            guard info.format == formatName else { throw BundleError.notABundle("bundle.json says \u{201C}\(info.format)\u{201D}") }
            guard info.version <= formatVersion else { throw BundleError.unsupportedVersion(info.version) }
        }
        guard let tj = entry("template.json") else { throw BundleError.notABundle("there is no template.json") }
        guard tj.data.count <= maxTemplateBytes else { throw BundleError.badTemplate("it is larger than \(maxTemplateBytes / 1_048_576) MB") }
        var template: HeraldTemplate
        do { template = try HeraldJSON.decoder().decode(HeraldTemplate.self, from: tj.data) }
        catch { throw BundleError.badTemplate(error.localizedDescription) }
        template.name = sanitizedTemplateName(template.name)
        try requireValid(template)

        var assets: [Asset] = []
        let prefix = root + "assets/"
        for e in real where e.name.hasPrefix(prefix) {
            let rest = String(e.name.dropFirst(prefix.count))
            // Only files directly in assets/, and only Rive files.
            guard !rest.isEmpty, !rest.contains("/"), rest.lowercased().hasSuffix("." + riveExtension) else { continue }
            guard !e.data.isEmpty else { throw BundleError.badAsset("\u{201C}\(rest)\u{201D} in the bundle is empty") }
            let file = safeFile(stem: rest)
            guard !assets.contains(where: { $0.file == file }) else { continue }
            assets.append(Asset(file: file, data: e.data))
        }
        guard assets.count <= maxAssets else { throw BundleError.tooManyAssets }
        return Contents(template: template, assets: assets)
    }

    // MARK: Locating files without the app (the command line tool)

    /// `<support>/assets/<app>/`, where Herald keeps an app's Rive files.
    public static func assetsFolder(app: String, supportDirectory: URL) -> URL {
        supportDirectory.appendingPathComponent("assets", isDirectory: true).appendingPathComponent(component(app), isDirectory: true)
    }

    /// Finds the Rive file for a ref the way `AssetStore` does, from the support directory alone: an asset id is the
    /// stored copy in the app's folder, else the file the issuer's manifest names; a path is absolute, `~/`, a
    /// `file:` URL, or relative to the app's folder (never above it; remote URLs are refused).
    public static func locator(app: String, supportDirectory: URL, manifest: HeraldManifest?) -> (RiveRef) -> URL? {
        let folder = assetsFolder(app: app, supportDirectory: supportDirectory)
        func locate(_ raw: String) -> URL? {
            let path = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !path.isEmpty else { return nil }
            if path.lowercased().hasPrefix("file:") { return URL(string: path).flatMap { $0.isFileURL ? $0 : nil } }
            guard !path.contains("://") else { return nil }
            if path.hasPrefix("~") { return URL(fileURLWithPath: (path as NSString).expandingTildeInPath) }
            if path.hasPrefix("/") { return URL(fileURLWithPath: path) }
            let parts = path.split(separator: "/", omittingEmptySubsequences: true)
            guard !parts.contains(where: { $0 == ".." }) else { return nil }
            return parts.reduce(folder) { $0.appendingPathComponent(String($1)) }
        }
        return { ref in
            switch ref {
            case .path(let p): return locate(p)
            case .asset(let id):
                let stored = folder.appendingPathComponent(fileName(for: ref))
                if FileManager.default.fileExists(atPath: stored.path) { return stored }
                return manifest?.assets.first { $0.id == id }.flatMap { locate($0.path) }
            }
        }
    }

    // MARK: Install

    public struct InstallReport: Equatable, Sendable {
        /// Files written into the folder.
        public var installed: [String] = []
        /// Files that were already there with the same content.
        public var reused: [String] = []
        /// Files that found a different file under their name and went in under another one.
        public var renamed: [String: String] = [:]
        /// Rive files the template names that the bundle does not hold (and the folder does not either).
        public var missing: [String] = []
    }

    /// Puts the bundle's Rive files into an app's assets folder and returns the template pointed at them.
    ///
    /// A file that is already there with the same bytes is reused. One that finds a different file under its name
    /// is written beside it as `name-2.riv` (and so on) and the template's references are rewritten, so an import
    /// never changes an animation another template plays. `maxFiles` caps the folder's `.riv` count.
    public static func installAssets(_ contents: Contents, into folder: URL, maxFiles: Int = 32) throws -> (template: HeraldTemplate, report: InstallReport) {
        var t = contents.template
        var report = InstallReport()
        let fm = FileManager.default
        func existing(_ name: String) -> Data? { try? Data(contentsOf: folder.appendingPathComponent(name)) }
        var count = ((try? fm.contentsOfDirectory(atPath: folder.path)) ?? []).filter { $0.lowercased().hasSuffix("." + riveExtension) }.count

        var finalFile: [String: String] = [:]
        for a in contents.assets {
            let stem = String(a.file.dropLast(riveExtension.count + 1))
            var candidate = a.file
            var n = 2
            var chosen: (file: String, write: Bool)?
            while chosen == nil, n < 200 {
                if let have = existing(candidate) { if have == a.data { chosen = (candidate, false) } else { candidate = "\(stem)-\(n).\(riveExtension)"; n += 1 } }
                else { chosen = (candidate, true) }
            }
            guard let pick = chosen else { throw BundleError.badAsset("no free file name for \u{201C}\(a.file)\u{201D}") }
            if pick.write {
                guard count < maxFiles else { throw BundleError.badAsset("an app can have at most \(maxFiles) animation files") }
                do {
                    try fm.createDirectory(at: folder, withIntermediateDirectories: true)
                    try a.data.write(to: folder.appendingPathComponent(pick.file), options: .atomic)
                } catch { throw BundleError.cannotWrite(error.localizedDescription) }
                count += 1
                report.installed.append(pick.file)
            } else {
                report.reused.append(pick.file)
            }
            if pick.file != a.file { report.renamed[a.file] = pick.file }
            finalFile[a.file] = pick.file
        }

        mapRive(&t) { r in
            guard let ref = ref(of: r) else { return }
            let original = fileName(for: ref)
            guard let now = finalFile[original] else {
                // Not in the bundle: fine when the folder already has it (an issuer's own copy), a warning otherwise.
                if existing(original) == nil, !report.missing.contains(original) { report.missing.append(original) }
                return
            }
            guard now != original else { return }
            switch ref {
            case .asset: r.asset = String(now.dropLast(riveExtension.count + 1))
            case .path: r.path = now
            }
        }
        return (t, report)
    }

    // MARK: Hash

    /// First three bytes of SHA-256 as hex, for `component` (a test pins the result against `TemplateStore.component`).
    private static func sha256Prefix(_ data: Data) -> String {
        SHA256.hash(data: data).prefix(3).map { String(format: "%02x", $0) }.joined()
    }
}
