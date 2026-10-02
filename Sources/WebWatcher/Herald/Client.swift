import Foundation

public enum HeraldError: Error, LocalizedError, Equatable {
    case notRunning
    case unauthorized
    case server(status: Int, message: String)
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .notRunning: return "Herald is not running (no token/port file or no answer on the port)."
        case .unauthorized: return "Herald rejected the token."
        case .server(let s, let m): return "Herald returned \(s): \(m)"
        case .invalidResponse: return "Unexpected response from Herald."
        }
    }
}

public struct HeraldHealth: Codable, Equatable, Sendable {
    public var ok: Bool
    public var version: String
    public var pid: Int
    public init(ok: Bool, version: String, pid: Int) { self.ok = ok; self.version = version; self.pid = pid }
}

/// Client for the Herald loopback API. Reads the token and port from Application Support.
public final class HeraldClient: @unchecked Sendable {
    public static let shared = HeraldClient()

    public let supportDirectory: URL
    private let session: URLSession
    private let portOverride: Int?
    private let tokenOverride: String?

    /// `port` and `token` override the `port` and `token` files in `supportDirectory` (the MCP server's
    /// `HERALD_PORT` / `HERALD_TOKEN`, for talking to a second Herald instance).
    public init(supportDirectory: URL = HeraldPaths.defaultSupportDirectory, port: Int? = nil, token: String? = nil) {
        self.supportDirectory = supportDirectory
        self.portOverride = port
        self.tokenOverride = token
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 5
        cfg.waitsForConnectivity = false
        self.session = URLSession(configuration: cfg)
    }

    public var token: String? { tokenOverride ?? HeraldPaths.readToken(in: supportDirectory) }
    public var port: Int { portOverride ?? HeraldPaths.readPort(in: supportDirectory) ?? HeraldPaths.defaultPort }

    /// True when token and port files exist and /v1/health answers (blocking, <= 1 s).
    public var isAvailable: Bool {
        guard token != nil, let url = URL(string: "http://127.0.0.1:\(port)/v1/health") else { return false }
        var req = URLRequest(url: url)
        req.timeoutInterval = 1
        let sem = DispatchSemaphore(value: 0)
        let ok = Flag()
        session.dataTask(with: req) { data, resp, _ in
            if let http = resp as? HTTPURLResponse, http.statusCode == 200,
               let data, (try? HeraldJSON.decoder().decode(HeraldHealth.self, from: data)) != nil { ok.value = true }
            sem.signal()
        }.resume()
        _ = sem.wait(timeout: .now() + 1.5)
        return ok.value
    }
    private final class Flag: @unchecked Sendable { var value = false }

    public func health() async throws -> HeraldHealth {
        try await send("GET", "/v1/health", auth: false)
    }

    /// Returns the notification id.
    @discardableResult
    public func notify(_ n: HeraldNotification) async throws -> String {
        struct R: Decodable { var id: String }
        let r: R = try await send("POST", "/v1/notify", body: n)
        return r.id
    }

    /// Says `text` aloud (DESIGN section 7.9): `POST /v1/speak`. Returns the history id.
    @discardableResult
    public func speak(_ r: HeraldSpeakRequest) async throws -> String {
        struct R: Decodable { var id: String }
        let x: R = try await send("POST", "/v1/speak", body: r)
        return x.id
    }

    /// Quiet hours (DESIGN section 7.9.1): the schedule and what is silenced now.
    public func quietHours() async throws -> HeraldQuietReply {
        try await send("GET", "/v1/settings/quiet-hours")
    }

    @discardableResult
    public func setQuietHours(_ update: HeraldQuietUpdate) async throws -> HeraldQuietReply {
        try await send("PUT", "/v1/settings/quiet-hours", body: update)
    }

    public func register(_ r: HeraldAppRegistration) async throws {
        let _: Ack = try await send("POST", "/v1/register", body: r)
    }

    public func dismiss(app: String, id: String) async throws {
        let _: Ack = try await send("POST", "/v1/dismiss", body: ["app": app, "id": id])
    }

    public func dismissAll(app: String) async throws {
        let _: Ack = try await send("POST", "/v1/dismissAll", body: ["app": app])
    }

    /// Dismisses every banner of `app` that was sent with this `group` (a stack, when stacking is by sender).
    public func dismissAll(app: String, group: String) async throws {
        let _: Ack = try await send("POST", "/v1/dismissAll", body: ["app": app, "group": group])
    }

