import Foundation

/// Minimal HTTP server on 127.0.0.1 for OAuth redirect handling.
/// Binds to an OS-assigned port, listens for a single request, extracts query parameters, and returns an HTML response.
final class OAuthLoopbackListener: @unchecked Sendable {
    private var serverSocket: Int32 = -1
    private(set) var port: UInt16 = 0

    enum ListenerError: Error, LocalizedError {
        case bindFailed
        case listenFailed
        case acceptFailed
        case readFailed
        case missingCode
        case stateMismatch
        /// The provider redirected back with `error=<code>` (e.g. "access_denied",
        /// "admin_policy_enforced", "org_internal") instead of a code. Carries the raw
        /// code and optional `error_description` so a caller (`GmailOAuthService`) can map
        /// it to a specific, actionable error instead of a generic "missing code".
        case callbackError(code: String, description: String?)

        var errorDescription: String? {
            switch self {
            case .bindFailed: return "Failed to bind loopback server"
            case .listenFailed: return "Failed to listen on loopback server"
            case .acceptFailed: return "Failed to accept connection"
            case .readFailed: return "Failed to read request"
            case .missingCode: return "OAuth response missing authorization code"
            case .stateMismatch: return "OAuth state parameter mismatch"
            case .callbackError(let code, let description): return description ?? code
            }
        }
    }

    /// Start the server and return the assigned port
    func start() throws -> UInt16 {
        serverSocket = socket(AF_INET, SOCK_STREAM, 0)
        guard serverSocket >= 0 else { throw ListenerError.bindFailed }

        var reuse: Int32 = 1
        setsockopt(serverSocket, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = 0 // OS assigns port
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")

        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                bind(serverSocket, sockPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else {
            close(serverSocket)
            throw ListenerError.bindFailed
        }

        guard Darwin.listen(serverSocket, 1) == 0 else {
            close(serverSocket)
            throw ListenerError.listenFailed
        }

        // Get assigned port
        var boundAddr = sockaddr_in()
        var addrLen = socklen_t(MemoryLayout<sockaddr_in>.size)
        withUnsafeMutablePointer(to: &boundAddr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                getsockname(serverSocket, sockPtr, &addrLen)
            }
        }
        port = UInt16(bigEndian: boundAddr.sin_port)

        return port
    }

    /// Wait for the OAuth callback and extract the authorization code.
    /// Blocks until a request is received. Validates the state parameter.
    func waitForCallback(expectedState: String) throws -> String {
        defer { stop() }

        var clientAddr = sockaddr_in()
        var clientAddrLen = socklen_t(MemoryLayout<sockaddr_in>.size)
        let clientSocket = withUnsafeMutablePointer(to: &clientAddr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                accept(serverSocket, sockPtr, &clientAddrLen)
            }
        }

        guard clientSocket >= 0 else { throw ListenerError.acceptFailed }
        defer { close(clientSocket) }

        // Read the HTTP request
        var buffer = [UInt8](repeating: 0, count: 4096)
        let bytesRead = read(clientSocket, &buffer, buffer.count)
        guard bytesRead > 0 else { throw ListenerError.readFailed }

        let requestString = String(bytes: buffer[0..<bytesRead], encoding: .utf8) ?? ""

        // Parse query parameters from GET request
        // Format: GET /callback?code=...&state=... HTTP/1.1
        let params = parseQueryParams(from: requestString)

        // Check for error in response
        if let error = params["error"] {
            let html = buildErrorHTML(error: error, description: params["error_description"])
            sendHTTPResponse(to: clientSocket, html: html)
            throw ListenerError.callbackError(code: error, description: params["error_description"])
        }

        // Validate state
        guard let state = params["state"], state == expectedState else {
            let html = buildErrorHTML(error: "state_mismatch", description: "Security state parameter does not match")
            sendHTTPResponse(to: clientSocket, html: html)
            throw ListenerError.stateMismatch
        }

        // Extract code
        guard let code = params["code"] else {
            let html = buildErrorHTML(error: "missing_code", description: "No authorization code received")
            sendHTTPResponse(to: clientSocket, html: html)
            throw ListenerError.missingCode
        }

        // Send success response
        let html = buildSuccessHTML()
        sendHTTPResponse(to: clientSocket, html: html)

        return code
    }

    func stop() {
        if serverSocket >= 0 {
            close(serverSocket)
            serverSocket = -1
        }
    }

    // MARK: - Private

    private func parseQueryParams(from request: String) -> [String: String] {
        // Extract path from "GET /path?query HTTP/1.1"
        guard let firstLine = request.components(separatedBy: "\r\n").first,
              let pathPart = firstLine.split(separator: " ").dropFirst().first else {
            return [:]
        }

        let pathString = String(pathPart)
        guard let questionIndex = pathString.firstIndex(of: "?") else { return [:] }

        let queryString = String(pathString[pathString.index(after: questionIndex)...])
        var params: [String: String] = [:]

        for pair in queryString.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1)
            if parts.count == 2 {
                let key = String(parts[0])
                let value = String(parts[1]).removingPercentEncoding ?? String(parts[1])
                params[key] = value
            }
        }

        return params
    }

    private func sendHTTPResponse(to socket: Int32, html: String) {
        let response = """
        HTTP/1.1 200 OK\r
        Content-Type: text/html; charset=utf-8\r
        Content-Length: \(html.utf8.count)\r
        Connection: close\r
        \r
        \(html)
        """
        _ = response.withCString { ptr in
            write(socket, ptr, strlen(ptr))
        }
    }

    private func buildSuccessHTML() -> String {
        """
        <!DOCTYPE html>
        <html>
        <head><title>Web Watcher - Gmail Connected</title></head>
        <body style="font-family: -apple-system, sans-serif; text-align: center; padding: 60px;">
        <h1>Gmail Account Connected</h1>
        <p>You can close this tab and return to Web Watcher.</p>
        <script>setTimeout(function() { window.close(); }, 3000);</script>
        </body>
        </html>
        """
    }

    private func buildErrorHTML(error: String, description: String?) -> String {
        let desc = description ?? error
        return """
        <!DOCTYPE html>
        <html>
        <head><title>Web Watcher - Error</title></head>
        <body style="font-family: -apple-system, sans-serif; text-align: center; padding: 60px;">
        <h1>Authentication Failed</h1>
        <p>\(desc)</p>
        <p>Please close this tab and try again in Web Watcher.</p>
        </body>
        </html>
        """
    }
}
