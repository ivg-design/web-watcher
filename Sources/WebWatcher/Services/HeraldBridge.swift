import Foundation
import AppKit

// MARK: - Seams (so tests never touch the network)

/// Whether Herald (the menu-bar notification service) is reachable. `HeraldClient` conforms;
/// tests substitute a fake.
protocol HeraldAvailability: AnyObject {
    /// Blocking (up to ~1.5 s) health check — call it off the main thread.
    var isAvailable: Bool { get }
    var port: Int { get }
}

/// The network calls the bridge makes. `LiveHeraldSender` talks to Herald; tests record.
protocol HeraldSending: AnyObject {
    /// Registers the app with Herald unless this exact registration is already current for the
    /// running Herald process (Herald forgets nothing, but a relaunched Herald has a new pid and
    /// our callback port changes every launch).
    func ensureRegistered(_ registration: HeraldAppRegistration) async throws
    /// Declares the issuer's manifest (`PUT /v1/manifest`) unless Herald already holds it for this
    /// run. A default template the user chose in Herald is kept.
    func ensureManifest(_ manifest: HeraldManifest) async throws
    /// Stores `template` (`PUT /v1/templates`) only when Herald has no template of that name for the app, or
    /// still holds an untouched earlier default of ours (`HeraldManifests.supersededDefaults`), so one the user
    /// edited is never overwritten.
    func ensureTemplate(_ template: HeraldTemplate) async throws
    func send(_ notification: HeraldNotification) async throws
    func dismiss(app: String, id: String) async
    /// Takes down every live banner of `app` (`POST /v1/dismissAll`). Best effort.
    func dismissAll(app: String) async
    /// The notifications Herald still has undismissed for `app` (on screen or snoozed). WebWatcher forgets
    /// which callback payloads it sent when it quits; this is how it learns them again.
    func liveNotifications(app: String) async throws -> [HeraldNotification]
}

extension HeraldSending {
    func ensureManifest(_ manifest: HeraldManifest) async throws {}
    func ensureTemplate(_ template: HeraldTemplate) async throws {}
    func liveNotifications(app: String) async throws -> [HeraldNotification] { [] }
    func dismissAll(app: String) async {}
}

/// The Herald endpoints the vendored `HeraldClient` has no method for: manifests, templates, and a notify
/// body that carries fields at the top level. Same token, same loopback port.
struct HeraldRawAPI: @unchecked Sendable {
    let client: HeraldClient
    private let session: URLSession

    init(client: HeraldClient = .shared) {
        self.client = client
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 5
        cfg.waitsForConnectivity = false
        self.session = URLSession(configuration: cfg)
    }

    func request(_ method: String, _ path: String, query: [URLQueryItem] = [], body: Data? = nil) async throws -> (status: Int, data: Data) {
        guard let token = client.token else { throw HeraldError.notRunning }
        var comps = URLComponents()
        comps.scheme = "http"; comps.host = "127.0.0.1"; comps.port = client.port; comps.path = path
        if !query.isEmpty { comps.queryItems = query }
        guard let url = comps.url else { throw HeraldError.invalidResponse }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body {
            req.httpBody = body
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let data: Data, resp: URLResponse
        do { (data, resp) = try await session.data(for: req) } catch { throw HeraldError.notRunning }
        guard let http = resp as? HTTPURLResponse else { throw HeraldError.invalidResponse }
        return (http.statusCode, data)
    }

    /// Throws for anything but 2xx, the way `HeraldClient` does.
    private func checked(_ result: (status: Int, data: Data)) throws -> Data {
        if result.status == 401 { throw HeraldError.unauthorized }
        guard (200..<300).contains(result.status) else {
            let message = (try? JSONDecoder().decode([String: String].self, from: result.data))?["error"] ?? "error"
            throw HeraldError.server(status: result.status, message: message)
        }
        return result.data
    }

    /// `POST /v1/notify` with a prepared body.
    func notify(body: Data) async throws {
        _ = try checked(try await request("POST", "/v1/notify", body: body))
    }

    /// `GET /v1/manifest?app=`; nil when Herald has none (404).
    func manifest(app: String) async throws -> HeraldManifest? {
        let result = try await request("GET", "/v1/manifest", query: [URLQueryItem(name: "app", value: app)])
        if result.status == 404 { return nil }
        return try? HeraldJSON.decoder().decode(HeraldManifest.self, from: try checked(result))
    }

    func putManifest(_ manifest: HeraldManifest) async throws {
        _ = try checked(try await request("PUT", "/v1/manifest", body: try HeraldJSON.encoder().encode(manifest)))
    }

    func templates(app: String) async throws -> [HeraldTemplate] {
        struct Reply: Decodable { var items: [HeraldTemplate] }
        let data = try checked(try await request("GET", "/v1/templates", query: [URLQueryItem(name: "app", value: app)]))
        return try HeraldJSON.decoder().decode(Reply.self, from: data).items
    }

    func putTemplate(_ template: HeraldTemplate) async throws {
        _ = try checked(try await request("PUT", "/v1/templates", body: try HeraldJSON.encoder().encode(template)))
    }
}

extension HeraldClient: HeraldAvailability {}

final class LiveHeraldSender: HeraldSending, @unchecked Sendable {
    private let client: HeraldClient
    private let api: HeraldRawAPI
    private let lock = NSLock()
    /// What has been told to the running Herald process, by app (or "app/template"). Cleared when a send
    /// fails: Herald may have restarted and forgotten nothing, but its pid and our callback port changed.
    private var registered: [String: String] = [:]
    private var manifests: [String: String] = [:]
    private var templates: Set<String> = []
    private var pidCache: (pid: Int, at: Date)?

