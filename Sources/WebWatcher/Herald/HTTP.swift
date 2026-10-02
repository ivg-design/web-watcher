import Foundation

public struct HTTPRequest: Sendable {
    public var method: String
    public var path: String
    public var query: [String: String]
    /// Header names are lowercased.
    public var headers: [String: String]
    public var body: Data
    public init(method: String, path: String, query: [String: String] = [:],
                headers: [String: String] = [:], body: Data = Data()) {
        self.method = method; self.path = path; self.query = query
        self.headers = headers; self.body = body
    }
}

public struct HTTPResponse: Sendable {
    public var status: Int
    public var body: Data
    /// Extra response headers (the fixed ones, Content-Type/Content-Length/Connection, are always written).
    public var headers: [String: String]
    /// The `Content-Type` written on the response: JSON unless a route returns something else (`image/png`).
    public var contentType: String
    public init(status: Int, body: Data = Data(), headers: [String: String] = [:],
                contentType: String = "application/json") {
        self.status = status; self.body = body; self.headers = headers; self.contentType = contentType
    }

    /// A binary 200 response, such as the PNG of `/v1/preview`.
    public static func png(_ data: Data) -> HTTPResponse {
        HTTPResponse(status: 200, body: data, contentType: "image/png")
    }

    public static func json<T: Encodable>(_ status: Int = 200, _ value: T) -> HTTPResponse {
        let data = (try? HeraldJSON.encoder().encode(value)) ?? Data("{}".utf8)
        return HTTPResponse(status: status, body: data)
    }

    public static func error(_ status: Int, _ message: String) -> HTTPResponse {
        json(status, ["error": message])
    }

    public static func reason(_ status: Int) -> String {
        switch status {
        case 200: return "OK"
        case 400: return "Bad Request"
        case 401: return "Unauthorized"
        case 403: return "Forbidden"
        case 404: return "Not Found"
        case 405: return "Method Not Allowed"
        case 409: return "Conflict"
        case 413: return "Payload Too Large"
        case 429: return "Too Many Requests"
        case 504: return "Gateway Timeout"
        default: return status >= 500 ? "Internal Server Error" : "Status"
        }
    }

    public func serialize() -> Data {
        var head = "HTTP/1.1 \(status) \(HTTPResponse.reason(status))\r\n"
        for (name, value) in headers.sorted(by: { $0.key < $1.key }) {
            // A header value is never allowed to smuggle a second header or the end of the head.
            // (unicodeScalars: "\r\n" is a single Character in Swift and would slip through a Character filter.)
            let clean = String(String.UnicodeScalarView(value.unicodeScalars.filter { $0 != "\r" && $0 != "\n" }))
            head += "\(name): \(clean)\r\n"
        }
        let type = String(String.UnicodeScalarView(contentType.unicodeScalars.filter { $0 != "\r" && $0 != "\n" }))
        head += "Content-Type: \(type)\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n"
        var out = Data(head.utf8)
        out.append(body)
        return out
    }
}

public enum HTTPParseResult {
    case needMore
    case request(HTTPRequest, consumed: Int)
    case bad(status: Int, message: String)
}

/// The request line and headers of a request whose body has not been read yet. The listener hands this to
/// its pre-body check, so a caller that is not allowed in is turned away before a single body byte is buffered.
public struct HTTPHead: Sendable {
    public var method: String
    /// The request target as sent: path and query string.
    public var target: String
    /// Header names are lowercased.
    public var headers: [String: String]
    /// The declared `Content-Length` (0 when absent).
    public var contentLength: Int
    /// Offset of the first body byte in the buffer the head was parsed from.
    public var bodyStart: Int

    public init(method: String, target: String, headers: [String: String] = [:], contentLength: Int = 0, bodyStart: Int = 0) {
        self.method = method; self.target = target; self.headers = headers
        self.contentLength = contentLength; self.bodyStart = bodyStart
    }

    public var path: String {
        target.firstIndex(of: "?").map { String(target[..<$0]) } ?? target
    }
}

public enum HTTPHeadResult {
    case needMore
    case head(HTTPHead)
    case bad(status: Int, message: String)
}

