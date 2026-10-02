import Foundation

/// Listens on an OS-assigned loopback port and delivers button callbacks to a closure.
/// Register `callbackURL` with Herald (`register(... callbackURL:)`).
///
/// Herald treats any 2xx answer as "the action happened" and dismisses the banner; any other status keeps the
/// banner and flashes a failure. A client whose action can fail should use `init(statusHandler:)` and answer
/// 2xx only once the action succeeded (a 4xx is final, a 408/429/5xx makes Herald retry once).
public final class HeraldCallbackServer: @unchecked Sendable {
    /// Fire and forget: the event is acknowledged with 200 before anything is done with it.
    public typealias Handler = @Sendable (HeraldCallbackEvent) -> Void
    /// Returns the HTTP status to answer with. Herald waits at most 5 s for it.
    public typealias StatusHandler = @Sendable (HeraldCallbackEvent) async -> Int

    private let onEvent: StatusHandler
    private var listener: HTTPLoopbackListener?
    public private(set) var port: Int = 0

    /// The handler is invoked on a background queue.
    public init(handler: @escaping Handler) {
        self.onEvent = { event in handler(event); return 200 }
    }

    /// The status the handler returns is the answer Herald sees.
    public init(statusHandler: @escaping StatusHandler) { self.onEvent = statusHandler }

    public var callbackURL: String { "http://127.0.0.1:\(port)/herald" }

    public func start() throws {
        let onEvent = self.onEvent
        let l = HTTPLoopbackListener(port: 0) { req in
            guard req.method == "POST" else { return .error(405, "POST only") }
            guard let event = try? HeraldJSON.decoder().decode(HeraldCallbackEvent.self, from: req.body) else {
                return .error(400, "invalid callback payload")
            }
            let status = await onEvent(event)
            if (200..<300).contains(status) { return .json(status, ["ok": true]) }
            return .error(status, "callback not handled")
        }
        try l.start()
        listener = l
        port = l.port
    }

    public func stop() { listener?.stop(); listener = nil }
}