    init(client: HeraldClient = .shared) {
        self.client = client
        self.api = HeraldRawAPI(client: client)
    }

    /// The running Herald's pid. Cached for a second so one delivery (register, manifest, template, send)
    /// asks once.
    private func currentPid() async throws -> Int {
        if let cached = lock.withLock({ pidCache }), Date().timeIntervalSince(cached.at) < 1 { return cached.pid }
        let pid = try await client.health().pid
        lock.withLock { pidCache = (pid, Date()) }
        return pid
    }

    private func forgetEverything() {
        lock.withLock {
            registered = [:]; manifests = [:]; templates = []; pidCache = nil
        }
    }

    func ensureRegistered(_ registration: HeraldAppRegistration) async throws {
        let pid = try await currentPid()
        let key = "\(pid)|\(registration.callbackURL ?? "")|\(registration.icon ?? "")|\(registration.appName ?? "")"
        if lock.withLock({ registered[registration.app] }) == key { return }
        try await client.register(registration)
        lock.withLock { registered[registration.app] = key }
    }

    func ensureManifest(_ manifest: HeraldManifest) async throws {
        let pid = try await currentPid()
        // Keyed on what WebWatcher wants (not on what Herald holds), so a delivery costs no request once this
        // run has declared it.
        let key = "\(pid)|" + ((try? String(data: HeraldJSON.encoder().encode(manifest), encoding: .utf8)) ?? "")
        if lock.withLock({ manifests[manifest.app] }) == key { return }
        var wanted = manifest
        let existing = try await api.manifest(app: manifest.app)
        // The user may have picked another default template in Herald ("Set as issuer default"): keep it.
        if let chosen = existing?.defaultTemplate, !chosen.isEmpty { wanted.defaultTemplate = chosen }
        if existing != wanted { try await api.putManifest(wanted) }
        lock.withLock { manifests[manifest.app] = key }
    }

    func ensureTemplate(_ template: HeraldTemplate) async throws {
        let pid = try await currentPid()
        let key = "\(pid)|\(template.app)/\(template.name)"
        if lock.withLock({ templates.contains(key) }) { return }
        let stored = try await api.templates(app: template.app)
        if HeraldManifests.shouldStore(template, over: stored.first(where: { $0.name == template.name })) {
            try await api.putTemplate(template)
        }
        lock.withLock { _ = templates.insert(key) }
    }

    func send(_ notification: HeraldNotification) async throws {
        do {
            if HeraldBridge.topLevelFields(of: notification).isEmpty {
                try await client.notify(notification)
            } else {
                try await api.notify(body: try HeraldBridge.wireBody(for: notification))
            }
        } catch {
            // Force a fresh registration next time (Herald may have restarted).
            forgetEverything()
            throw error
        }
    }

    func dismiss(app: String, id: String) async {
        try? await client.dismiss(app: app, id: id)
    }

    func dismissAll(app: String) async {
        try? await client.dismissAll(app: app)
    }

    func liveNotifications(app: String) async throws -> [HeraldNotification] {
        try await client.history(app: app, limit: 1000).filter { $0.dismissedAt == nil }.map(\.notification)
    }
}

// MARK: - Status

struct HeraldStatus: Equatable {
    var isRunning: Bool
    var port: Int

    /// The line shown under the delivery picker in Settings.
    var line: String {
        isRunning
            ? "Herald: running (port \(port))"
            : "Herald not running — using macOS notifications"
    }
}

// MARK: - Callback actions

/// What a Herald button callback asks WebWatcher to do. Decoded from the `payload` WebWatcher
/// itself attached to the button.
enum HeraldCallbackAction: Equatable {
    case gmail(action: String, accountId: UUID, messageIds: [String], emailWatcherId: UUID?)
    case openWatcher(watcherId: UUID)

