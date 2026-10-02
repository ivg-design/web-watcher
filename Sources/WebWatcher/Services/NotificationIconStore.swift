import AppKit
import Foundation

/// Keeps notification icons under the app's own Application Support folder.
///
/// A path chosen in the editor used to be stored as-is, so moving or deleting the
/// original file silently dropped the image from every later notification. Importing
/// copies the file once (`icons/<uuid>.<ext>`), and `squareThumbnail` renders the
/// attachment macOS actually shows: a centred square crop at 512 px, so a landscape or
/// portrait photo fills the thumbnail slot instead of being letterboxed inside it.
enum NotificationIconStore {

    static var folder: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("WebWatcher/icons", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// True when `path` already lives in the managed folder.
    static func isManaged(_ path: String) -> Bool {
        URL(fileURLWithPath: path).standardizedFileURL.path.hasPrefix(folder.standardizedFileURL.path)
    }

    /// Copies `path` into the managed folder and returns the new path. Returns the input
    /// unchanged when it is already managed, and nil when the file cannot be read.
    @discardableResult
    static func importIcon(from path: String) -> String? {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if isManaged(trimmed) { return trimmed }
        let source = URL(fileURLWithPath: trimmed)
        guard FileManager.default.fileExists(atPath: source.path) else { return nil }
        let ext = source.pathExtension.isEmpty ? "png" : source.pathExtension.lowercased()
        let dest = folder.appendingPathComponent("\(UUID().uuidString).\(ext)")
        do {
            try FileManager.default.copyItem(at: source, to: dest)
            return dest.path
        } catch {
            print("NotificationIconStore: copy failed: \(error)")
            return nil
        }
    }

    /// Renders a centred square crop of the image as PNG at up to `side` px, into a
    /// fresh temp file (UNNotificationAttachment takes ownership of the file it is given).
    static func squareThumbnail(from path: String, side: CGFloat = 512) -> URL? {
        guard let image = NSImage(contentsOfFile: path),
              let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let w = CGFloat(cg.width), h = CGFloat(cg.height)
        let edge = min(w, h)
        guard edge > 0 else { return nil }
        let crop = CGRect(x: (w - edge) / 2, y: (h - edge) / 2, width: edge, height: edge)
        guard let cropped = cg.cropping(to: crop) else { return nil }
        let out = min(side, edge)
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(out), pixelsHigh: Int(out),
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let ctx = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = ctx
        ctx.cgContext.interpolationQuality = .high
        ctx.cgContext.draw(cropped, in: CGRect(x: 0, y: 0, width: out, height: out))
        NSGraphicsContext.restoreGraphicsState()
        guard let png = rep.representation(using: .png, properties: [:]) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ww-icon-\(UUID().uuidString).png")
        do { try png.write(to: url); return url } catch { return nil }
    }
}
