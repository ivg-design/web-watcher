import Foundation

public enum HeraldPaths {
    public static let defaultPort = 48617

    public static var defaultSupportDirectory: URL {
        // HERALD_SUPPORT_DIR points a development build at its own data (token, port, history), so it can run
        // beside the installed Herald without touching it.
        if let override = ProcessInfo.processInfo.environment["HERALD_SUPPORT_DIR"], !override.isEmpty {
            return URL(fileURLWithPath: (override as NSString).expandingTildeInPath, isDirectory: true)
        }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Herald", isDirectory: true)
    }
    public static func tokenURL(in dir: URL = defaultSupportDirectory) -> URL { dir.appendingPathComponent("token") }
    public static func portURL(in dir: URL = defaultSupportDirectory) -> URL { dir.appendingPathComponent("port") }

    public static func readToken(in dir: URL = defaultSupportDirectory) -> String? {
        guard let s = try? String(contentsOf: tokenURL(in: dir), encoding: .utf8) else { return nil }
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    public static func readPort(in dir: URL = defaultSupportDirectory) -> Int? {
        guard let s = try? String(contentsOf: portURL(in: dir), encoding: .utf8) else { return nil }
        return Int(s.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