    static func parse(_ payload: JSONValue?) -> HeraldCallbackAction? {
        guard case .object(let o)? = payload, case .string(let action)? = o["action"] else { return nil }

        if action == HeraldBridge.openAction {
            guard case .string(let w)? = o["watcherId"], let id = UUID(uuidString: w) else { return nil }
            return .openWatcher(watcherId: id)
        }

        guard HeraldBridge.gmailActionIdentifiers.contains(action),
              case .string(let a)? = o["accountId"], let accountId = UUID(uuidString: a),
              case .array(let rawIds)? = o["messageIds"] else { return nil }
        let messageIds: [String] = rawIds.compactMap {
            if case .string(let s) = $0 { return s }
            return nil
        }
        guard !messageIds.isEmpty else { return nil }
        var watcherId: UUID?
        if case .string(let w)? = o["emailWatcherId"] { watcherId = UUID(uuidString: w) }
        return .gmail(action: action, accountId: accountId, messageIds: messageIds, emailWatcherId: watcherId)
    }
}

// MARK: - Bridge

/// Sends WebWatcher's notifications to Herald when the user's delivery setting and Herald's
/// availability allow it, and otherwise hands control back to the caller's native
/// `UNUserNotificationCenter` path. Everything that maps WebWatcher data to a
/// `HeraldNotification` is a pure static function (see the `// MARK: Mapping` section).
final class HeraldBridge: @unchecked Sendable {
    /// The single app id WebWatcher used before it split into `HeraldIssuer`s. It is never registered or
    /// sent under any more; it is only named so a one-time cleanup can take down banners an older build left.
    static let legacyAppId = "webwatcher"
    /// Every app id whose banners and button callbacks belong to WebWatcher: the two issuers.
    static let allAppIds: [String] = HeraldIssuer.allCases.map(\.appId)

    static func isOurApp(_ app: String) -> Bool { allAppIds.contains(app) }

    static let shared = HeraldBridge()

    let availability: HeraldAvailability
    let sender: HeraldSending
    private let deliveryProvider: () -> NotificationDelivery

    private let lock = NSLock()
    private var callbackServer: HeraldCallbackServer?
    private var callbackURL: String?
    private var iconPath: String?
    private var onCallback: CallbackHandler?
    private var rehydrated = false
    private var legacyCleaned = false
    private var tail: Task<Void, Never>?

    /// What a Herald button callback is answered with: the HTTP status for Herald. 2xx means "done" (Herald
    /// dismisses the banner); anything else keeps the banner and shows a failure.
    typealias CallbackHandler = @Sendable (HeraldCallbackEvent, HeraldCallbackAction) async -> Int

    /// notification id → the callback payloads WebWatcher attached to it. The callback server is
    /// an unauthenticated loopback endpoint, so an incoming event is honoured only if its payload
    /// is byte-for-byte one WebWatcher sent for that notification (nothing else on the machine can
    /// make it archive or delete mail). Rebuilt from Herald's history after a relaunch (`rehydrate`),
    /// forgotten when WebWatcher dismisses the banner itself, and bounded by `expectedCapacity`.
    private var expected: [String: [JSONValue]] = [:]
    private var expectedOrder: [String] = []
    static let expectedCapacity = 1024

    init(availability: HeraldAvailability = HeraldClient.shared,
         sender: HeraldSending = LiveHeraldSender(),
         delivery: @escaping () -> NotificationDelivery = { AppSettings.shared.notificationDelivery }) {
        self.availability = availability
        self.sender = sender
        self.deliveryProvider = delivery
    }

    // MARK: Lifecycle

    /// Starts the callback listener, exports the app icon, and registers with Herald if it is
    /// already running. Safe to call more than once.
    func start(onCallback: @escaping CallbackHandler) {
        installCallbackHandler(onCallback)

        if lock.withLock({ callbackServer == nil }) {
            let server = HeraldCallbackServer(statusHandler: { [weak self] event in
                guard let self else { return 503 }
                return await self.handleCallback(event)
            })
            do {
                try server.start()
                lock.withLock {
                    callbackServer = server
                    callbackURL = server.callbackURL
                }
            } catch {
                print("Herald callback server failed to start: \(error)")
            }
        }

        if lock.withLock({ iconPath }) == nil, let path = Self.exportAppIcon() {
            lock.withLock { iconPath = path }
        }

        enqueue { [self] in
            guard deliveryProvider() == .heraldWhenAvailable, availability.isAvailable else { return }
            for issuer in HeraldIssuer.allCases { try? await prepare(app: issuer.appId) }
            await cleanUpLegacyBanners()
            await rehydrate()
        }
    }

    func installCallbackHandler(_ handler: @escaping CallbackHandler) {
        lock.withLock { onCallback = handler }
    }

    func stop() {
        lock.withLock {
            callbackServer?.stop()
            callbackServer = nil
            callbackURL = nil
        }
    }