/// Minimal HTTP/1.1 request parser: request line, headers, Content-Length body.
public enum HTTPParser {
    public static let maxHeaderBytes = 64 * 1024
    /// Every legitimate payload (text fields, 64 KB of metadata, a 256 KB image or icon spec) fits in this,
    /// so it is also the most any caller, authenticated or not, can make Herald buffer for one request.
    public static let maxBodyBytes = 1024 * 1024

    /// Parses the request line and headers as soon as the blank line that ends them has arrived, and
    /// rejects a head that is oversized, malformed or announces a body larger than `maxBodyBytes`.
    public static func parseHead(_ data: Data, maxBody: Int = maxBodyBytes) -> HTTPHeadResult {
        let sep = Data("\r\n\r\n".utf8)
        guard let r = data.range(of: sep) else {
            return data.count > maxHeaderBytes ? .bad(status: 400, message: "headers too large") : .needMore
        }
        guard r.lowerBound - data.startIndex <= maxHeaderBytes else { return .bad(status: 400, message: "headers too large") }
        guard let head = String(data: data.subdata(in: data.startIndex..<r.lowerBound), encoding: .utf8) else {
            return .bad(status: 400, message: "invalid header encoding")
        }
        let lines = head.components(separatedBy: "\r\n")
        let parts = lines[0].split(separator: " ", omittingEmptySubsequences: true)
        guard parts.count == 3, parts[2].hasPrefix("HTTP/1.") else {
            return .bad(status: 400, message: "malformed request line")
        }
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colon = line.firstIndex(of: ":") else { return .bad(status: 400, message: "malformed header") }
            let name = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            headers[name] = value
        }
        if let te = headers["transfer-encoding"], te.lowercased() != "identity" {
            return .bad(status: 400, message: "chunked bodies are not supported; send Content-Length")
        }
        var length = 0
        if let cl = headers["content-length"] {
            guard let n = Int(cl), n >= 0 else { return .bad(status: 400, message: "invalid Content-Length") }
            length = n
        }
        if length > maxBody { return .bad(status: 413, message: "payload too large") }
        return .head(HTTPHead(method: String(parts[0]).uppercased(), target: String(parts[1]), headers: headers,
                              contentLength: length, bodyStart: r.upperBound - data.startIndex))
    }

    /// Builds the request once `data` holds the whole body announced by `head`.
    public static func makeRequest(_ head: HTTPHead, from data: Data) -> HTTPRequest {
        let start = data.startIndex + head.bodyStart
        let body = data.subdata(in: start..<(start + head.contentLength))
        var path = head.target
        var query: [String: String] = [:]
        if let q = head.target.firstIndex(of: "?") {
            path = String(head.target[..<q])
            if let comps = URLComponents(string: "http://x/?" + head.target[head.target.index(after: q)...]) {
                for item in comps.queryItems ?? [] { query[item.name] = item.value ?? "" }
            }
        }
        return HTTPRequest(method: head.method, path: path, query: query, headers: head.headers, body: body)
    }

    public static func parse(_ input: Data) -> HTTPParseResult {
        let data = Data(input)
        switch parseHead(data) {
        case .needMore: return .needMore
        case .bad(let status, let message): return .bad(status: status, message: message)
        case .head(let head):
            guard data.count - head.bodyStart >= head.contentLength else { return .needMore }
            return .request(makeRequest(head, from: data), consumed: head.bodyStart + head.contentLength)
        }
    }

    /// True for `127.0.0.1`, `localhost` and `[::1]`, with or without a port: the only names a local
    /// client uses to reach Herald. A browser tricked into talking to Herald through a rebound DNS name
    /// sends that attacker's name in `Host`.
    public static func isLoopbackHost(_ value: String) -> Bool {
        var h = value.trimmingCharacters(in: .whitespaces).lowercased()
        if h.hasPrefix("[") {
            guard let close = h.firstIndex(of: "]") else { return false }
            h = String(h[h.index(after: h.startIndex)..<close])
        } else if let colon = h.lastIndex(of: ":") {
            h = String(h[..<colon])
        }
        return h == "127.0.0.1" || h == "localhost" || h == "::1"
    }
}