    /// The stacks currently on screen (`GET /v1/stacks`), newest member first in each. `app` keeps only the
    /// stacks that hold a notification of that app.
    public func stacks(app: String? = nil) async throws -> [HeraldStackInfo] {
        struct R: Decodable { var stacks: [HeraldStackInfo] }
        var q: [URLQueryItem] = []
        if let app { q.append(URLQueryItem(name: "app", value: app)) }
        let r: R = try await send("GET", "/v1/stacks", query: q)
        return r.stacks
    }

    public func history(app: String? = nil, limit: Int = 50) async throws -> [HeraldHistoryItem] {
        struct R: Decodable { var items: [HeraldHistoryItem] }
        var q = [URLQueryItem(name: "limit", value: String(limit))]
        if let app { q.append(URLQueryItem(name: "app", value: app)) }
        let r: R = try await send("GET", "/v1/history", query: q)
        return r.items
    }

    private struct Ack: Decodable { var ok: Bool }
    private struct Empty: Encodable {}

    private func send<T: Decodable, B: Encodable>(_ method: String, _ path: String, query: [URLQueryItem] = [],
                                                  body: B?, auth: Bool = true) async throws -> T {
        var comps = URLComponents()
        comps.scheme = "http"; comps.host = "127.0.0.1"; comps.port = port; comps.path = path
        if !query.isEmpty { comps.queryItems = query }
        guard let url = comps.url else { throw HeraldError.invalidResponse }
        var req = URLRequest(url: url)
        req.httpMethod = method
        if auth {
            guard let token else { throw HeraldError.notRunning }
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            req.httpBody = try HeraldJSON.encoder().encode(body)
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let data: Data, resp: URLResponse
        do { (data, resp) = try await session.data(for: req) } catch { throw HeraldError.notRunning }
        guard let http = resp as? HTTPURLResponse else { throw HeraldError.invalidResponse }
        if http.statusCode == 401 { throw HeraldError.unauthorized }
        guard (200..<300).contains(http.statusCode) else {
            let msg = (try? JSONDecoder().decode([String: String].self, from: data))?["error"] ?? "error"
            throw HeraldError.server(status: http.statusCode, message: msg)
        }
        do { return try HeraldJSON.decoder().decode(T.self, from: data) } catch { throw HeraldError.invalidResponse }
    }

    private func send<T: Decodable>(_ method: String, _ path: String, query: [URLQueryItem] = [],
                                    auth: Bool = true) async throws -> T {
        try await send(method, path, query: query, body: Optional<Empty>.none, auth: auth)
    }
}

// MARK: - Herald 1.1: manifests, templates, components, shortcuts, preview (DESIGN section 7.5, 7.6)

/// The body of `POST /v1/preview`.
public struct HeraldPreviewRequest: Codable, Equatable, Sendable {
    /// A saved template's name (a string) or a full v2 template object.
    public var template: JSONValue
    public var app: String
    /// The string `"sample"` (the manifest's sample values) or an object of field values.
    public var data: JSONValue
    /// `light` or `dark`.
    public var appearance: String
    public var scale: Double

    public init(template: JSONValue, app: String, data: JSONValue = .string("sample"),
                appearance: String = "light", scale: Double = 2) {
        self.template = template; self.app = app; self.data = data
        self.appearance = appearance; self.scale = scale
    }

    public init(templateName: String, app: String, data: JSONValue = .string("sample"),
                appearance: String = "light", scale: Double = 2) {
        self.init(template: .string(templateName), app: app, data: data, appearance: appearance, scale: scale)
    }

    /// Previews an unsaved template.
    public init(template: HeraldTemplate, data: JSONValue = .string("sample"),
                appearance: String = "light", scale: Double = 2) throws {
        let encoded = try HeraldJSON.encoder().encode(template)
        self.init(template: try HeraldJSON.decoder().decode(JSONValue.self, from: encoded), app: template.app,
                  data: data, appearance: appearance, scale: scale)
    }
}

extension HeraldClient {
    public func apps() async throws -> [HeraldAppRegistration] {
        struct R: Decodable { var apps: [HeraldAppRegistration] }
        let r: R = try await send("GET", "/v1/apps")
        return r.apps
    }

    public func manifests() async throws -> [HeraldManifest] {
        struct R: Decodable { var items: [HeraldManifest] }
        let r: R = try await send("GET", "/v1/manifests")
        return r.items
    }

    /// nil when the app has no manifest (404).
    public func manifest(app: String) async throws -> HeraldManifest? {
        do { return try await send("GET", "/v1/manifest", query: [URLQueryItem(name: "app", value: app)]) }
        catch HeraldError.server(status: 404, _) { return nil }
    }

    public func putManifest(_ m: HeraldManifest) async throws {
        let _: Ack = try await send("PUT", "/v1/manifest", body: m)
    }

    public func deleteManifest(app: String) async throws {
        let _: Ack = try await send("DELETE", "/v1/manifest", query: [URLQueryItem(name: "app", value: app)])
    }