    /// What WebWatcher registers for an issuer id: its own name, and the same callback URL, icon and bundle id
    /// for both, so every button reaches WebWatcher.
    func registration(for app: String) -> HeraldAppRegistration {
        let (icon, url) = lock.withLock { (iconPath, callbackURL) }
        return HeraldAppRegistration(
            app: app,
            appName: HeraldIssuer.issuer(forApp: app)?.appName,
            icon: icon,
            bundleId: Bundle.main.bundleIdentifier,
            callbackURL: url,
            allowCommands: false
        )
    }

    /// Registers `app` with Herald and, for one of WebWatcher's issuers, declares its default template and
    /// manifest. Registration is what delivery needs, so its failure propagates (the caller falls back to a
    /// macOS notification). The template and manifest only change how the banner looks: a Herald that
    /// predates them still shows the notification, so those failures are logged and swallowed.
    func prepare(app: String) async throws {
        // Only the two issuers are ever registered; anything else is sent without a registration.
        guard let issuer = HeraldIssuer.issuer(forApp: app) else { return }
        try await sender.ensureRegistered(registration(for: app))
        let icon = lock.withLock { iconPath }
        do {
            try await sender.ensureTemplate(HeraldManifests.defaultTemplate(for: issuer))
        } catch {
            print("Herald: could not store the default template for \(app) (\(error.localizedDescription))")
        }
        do {
            try await sender.ensureManifest(HeraldManifests.manifest(for: issuer, icon: icon))
        } catch {
            print("Herald: could not declare the manifest for \(app) (\(error.localizedDescription))")
        }
    }

    // MARK: Delivery

    /// Sends `notification` to Herald, or runs `fallback` (the native macOS path) when the setting
    /// is `.system`, Herald isn't running, or the send fails. Never both. Calls are serialised so
    /// two quick updates to the same id arrive in order.
    func deliver(_ notification: HeraldNotification, fallback: @escaping @Sendable () -> Void) {
        enqueue { [self] in await route(notification, fallback: fallback) }
    }

    /// The decision itself, awaitable so tests can drive it.
    func route(_ notification: HeraldNotification, fallback: @escaping @Sendable () -> Void) async {
        guard deliveryProvider() == .heraldWhenAvailable, availability.isAvailable else {
            fallback()
            return
        }
        remember(notification)
        do {
            try await prepare(app: notification.app)
            await rehydrate()
            try await sender.send(notification)
        } catch {
            print("Herald delivery failed (\(error.localizedDescription)); using a macOS notification instead")
            fallback()
        }
    }

    /// Removes a banner from Herald (e.g. once an email watcher's unread count drops to 0).
    func dismiss(id: String) {
        forget(id: id)   // the banner is going away, so nothing can call back for it any more
        guard deliveryProvider() == .heraldWhenAvailable else { return }
        let targets = Self.issuers(forNotificationId: id).map(\.appId)
        enqueue { [self] in
            for app in targets { await sender.dismiss(app: app, id: id) }
        }
    }

    /// The issuer(s) a notification id can belong to, from the ids this file builds: `watcher-…` and
    /// `health-…` are web, `gmail-…` and `emailwatcher-…` email; a preview (or anything else) could be either.
    static func issuers(forNotificationId id: String) -> [HeraldIssuer] {
        if id.hasPrefix("watcher-") || id.hasPrefix("health-") { return [.web] }
        if id.hasPrefix("gmail-") || id.hasPrefix("emailwatcher-") { return [.email] }
        return HeraldIssuer.allCases
    }

    /// Once per run: takes down any banner still live under the legacy app id (an older build's), which
    /// nothing can update or answer any more. Best effort; the legacy id is never registered again.
    func cleanUpLegacyBanners() async {
        let first = lock.withLock { () -> Bool in
            defer { legacyCleaned = true }
            return !legacyCleaned
        }
        guard first else { return }
        await sender.dismissAll(app: Self.legacyAppId)
    }

    /// Current availability for the Settings status line. Blocking — call off the main thread.
    func currentStatus() -> HeraldStatus {
        HeraldStatus(isRunning: availability.isAvailable, port: availability.port)
    }

    private func enqueue(_ work: @escaping @Sendable () async -> Void) {
        lock.lock()
        defer { lock.unlock() }
        let previous = tail
        tail = Task {
            _ = await previous?.value
            await work()
        }
    }

    // MARK: Callbacks

    /// The status Herald is answered with, after the action has been carried out (Herald dismisses the banner
    /// on a 2xx, so the answer must not come before the outcome is known): 403 for a request that is not one
    /// of WebWatcher's own buttons, otherwise whatever the handler decides.
    func handleCallback(_ event: HeraldCallbackEvent) async -> Int {
        guard Self.isOurApp(event.app), let payload = matchedPayload(event),
              let action = HeraldCallbackAction.parse(payload) else {
            print("Herald callback ignored (not a button WebWatcher sent): \(event.notificationId) \(event.action)")
            return 403
        }
        guard let handler = lock.withLock({ onCallback }) else { return 503 }
        return await handler(event, action)
    }

