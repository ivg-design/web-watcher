import Foundation

// A JSON passthrough for the routes that have no typed model: the parity routes (settings, per-app settings, assets,
// bundles, History search, symbols, voice, MCP install, approvals). The MCP server's tools for them are thin
// wrappers over `call`; nothing is decided on this side of the wire.

extension HeraldClient {
    /// One authenticated JSON request. `query` pairs with an empty value are left out. A non-2xx answer throws
    /// `HeraldError.server` with the `error` text Herald sent.
    public func call(_ method: String, _ path: String, query: [String: String] = [:], body: JSONValue? = nil,
                     timeout: TimeInterval = 20) async throws -> JSONValue {
        let items = query.filter { !$0.value.isEmpty }.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        let data = try body.map { try HeraldJSON.encoder().encode($0) }
        let (status, reply) = try await raw(method, path, query: items, body: data, timeout: timeout)
        guard (200..<300).contains(status) else { throw HeraldError.server(status: status, message: Self.errorMessage(in: reply)) }
        if reply.isEmpty { return .object([:]) }
        do { return try HeraldJSON.decoder().decode(JSONValue.self, from: reply) } catch { throw HeraldError.invalidResponse }
    }

    /// The Designer window's content drawn offscreen (`POST /v1/designer/snapshot`): PNG bytes.
    public func designerSnapshot(app: String? = nil, template: String? = nil, select: String? = nil,
                                 width: Int? = nil, height: Int? = nil) async throws -> Data {
        var q: [URLQueryItem] = []
        if let app { q.append(URLQueryItem(name: "app", value: app)) }
        if let template { q.append(URLQueryItem(name: "template", value: template)) }
        if let select { q.append(URLQueryItem(name: "select", value: select)) }
        if let width { q.append(URLQueryItem(name: "width", value: String(width))) }
        if let height { q.append(URLQueryItem(name: "height", value: String(height))) }
        let (status, data) = try await raw("GET", "/v1/designer/snapshot", query: q, timeout: 30)
        guard (200..<300).contains(status) else { throw HeraldError.server(status: status, message: Self.errorMessage(in: data)) }
        guard data.count > 8, data.prefix(4) == Data([0x89, 0x50, 0x4E, 0x47]) else { throw HeraldError.invalidResponse }
        return data
    }
}
