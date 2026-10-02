import Foundation
#if canImport(AppKit)
import AppKit
#endif

/// What an issuer's `openApp` action names (payload `buttons[].openApp`, or `bundleId` / `path` on a manifest
/// action). Both optional: with neither the issuing application itself is brought to the front.
public struct HeraldOpenApp: Codable, Equatable, Sendable {
    public var bundleId: String?
    public var path: String?
    public init(bundleId: String? = nil, path: String? = nil) { self.bundleId = bundleId; self.path = path }
}

/// What a template's banner click does (`onClick`). Absent is `url`: open the notification's link.
public enum HeraldBannerClick: String, Codable, CaseIterable, Sendable {
    /// Open the notification's `url` (and bring the app forward when it has none), as ever.
    case url
    /// Bring the issuing application to the front, whatever the notification links to.
    case openApp
}

/// Where applications are looked up. The default asks Launch Services and the usual Applications folders; tests
/// and validation can substitute their own.
public struct HeraldAppLookup: Sendable {
    public var bundleURL: @Sendable (String) -> URL?
    public var named: @Sendable (String) -> URL?
    public var pathExists: @Sendable (String) -> URL?

    public init(bundleURL: @escaping @Sendable (String) -> URL?, named: @escaping @Sendable (String) -> URL?,
                pathExists: @escaping @Sendable (String) -> URL?) {
        self.bundleURL = bundleURL; self.named = named; self.pathExists = pathExists
    }

    /// The folders an application called "Name" is looked for in.
    public static var applicationFolders: [String] {
        ["/Applications", "/Applications/Utilities", "/System/Applications", "/System/Applications/Utilities",
         (NSHomeDirectory() as NSString).appendingPathComponent("Applications")]
    }

    public static let system = HeraldAppLookup(
        bundleURL: { id in
            #if canImport(AppKit)
            return NSWorkspace.shared.urlForApplication(withBundleIdentifier: id)
            #else
            return nil
            #endif
        },
        named: { name in
            let file = name.hasSuffix(".app") ? name : name + ".app"
            for folder in HeraldAppLookup.applicationFolders {
                let url = URL(fileURLWithPath: folder).appendingPathComponent(file)
                if FileManager.default.fileExists(atPath: url.path) { return url }
            }
            return nil
        },
        pathExists: { path in
            let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
            var isDir: ObjCBool = false
            return url.pathExtension.lowercased() == "app" && FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
                && isDir.boolValue ? url : nil
        })

    /// Replaced in tests; `validate` and the app use it.
    public nonisolated(unsafe) static var current = HeraldAppLookup.system

    public func locate(_ target: HeraldOpenAppTarget) -> URL? {
        switch target {
        case .bundleId(let id): return bundleURL(id)
        case .path(let p): return pathExists(p)
        case .appName(let n): return named(n)
        }
    }
}

public enum HeraldOpenAppTarget: Equatable, Sendable {
    case bundleId(String)
    case path(String)
    case appName(String)
}

/// Which application an `openApp` action opens. The order is the contract (docs/reference/actions.md):
/// 1. the action's own `bundleId`, 2. its own `path`, 3. the manifest's `appBundleId`, 4. the manifest's `appPath`,
/// 5. the bundle id the issuer registered with, 6. the application whose name is the issuer's `appName`.
/// The first one that names an application that exists wins; a named one that does not exist is skipped.
public enum HeraldOpenAppResolver {
    public static func candidates(bundleId: String?, path: String?, manifest: HeraldManifest?,
                                  registeredBundleId: String? = nil, appName: String? = nil) -> [HeraldOpenAppTarget] {
        func clean(_ s: String?) -> String? {
            guard let t = s?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return nil }
            return t
        }
        var out: [HeraldOpenAppTarget] = []
        if let b = clean(bundleId) { out.append(.bundleId(b)) }
        if let p = clean(path) { out.append(.path(p)) }
        if let b = clean(manifest?.appBundleId) { out.append(.bundleId(b)) }
        if let p = clean(manifest?.appPath) { out.append(.path(p)) }
        if let b = clean(registeredBundleId) { out.append(.bundleId(b)) }
        if let n = clean(appName ?? manifest?.appName) { out.append(.appName(n)) }
        return out
    }

    /// What History records when the action finds no application (the banner stays up and nothing else happens).
    public static func notFoundNote(label: String) -> String { "\(label): no installed application found" }

    public static func resolve(_ candidates: [HeraldOpenAppTarget], lookup: HeraldAppLookup = .current)
        -> (url: URL, via: HeraldOpenAppTarget)? {
        for c in candidates { if let url = lookup.locate(c) { return (url, c) } }
        return nil
    }
}