    /// Re-learns the payloads of the banners Herald still holds (undismissed in its history), once per run,
    /// so a button pressed after a WebWatcher relaunch is still recognised. Payloads already known for an id
    /// are kept; the restored ones are added beside them.
    func rehydrate() async {
        guard !lock.withLock({ rehydrated }) else { return }
        var live: [HeraldNotification] = []
        for app in Self.allAppIds {
            guard let items = try? await sender.liveNotifications(app: app) else { return }   // retried on the next call
            live += items
        }
        lock.withLock {
            for notification in live {
                guard let id = notification.id else { continue }
                let payloads = Self.callbackPayloads(of: notification)
                guard !payloads.isEmpty else { continue }
                if expected[id] == nil { expectedOrder.append(id) }
                var known = expected[id] ?? []
                for p in payloads where !known.contains(p) { known.append(p) }
                expected[id] = known
            }
            trimExpected()
            rehydrated = true
        }
    }

    func forget(id: String) {
        lock.withLock {
            expected[id] = nil
            expectedOrder.removeAll { $0 == id }
        }
    }

    func remember(_ notification: HeraldNotification) {
        guard let id = notification.id else { return }
        let payloads = Self.callbackPayloads(of: notification)
        lock.withLock {
            if payloads.isEmpty {
                expected[id] = nil
                expectedOrder.removeAll { $0 == id }
                return
            }
            if expected[id] == nil { expectedOrder.append(id) }
            expected[id] = payloads
            trimExpected()
        }
    }

    /// Lock held. The oldest ids go first.
    private func trimExpected() {
        while expectedOrder.count > Self.expectedCapacity {
            expected[expectedOrder.removeFirst()] = nil
        }
    }

    func isExpected(_ event: HeraldCallbackEvent) -> Bool { matchedPayload(event) != nil }

    /// The payload WebWatcher attached to the pressed button, or nil when the event is not one of ours.
    ///
    /// Herald hands the callback back with the template's `extra` values added under a top-level `"extra"` key
    /// (an object payload that does not use that key itself, or an object it makes of its own for a button with
    /// no payload). So an event that carries `extra` is compared without it, and the stored original is what
    /// the handler gets: WebWatcher never acts on a value the template or a request put there.
    func matchedPayload(_ event: HeraldCallbackEvent) -> JSONValue? {
        guard let payload = event.payload else { return nil }
        return lock.withLock {
            guard let known = expected[event.notificationId] else { return nil }
            if known.contains(payload) { return payload }
            guard case .object(var received) = payload, received["extra"] != nil else { return nil }
            received["extra"] = nil
            return known.first { stored in
                if case .object(let o) = stored, o["extra"] == nil { return JSONValue.object(received) == stored }
                return false
            }
        }
    }

    static func callbackPayloads(of notification: HeraldNotification) -> [JSONValue] {
        (notification.buttons ?? []).compactMap { $0.callback?.payload }
    }

    // MARK: Bounded wait

    /// Runs `work` and returns its result, or nil if it has not finished after `seconds`. The work is not
    /// cancelled when the wait gives up: it carries on in the background (a Gmail archive that is a little
    /// slow should still happen), the caller just stops waiting for it.
    static func boundedWait<T: Sendable>(seconds: TimeInterval, _ work: @escaping @Sendable () async -> T) async -> T? {
        await withCheckedContinuation { (continuation: CheckedContinuation<T?, Never>) in
            let once = OnceGate()
            let finish: @Sendable (T?) -> Void = { value in
                if once.fire() { continuation.resume(returning: value) }
            }
            let timer = Task {
                try? await Task.sleep(nanoseconds: UInt64(max(0, seconds) * 1_000_000_000))
                finish(nil)
            }
            Task {
                let value = await work()
                finish(value)
                timer.cancel()
            }
        }
    }

    private final class OnceGate: @unchecked Sendable {
        private let lock = NSLock()
        private var done = false
        func fire() -> Bool {
            lock.lock(); defer { lock.unlock() }
            if done { return false }
            done = true
            return true
        }
    }

    // MARK: Icon

    /// Exports the app icon as a PNG into Application Support/WebWatcher so Herald can show it.
    static func exportAppIcon(size: Int = 512) -> String? {
        let fm = FileManager.default
        guard let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let folder = support.appendingPathComponent("WebWatcher", isDirectory: true)
        try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("herald-icon.png")
        guard let data = pngData(for: NSApplication.shared.applicationIconImage, pixels: size) else { return nil }
        do {
            try data.write(to: url, options: .atomic)
            return url.path
        } catch {
            print("Failed to export Herald icon: \(error)")
            return nil
        }
    }

    static func pngData(for image: NSImage, pixels: Int) -> Data? {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        guard let context = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
        NSGraphicsContext.current = context
        image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels),
                   from: .zero, operation: .copy, fraction: 1)
        return rep.representation(using: .png, properties: [:])
    }
}

