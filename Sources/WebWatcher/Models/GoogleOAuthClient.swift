import Foundation

/// A Google OAuth "Desktop app" client the user downloads from Google Cloud Console and
/// imports once (G1). Never written to the watchers/accounts JSON — `clientSecret` is a
/// credential, so it only ever lives in the Keychain via `GoogleOAuthClientStore`.
struct GoogleOAuthClient: Codable, Equatable {
    var clientId: String
    var clientSecret: String
    var projectId: String?
    /// e.g. the imported file's name, shown in Settings so the user can tell which
    /// download they last imported.
    var sourceName: String?

    var isValid: Bool {
        clientId.hasSuffix(".apps.googleusercontent.com") && !clientSecret.isEmpty
    }

    /// First 12 characters of the client ID plus an ellipsis, for display without exposing
    /// the whole ID (which itself isn't secret, but a short form reads better in a status line).
    var shortId: String {
        String(clientId.prefix(12)) + "…"
    }
}

// MARK: - Built-in client (§9.6)

extension GoogleOAuthClient {
    /// The client embedded in this build's app bundle: the Google-downloaded
    /// `google-oauth-client.json` (installed unchanged by the user via
    /// `scripts/install-google-client.sh`, copied into the app bundle's Resources by an
    /// Xcode Run Script build phase). `nil` whenever there is nothing to resolve — the
    /// resource is absent (a fresh clone, a SwiftPM test bundle) or fails to parse —
    /// `builtIn` must never throw or crash a build that ships with no embedded client.
    static var builtIn: GoogleOAuthClient? {
        guard let url = Bundle.main.url(forResource: "google-oauth-client", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? GoogleOAuthClientParser.parse(data)
    }
}

/// Parses the JSON Google Cloud Console offers for download when creating an OAuth client.
enum GoogleOAuthClientParser {

    enum ParseError: LocalizedError {
        case notJSON
        case unsupportedType(String)
        case missingFields

        var errorDescription: String? {
            switch self {
            case .notJSON:
                return "That file isn't valid JSON."
            case .unsupportedType("web"):
                return "This is a Web application client. Create a Desktop app client instead."
            case .unsupportedType(let type):
                return "Unsupported client type \"\(type)\". Create a Desktop app client instead."
            case .missingFields:
                return "That JSON is missing client_id or client_secret."
            }
        }
    }

    private struct RawInstalled: Decodable {
        let client_id: String
        let client_secret: String
        let project_id: String?
    }

    /// Accepts Google's downloadable JSON: `{"installed": {...}}` (Desktop app clients).
    /// `{"web": {...}}` is rejected by name — a Web client can't do the PKCE + loopback
    /// flow this app uses — and so is any other root key, so the user knows exactly what
    /// kind of file they picked.
    static func parse(_ data: Data) throws -> GoogleOAuthClient {
        guard let raw = try? JSONSerialization.jsonObject(with: data),
              let json = raw as? [String: Any] else {
            throw ParseError.notJSON
        }

        guard let installedRaw = json["installed"] else {
            if let key = json.keys.first {
                throw ParseError.unsupportedType(key)
            }
            throw ParseError.notJSON
        }

        guard let installedData = try? JSONSerialization.data(withJSONObject: installedRaw),
              let installed = try? JSONDecoder().decode(RawInstalled.self, from: installedData),
              !installed.client_id.isEmpty, !installed.client_secret.isEmpty else {
            throw ParseError.missingFields
        }

        return GoogleOAuthClient(
            clientId: installed.client_id,
            clientSecret: installed.client_secret,
            projectId: installed.project_id,
            sourceName: nil
        )
    }

    /// Looks for `client_secret*.json` in ~/Downloads, newest first. Read-only — never
    /// writes to or deletes from the user's Downloads folder.
    static func candidateFilesInDownloads() -> [URL] {
        guard let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first,
              let files = try? FileManager.default.contentsOfDirectory(
                  at: downloads, includingPropertiesForKeys: [.contentModificationDateKey]
              ) else {
            return []
        }

        return files
            .filter { $0.lastPathComponent.hasPrefix("client_secret") && $0.pathExtension == "json" }
            .sorted { a, b in
                let da = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let db = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return da > db
            }
    }
}

/// Keychain-backed storage for the imported OAuth client override, resolved against the
/// app's built-in client (§9.6). Only one override is supported at a time (the app isn't
/// multi-tenant), so there's no per-account keying.
final class GoogleOAuthClientStore {
    static let shared = GoogleOAuthClientStore()

    private static let service = "com.webwatcher.app.google-oauth-client"
    private static let account = "default"

    /// nil in tests: load/save/clear become in-memory only, so a test run never touches
    /// the real Keychain.
    private let keychain: KeychainService?
    /// Injectable so tests can supply a fabricated client without depending on
    /// `Bundle.main` actually shipping `google-oauth-client.json`.
    private let builtIn: GoogleOAuthClient?

    /// The resolved answer — `override ?? builtIn` — cached after the first `load()` so
    /// repeated `isConfigured`/`load()` checks (the editor and Settings both poll this)
    /// never re-hit the Keychain or re-resolve `builtIn`.
    private var resolved: GoogleOAuthClient?
    private var resolvedIsOverride = false
    private var didLoad = false

    init(keychain: KeychainService? = KeychainService.shared, builtIn: GoogleOAuthClient? = GoogleOAuthClient.builtIn) {
        self.keychain = keychain
        self.builtIn = builtIn
    }

    /// Keychain override first, else the built-in client. Resolved once and cached: a
    /// second `load()` call with nothing changed returns the exact same value (in
    /// particular, the same non-nil built-in) rather than re-resolving.
    func load() -> GoogleOAuthClient? {
        if !didLoad {
            didLoad = true
            if let data = keychain?.loadData(service: Self.service, account: Self.account),
               let override = try? JSONDecoder().decode(GoogleOAuthClient.self, from: data) {
                resolved = override
                resolvedIsOverride = true
            } else {
                resolved = builtIn
                resolvedIsOverride = false
            }
        }
        return resolved
    }

    func save(_ client: GoogleOAuthClient) {
        resolved = client
        resolvedIsOverride = true
        didLoad = true
        guard let data = try? JSONEncoder().encode(client) else { return }
        keychain?.saveData(service: Self.service, account: Self.account, data: data)
    }

    /// Removes the override and re-resolves to the built-in client — a subsequent
    /// `load()` returns `builtIn` immediately, with no stale override cached.
    func clear() {
        keychain?.deleteData(service: Self.service, account: Self.account)
        resolved = builtIn
        resolvedIsOverride = false
        didLoad = true
    }

    var isConfigured: Bool {
        load()?.isValid ?? false
    }

    /// True when the resolved client came from an imported override rather than the
    /// built-in client — Settings uses this to label which one is active.
    var isUsingOverride: Bool {
        _ = load()
        return resolvedIsOverride
    }

    /// True when this build has an embedded Google client at all, regardless of whether
    /// an override is currently active.
    var builtInAvailable: Bool {
        builtIn != nil
    }
}
