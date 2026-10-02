import Foundation
import Network

/// A loopback-only (127.0.0.1) HTTP/1.1 listener. Used by Herald.app and by `HeraldCallbackServer`.
///
/// The listener is the first thing any local process (or any web page, through the browser) can reach, so it
/// is deliberately stingy before a request has proved itself:
/// - a request is answered or dropped as soon as its head says it should be (wrong `Host`, an `Origin`
///   header, the `headCheck` refusing it, a body that is too large), without buffering the body;
/// - the whole request must arrive within `readTimeout`, so an idle or dribbling socket is reaped;
/// - no more than `maxConnections` sockets are served at once.
public final class HTTPLoopbackListener: @unchecked Sendable {
    public typealias Handler = @Sendable (HTTPRequest) async -> HTTPResponse
    /// Looks at the request line and headers alone, before any body is read. Returning a response refuses the
    /// request: it is sent as the answer and the connection is closed.
    public typealias HeadCheck = @Sendable (HTTPHead) -> HTTPResponse?

    public static let defaultReadTimeout: TimeInterval = 10
    public static let defaultMaxConnections = 32

    public enum ListenerError: Error, LocalizedError {
        case invalidPort(Int)
        case failed(String)
        public var errorDescription: String? {
            switch self {
            case .invalidPort(let p): return "invalid port \(p)"
            case .failed(let m): return m
            }
        }
    }

    private let requestedPort: Int
    private let handler: Handler
    private let headCheck: HeadCheck?
    private let readTimeout: TimeInterval
    private let gate: ConnectionGate
    private let queue = DispatchQueue(label: "com.ivg.herald.listener")
    private var listener: NWListener?
    public private(set) var port: Int = 0

    /// `port` 0 means "let the OS pick".
    public init(port: Int, readTimeout: TimeInterval = HTTPLoopbackListener.defaultReadTimeout,
                maxConnections: Int = HTTPLoopbackListener.defaultMaxConnections,
                headCheck: HeadCheck? = nil, handler: @escaping Handler) {
        self.requestedPort = port
        self.handler = handler
        self.headCheck = headCheck
        self.readTimeout = readTimeout
        self.gate = ConnectionGate(limit: maxConnections)
    }

    /// Starts listening and blocks (up to 5 s) until the socket is bound.
    public func start() throws {
        guard (0...65535).contains(requestedPort) else { throw ListenerError.invalidPort(requestedPort) }
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        let p: NWEndpoint.Port = requestedPort == 0 ? .any : NWEndpoint.Port(rawValue: UInt16(requestedPort))!
        params.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: p)
        let l = try NWListener(using: params)

        let sem = DispatchSemaphore(value: 0)
        let box = ResultBox()
        l.stateUpdateHandler = { state in
            switch state {
            case .ready: box.set(nil); sem.signal()
            case .failed(let e): box.set("\(e)"); sem.signal()
            default: break
            }
        }
        let config = ServeConfig(handler: handler, headCheck: headCheck, readTimeout: readTimeout, queue: queue)
        let gate = self.gate
        l.newConnectionHandler = { conn in
            // Over the cap the socket is dropped on the spot; nothing is read from it.
            guard gate.enter() else { conn.cancel(); return }
            let once = Once()
            conn.stateUpdateHandler = { state in
                switch state {
                case .cancelled, .failed: if once.fire() { gate.leave() }
                default: break
                }
            }
            HTTPLoopbackListener.serve(conn, config: config)
        }
        l.start(queue: queue)
        if sem.wait(timeout: .now() + 5) == .timedOut {
            l.cancel()
            throw ListenerError.failed("timed out starting listener")
        }
        if let msg = box.error {
            l.cancel()
            throw ListenerError.failed(msg)
        }
        listener = l
        port = Int(l.port?.rawValue ?? UInt16(requestedPort))
    }

    public func stop() {
        listener?.cancel()
        listener = nil
    }

    private final class ResultBox: @unchecked Sendable {
        private let lock = NSLock()
        private var _error: String?
        func set(_ e: String?) { lock.lock(); _error = e; lock.unlock() }
        var error: String? { lock.lock(); defer { lock.unlock() }; return _error }
    }

    /// Counts the connections being served; `enter` refuses once `limit` are open.
    private final class ConnectionGate: @unchecked Sendable {
        private let lock = NSLock()
        private let limit: Int
        private var open = 0
        init(limit: Int) { self.limit = max(1, limit) }
        func enter() -> Bool {
            lock.lock(); defer { lock.unlock() }
            guard open < limit else { return false }
            open += 1
            return true
        }
        func leave() { lock.lock(); open = max(0, open - 1); lock.unlock() }
    }

    /// `.cancelled` and `.failed` can both be reported for one connection; it must leave the gate once.
    private final class Once: @unchecked Sendable {
        private let lock = NSLock()
        private var done = false
        func fire() -> Bool {
            lock.lock(); defer { lock.unlock() }
            if done { return false }
            done = true
            return true
        }
    }

    private struct ServeConfig: Sendable {
        var handler: Handler
        var headCheck: HeadCheck?
        var readTimeout: TimeInterval
        var queue: DispatchQueue
    }

    private final class Buffer: @unchecked Sendable {
        var data = Data()
        var head: HTTPHead?
    }

    /// Refusals decided from the head alone: a browser (`Origin`), a rebound DNS name (`Host`), then whatever
    /// the owner of the listener wants to check (the bearer token, for Herald itself).
    private static func refusal(for head: HTTPHead, headCheck: HeadCheck?) -> HTTPResponse? {
        if head.headers["origin"] != nil { return .error(403, "browser requests are not allowed") }
        if let host = head.headers["host"], !HTTPParser.isLoopbackHost(host) { return .error(403, "unexpected Host header") }
        return headCheck?(head)
    }

    private static func serve(_ conn: NWConnection, config: ServeConfig) {
        conn.start(queue: config.queue)
        let buffer = Buffer()

        // The whole request has to arrive within the deadline; it is lifted once the request is complete, so a
        // slow handler (a callback that takes seconds) is never cut off by it.
        let deadline = DispatchWorkItem { conn.cancel() }
        config.queue.asyncAfter(deadline: .now() + max(0.05, config.readTimeout), execute: deadline)

        func send(_ response: HTTPResponse) {
            deadline.cancel()
            conn.send(content: response.serialize(), completion: .contentProcessed { _ in conn.cancel() })
        }

        func receive() {
            conn.receive(minimumIncompleteLength: 1, maximumLength: 256 * 1024) { data, _, isComplete, error in
                if let data { buffer.data.append(data) }
                func waitForMore() { if error != nil || isComplete { deadline.cancel(); conn.cancel() } else { receive() } }

                if buffer.head == nil {
                    switch HTTPParser.parseHead(buffer.data) {
                    case .needMore:
                        return waitForMore()
                    case .bad(let status, let message):
                        return send(.error(status, message))
                    case .head(let head):
                        if let refused = refusal(for: head, headCheck: config.headCheck) { return send(refused) }
                        buffer.head = head
                    }
                }
                guard let head = buffer.head else { return }
                guard buffer.data.count - head.bodyStart >= head.contentLength else { return waitForMore() }
                deadline.cancel()
                let req = HTTPParser.makeRequest(head, from: buffer.data)
                let handler = config.handler
                Task { send(await handler(req)) }
            }
        }
        receive()
    }
}