// MARK: - Mapping (pure)

extension HeraldBridge {

    // Gmail action identifiers — the same strings the native notification actions use.
    static let markReadAction = "GMAIL_MARK_READ"
    static let archiveAction = "GMAIL_ARCHIVE"
    static let deleteAction = "GMAIL_DELETE"
    static let spamAction = "GMAIL_SPAM"
    static let gmailActionIdentifiers: Set<String> = [markReadAction, archiveAction, deleteAction, spamAction]
    /// Callback action for the web-watcher "Open" button when the destination needs an API lookup.
    static let openAction = "WATCHER_OPEN"

    static func soundName(enabled: Bool) -> String { enabled ? "default" : "none" }

    private static func nonEmpty(_ s: String?) -> String? {
        guard let s, !s.isEmpty else { return nil }
        return s
    }

    private static func base(issuer: HeraldIssuer, id: String, title: String, subtitle: String?, body: String?,
                             image: String?, url: String?, sound: String,
                             buttons: [HeraldButton], metadata: [String: JSONValue],
                             group: String? = nil) -> HeraldNotification {
        var n = HeraldNotification(app: issuer.appId, id: id, title: title)
        n.group = nonEmpty(group)
        n.subtitle = nonEmpty(subtitle)
        n.body = nonEmpty(body)
        n.image = nonEmpty(image)
        n.url = nonEmpty(url)
        n.sound = sound
        n.persistent = true
        n.buttons = buttons.isEmpty ? nil : buttons
        n.metadata = .object(metadata)
        return n
    }

    // MARK: Fields on the wire

    /// The properties `HeraldNotification` itself models. Herald moves any other top-level key into
    /// `metadata`, so these are the keys a manifest field must not shadow. Read from the type, as Herald does.
    private static let notificationKeys: Set<String> = Set(
        Mirror(reflecting: HeraldNotification(app: "", title: "")).children.compactMap { $0.label })

    /// The manifest fields of `n` that travel at the top level of the notify payload (DESIGN 7.1: "fields
    /// are read from the payload's top-level keys first, then `metadata`"): the issuer's declared fields
    /// that `metadata` carries and that are not already a notification property (`title`, `image`, `url`,
    /// `subtitle` and `body` are). Empty for an app that is not one of ours, and blank values are left out.
    static func topLevelFields(of n: HeraldNotification) -> [String: JSONValue] {
        guard let issuer = HeraldIssuer.issuer(forApp: n.app), case .object(let metadata)? = n.metadata else { return [:] }
        var out: [String: JSONValue] = [:]
        for key in issuer.fieldKeys where !notificationKeys.contains(key) {
            switch metadata[key] {
            case .string(let s)? where !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty: out[key] = .string(s)
            case .number(let d)?: out[key] = .number(d)
            case .bool(let b)?: out[key] = .bool(b)
            case .array(let a)? where !a.isEmpty: out[key] = .array(a)
            default: break
            }
        }
        return out
    }

    /// The JSON body POSTed to `/v1/notify`: the notification as `HeraldNotification` encodes it, plus its
    /// fields at the top level (they stay in `metadata` too, which is where an older Herald reads them).
    static func wireBody(for n: HeraldNotification) throws -> Data {
        let encoded = try HeraldJSON.encoder().encode(n)
        guard case .object(var object) = try HeraldJSON.decoder().decode(JSONValue.self, from: encoded) else {
            return encoded
        }
        for (key, value) in topLevelFields(of: n) where object[key] == nil { object[key] = value }
        return try HeraldJSON.encoder().encode(JSONValue.object(object))
    }