    /// Saved templates of `app`, or of every app when `app` is nil. (The four `builtin.*` templates are
    /// generated in code and not listed; see `BuiltinTemplates`.)
    public func templates(app: String? = nil) async throws -> [HeraldTemplate] {
        struct R: Decodable { var items: [HeraldTemplate] }
        let q = app.map { [URLQueryItem(name: "app", value: $0)] } ?? []
        let r: R = try await send("GET", "/v1/templates", query: q)
        return r.items
    }

    /// One saved template, or a built-in one for a `builtin.*` name; nil when there is none.
    public func template(app: String, name: String) async throws -> HeraldTemplate? {
        if BuiltinTemplates.isBuiltin(name) { return BuiltinTemplates.named(name, app: app) }
        return try await templates(app: app).first { $0.name == name }
    }

    public func putTemplate(_ t: HeraldTemplate) async throws {
        let _: Ack = try await send("PUT", "/v1/templates", body: t)
    }

    public func deleteTemplate(app: String, name: String) async throws {
        let _: Ack = try await send("DELETE", "/v1/templates",
                                    query: [URLQueryItem(name: "app", value: app), URLQueryItem(name: "name", value: name)])
    }

    /// `GET /v1/components`: the component schema document (the same value as `ComponentSchema.document()` for
    /// the running Herald's version).
    public func components() async throws -> JSONValue {
        try await send("GET", "/v1/components")
    }

    /// Names of the installed Apple Shortcuts.
    public func shortcuts() async throws -> [String] {
        struct R: Decodable { var items: [String] }
        let r: R = try await send("GET", "/v1/shortcuts")
        return r.items
    }

    /// Renders a template offscreen; the PNG bytes.
    public func preview(_ request: HeraldPreviewRequest) async throws -> Data {
        let body = try HeraldJSON.encoder().encode(request)
        let (status, data) = try await raw("POST", "/v1/preview", body: body, timeout: 30)
        guard (200..<300).contains(status) else { throw HeraldError.server(status: status, message: Self.errorMessage(in: data)) }
        guard data.count > 8, data.prefix(4) == Data([0x89, 0x50, 0x4E, 0x47]) else { throw HeraldError.invalidResponse }
        return data
    }

    /// Posts a notification payload exactly as given (so manifest fields at the top level reach Herald the way
    /// an issuer would send them). Returns the notification id.
    @discardableResult
    public func notify(payload: JSONValue) async throws -> String {
        struct R: Decodable { var id: String }
        let r: R = try await send("POST", "/v1/notify", body: payload)
        return r.id
    }

    // MARK: Raw requests

    /// One authenticated request; the status and body are returned as they came (only a transport failure
    /// and a 401 throw).
    func raw(_ method: String, _ path: String, query: [URLQueryItem] = [], body: Data? = nil,
             timeout: TimeInterval = 5) async throws -> (Int, Data) {
        var comps = URLComponents()
        comps.scheme = "http"; comps.host = "127.0.0.1"; comps.port = port; comps.path = path
        if !query.isEmpty { comps.queryItems = query }
        guard let url = comps.url else { throw HeraldError.invalidResponse }
        guard let token else { throw HeraldError.notRunning }
        var req = URLRequest(url: url, timeoutInterval: timeout)
        req.httpMethod = method
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body {
            req.httpBody = body
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let data: Data, resp: URLResponse
        do { (data, resp) = try await session.data(for: req) }
        catch let e as URLError where e.code == .timedOut {
            throw HeraldError.server(status: 504, message: "Herald did not answer within \(Int(timeout)) s")
        } catch { throw HeraldError.notRunning }
        guard let http = resp as? HTTPURLResponse else { throw HeraldError.invalidResponse }
        if http.statusCode == 401 { throw HeraldError.unauthorized }
        return (http.statusCode, data)
    }

    /// The `error` text of a JSON error body, followed by any other keys it carries (validation `issues`),
    /// as compact JSON. Falls back to "error".
    static func errorMessage(in data: Data) -> String {
        guard let v = try? HeraldJSON.decoder().decode(JSONValue.self, from: data), case .object(let o) = v else {
            return String(data: data.prefix(300), encoding: .utf8).flatMap { $0.isEmpty ? nil : $0 } ?? "error"
        }
        var text = "error"
        if case .string(let s)? = o["error"] { text = s }
        let rest = o.filter { $0.key != "error" }
        if !rest.isEmpty, let d = try? HeraldJSON.encoder().encode(JSONValue.object(rest)), let s = String(data: d, encoding: .utf8) {
            text += " " + s
        }
        return text
    }
}