    /// ISO 8601 UTC, the form a `date` field travels in.
    static func isoDate(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    /// "example.com" for "https://www.example.com/a/b": the host without a leading "www.".
    static func siteName(for urlString: String) -> String? {
        guard let host = URL(string: urlString)?.host, !host.isEmpty else { return nil }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    /// The number a count badge shows for a web watcher: its value when the watcher counts things (a badge
    /// number or an element count) and the value is a positive whole number; otherwise nothing to badge.
    static func webCount(watcher: Watcher, newValue: String) -> Int? {
        guard watcher.watchType == .badgeNumber || watcher.watchType == .elementCount,
              let n = Int(newValue.trimmingCharacters(in: .whitespaces)), n > 0 else { return nil }
        return n
    }

    // MARK: Buttons

    /// The four email buttons. `callback.url` is left nil so Herald posts to the callback URL the
    /// app registered. Their labels are the ones `HeraldManifests` declares, which is how Herald matches
    /// them to the manifest's action ids (markRead, archive, delete, spam).
    static func gmailButtons(accountId: UUID, messageIds: [String], emailWatcherId: UUID?) -> [HeraldButton] {
        func button(_ label: String, _ action: String, destructive: Bool) -> HeraldButton {
            var payload: [String: JSONValue] = [
                "action": .string(action),
                "accountId": .string(accountId.uuidString),
                "messageIds": .array(messageIds.map(JSONValue.string))
            ]
            if let emailWatcherId { payload["emailWatcherId"] = .string(emailWatcherId.uuidString) }
            return HeraldButton(label: label, style: destructive ? "destructive" : "default",
                                callback: HeraldCallback(payload: .object(payload)))
        }
        return [
            button("Mark as Read", markReadAction, destructive: false),
            button("Archive", archiveAction, destructive: true),
            button("Delete", deleteAction, destructive: true),
            button("Spam", spamAction, destructive: true)
        ]
    }

    static func gmailThreadURL(accountIndex: Int, threadId: String) -> String {
        "https://mail.google.com/mail/u/\(accountIndex)/#inbox/\(threadId)"
    }

    // MARK: Web watcher

    static func webWatcherNotificationId(_ watcherId: UUID) -> String { "watcher-\(watcherId.uuidString)" }
    static func healthNotificationId(_ watcherId: UUID) -> String { "health-\(watcherId.uuidString)" }

    /// The page a web watcher's banner opens: its custom action URL, else the watched page.
    static func destinationURL(for watcher: Watcher) -> String? {
        if let action = nonEmpty(watcher.actionURL) { return action }
        guard let page = URL(string: watcher.url) else { return nil }
        return page.absoluteString
    }

    /// "Open" button for a watcher. A watcher with an API lookup command resolves its destination
    /// at click time, which only WebWatcher can do, so that one is a callback button.
    static func openButtons(for watcher: Watcher, url: String?) -> [HeraldButton] {
        if let cmd = watcher.apiLookupCommand, !cmd.isEmpty {
            return [HeraldButton(label: "Open", style: "default", callback: HeraldCallback(payload: .object([
                "action": .string(openAction),
                "watcherId": .string(watcher.id.uuidString)
            ])))]
        }
        guard let url else { return [] }
        return [HeraldButton(label: "Open", style: "default", url: url)]
    }

    /// A web-watcher change (or its preview — pass a `preview-…` id). Sent as `webwatcher.web`: the manifest's
    /// fields (`value`, `previous`, `watcherName`, `site`, `count`) ride in `metadata` and, via `wireBody`,
    /// at the top level.
    static func webWatcher(watcher: Watcher, content: WatcherNotificationContent,
                           newValue: String, oldValue: String?, id: String,
                           isPreview: Bool = false) -> HeraldNotification {
        let url = destinationURL(for: watcher)
        var metadata: [String: JSONValue] = [
            "type": .string("watcher"),
            "watcherId": .string(watcher.id.uuidString),
            "watcherName": .string(watcher.name),
            "watcherURL": .string(watcher.url),
            "name": .string(watcher.name),
            "value": .string(newValue),
            "previous": .string(oldValue ?? "")
        ]
        if let site = siteName(for: watcher.url) { metadata["site"] = .string(site) }
        if let count = webCount(watcher: watcher, newValue: newValue) { metadata["count"] = .number(Double(count)) }
        if isPreview { metadata["preview"] = .bool(true) }
        return base(issuer: .web, id: id, title: content.title, subtitle: content.subtitle, body: content.body,
                    image: watcher.customIconPath, url: url,
                    sound: soundName(enabled: isPreview || watcher.notificationSound),
                    buttons: openButtons(for: watcher, url: url), metadata: metadata,
                    group: siteName(for: watcher.url)?.lowercased())
    }

    /// "<watcher> isn't working" — same id the native path uses.
    static func watcherBroken(watcher: Watcher, content: WatcherNotificationContent,
                              reason: CannotReason) -> HeraldNotification {
        let url = destinationURL(for: watcher)
        var metadata: [String: JSONValue] = [
            "type": .string("health"),
            "watcherId": .string(watcher.id.uuidString),
            "watcherName": .string(watcher.name),
            "watcherURL": .string(watcher.url),
            "name": .string(watcher.name),
            "reason": .string(reason.shortStatus)
        ]
        if let site = siteName(for: watcher.url) { metadata["site"] = .string(site) }
        return base(issuer: .web, id: healthNotificationId(watcher.id),
                    title: content.title, subtitle: content.subtitle, body: content.body,
                    image: watcher.customIconPath, url: url, sound: soundName(enabled: false),
                    buttons: openButtons(for: watcher, url: url), metadata: metadata,
                    group: siteName(for: watcher.url)?.lowercased())
    }

    // MARK: Gmail

    /// The manifest fields every email notification carries: who it is from, the subject, a snippet and when
    /// it arrived. `count` is added only for a banner that stands for several messages.
    private static func messageFields(_ message: GmailMessage, count: Int) -> [String: JSONValue] {
        var m: [String: JSONValue] = [
            "sender": .string(message.senderName.isEmpty ? message.senderAddress : message.senderName),
            "address": .string(message.senderAddress),
            "subject": .string(message.subject),
            "receivedAt": .string(isoDate(message.date))
        ]
        let snippet = message.snippet.trimmingCharacters(in: .whitespacesAndNewlines)
        if !snippet.isEmpty { m["snippet"] = .string(String(snippet.prefix(300))) }
        if count > 1 { m["count"] = .number(Double(count)) }
        return m
    }

    /// Per-message Gmail notification ("notify for every new email"). Sent as `webwatcher.email`.
    static func gmailMessage(message: GmailMessage, account: GmailAccount,
                             content: EmailNotificationContent) -> HeraldNotification {
        var metadata = messageFields(message, count: 1)
        metadata["type"] = .string("gmail")
        metadata["accountId"] = .string(account.id.uuidString)
        metadata["account"] = .string(account.email)
        metadata["messageId"] = .string(message.messageId)
        metadata["threadId"] = .string(message.threadId)
        // The banner binds {body}. The macOS text carries the label ids and the account ("Hello [INBOX] — me@x.com"),
        // which is noise on a banner, so Herald gets the snippet alone.
        let snippet = message.snippet.trimmingCharacters(in: .whitespacesAndNewlines)
        return base(issuer: .email, id: "gmail-\(message.messageId)",
                    title: content.title, subtitle: content.subtitle, body: snippet.isEmpty ? nil : String(snippet.prefix(300)),
                    image: nil,
                    url: gmailThreadURL(accountIndex: account.accountIndex, threadId: message.threadId),
                    sound: soundName(enabled: account.notificationSound),
                    buttons: gmailButtons(accountId: account.id, messageIds: [message.messageId], emailWatcherId: nil),
                    metadata: metadata, group: senderGroup(message.senderAddress))
    }

    /// The Herald stacking key for mail: the sender address, lowercased (nil when unknown).
    static func senderGroup(_ address: String) -> String? {
        let a = address.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return a.isEmpty ? nil : a
    }

    private static func emailMetadata(watcher: EmailWatcher, message: GmailMessage, account: GmailAccount,
                                      count: Int, isPreview: Bool) -> [String: JSONValue] {
        var m = messageFields(message, count: count)
        m["type"] = .string("emailWatcher")
        m["emailWatcherId"] = .string(watcher.id.uuidString)
        m["name"] = .string(watcher.name)
        m["accountId"] = .string(account.id.uuidString)
        m["account"] = .string(account.email)
        m["messageId"] = .string(message.messageId)
        m["threadId"] = .string(message.threadId)
        if isPreview { m["preview"] = .bool(true) }
        return m
    }

    /// A single message that matched an email watcher.
    static func emailWatcherMessage(watcher: EmailWatcher, message: GmailMessage, account: GmailAccount,
                                    content: EmailNotificationContent) -> HeraldNotification {
        base(issuer: .email, id: "gmail-\(message.messageId)-\(watcher.id.uuidString)",
             title: content.title, subtitle: content.subtitle, body: content.body,
             image: watcher.customIconPath,
             url: gmailThreadURL(accountIndex: account.accountIndex, threadId: message.threadId),
             sound: soundName(enabled: watcher.notificationSound),
             buttons: gmailButtons(accountId: account.id, messageIds: [message.messageId], emailWatcherId: watcher.id),
             metadata: emailMetadata(watcher: watcher, message: message, account: account, count: 1, isPreview: false),
             group: senderGroup(message.senderAddress))
    }

    /// The one accumulated notification per email watcher. Same id on every update, so Herald
    /// replaces the banner in place. Buttons act on every counted unread message.
    static func emailWatcherAccumulated(watcher: EmailWatcher, newest: GmailMessage, account: GmailAccount,
                                        content: EmailNotificationContent,
                                        idOverride: String? = nil,
                                        isPreview: Bool = false) -> HeraldNotification {
        let messageIds = watcher.unreadMessageIds.isEmpty ? [newest.messageId] : watcher.unreadMessageIds
        let url = watcher.openURL(accountIndex: account.accountIndex)?.absoluteString
            ?? gmailThreadURL(accountIndex: account.accountIndex, threadId: newest.threadId)
        return base(issuer: .email, id: idOverride ?? "emailwatcher-\(watcher.id.uuidString)",
                    title: content.title, subtitle: content.subtitle, body: content.body,
                    image: watcher.customIconPath, url: url,
                    sound: soundName(enabled: isPreview || watcher.notificationSound),
                    buttons: gmailButtons(accountId: account.id, messageIds: messageIds, emailWatcherId: watcher.id),
                    metadata: emailMetadata(watcher: watcher, message: newest, account: account,
                                            count: max(watcher.unreadCount, 1), isPreview: isPreview),
                    group: watcher.senders.first.flatMap(senderGroup) ?? senderGroup(newest.senderAddress))
    }
}
