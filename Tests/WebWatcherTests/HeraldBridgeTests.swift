import XCTest
@testable import WebWatcher

/// Coverage for the Herald bridge. The mapping from WebWatcher data to `HeraldNotification` is
/// pure, and the delivery decision runs against a fake availability and a fake sender, so nothing
/// here touches the network, Herald, or Notification Center.
final class HeraldBridgeTests: XCTestCase {

    // MARK: - Fakes

    private final class FakeAvailability: HeraldAvailability {
        var isAvailable: Bool
        var port: Int
        init(available: Bool, port: Int = 48617) { self.isAvailable = available; self.port = port }
    }

    private final class FakeSender: HeraldSending, @unchecked Sendable {
        var registrations: [HeraldAppRegistration] = []
        var manifests: [HeraldManifest] = []
        var templates: [HeraldTemplate] = []
        var sent: [HeraldNotification] = []
        var dismissed: [String] = []
        var dismissedApps: [String] = []
        var dismissedAll: [String] = []
        /// Every call in order, e.g. "register:webwatcher.web", "manifest:...", "template:...", "send:<id>".
        var log: [String] = []
        var failure: Error?
        var manifestFailure: Error?
        var templateFailure: Error?
        var live: [HeraldNotification] = []
        var liveFailure: Error?
        var liveCalls = 0
        func liveNotifications(app: String) async throws -> [HeraldNotification] {
            liveCalls += 1
            if let liveFailure { throw liveFailure }
            return live
        }
        func ensureRegistered(_ registration: HeraldAppRegistration) async throws {
            if let failure { throw failure }
            registrations.append(registration)
            log.append("register:\(registration.app)")
        }
        func ensureManifest(_ manifest: HeraldManifest) async throws {
            if let manifestFailure { throw manifestFailure }
            manifests.append(manifest)
            log.append("manifest:\(manifest.app)")
        }
        func ensureTemplate(_ template: HeraldTemplate) async throws {
            if let templateFailure { throw templateFailure }
            templates.append(template)
            log.append("template:\(template.app)/\(template.name)")
        }
        func send(_ notification: HeraldNotification) async throws {
            if let failure { throw failure }
            sent.append(notification)
            log.append("send:\(notification.id ?? "")")
        }
        func dismissAll(app: String) async { dismissedAll.append(app); log.append("dismissAll:\(app)") }
        func dismiss(app: String, id: String) async { dismissed.append(id); dismissedApps.append(app); log.append("dismiss:\(app)/\(id)") }
    }

    private final class Counter: @unchecked Sendable {
        private let lock = NSLock()
        private var n = 0
        func bump() { lock.lock(); n += 1; lock.unlock() }
        var value: Int { lock.lock(); defer { lock.unlock() }; return n }
    }

    private func bridge(available: Bool, delivery: NotificationDelivery = .heraldWhenAvailable,
                        sender: FakeSender = FakeSender()) -> (HeraldBridge, FakeSender) {
        (HeraldBridge(availability: FakeAvailability(available: available), sender: sender, delivery: { delivery }), sender)
    }

    // MARK: - Fixtures

    private let accountId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private let watcherId = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!

    private func makeWatcher(sound: Bool = true, actionURL: String? = "https://example.com/inbox",
                             apiLookup: String? = nil, icon: String? = "/tmp/icon.png") -> Watcher {
        Watcher(id: watcherId, name: "Inbox", url: "https://example.com/page", selector: ".badge",
                watchType: .badgeNumber, notificationSound: sound, actionURL: actionURL,
                apiLookupCommand: apiLookup, customIconPath: icon)
    }

    private func makeAccount(sound: Bool = true) -> GmailAccount {
        GmailAccount(id: accountId, email: "me@example.com", notificationSound: sound, accountIndex: 2)
    }

    private func makeMessage(id: String = "m1", thread: String = "t1") -> GmailMessage {
        GmailMessage(accountId: accountId, messageId: id, threadId: thread,
                     from: "Jane Doe <jane@acme.com>", subject: "Invoice #42",
                     date: Date(timeIntervalSince1970: 1_700_000_000), labelIds: ["INBOX"], snippet: "Hello")
    }

    private func makeEmailWatcher(sound: Bool = true) -> EmailWatcher {
        var w = EmailWatcher(id: watcherId, name: "Acme", accountId: accountId, senders: ["jane@acme.com"],
                             notificationSound: sound)
        w.customIconPath = "/tmp/acme.png"
        w.unreadMessageIds = ["m1", "m2", "m3"]
        w.unreadCount = 3
        w.lastMatchThreadId = "t1"
        return w
    }

    private func string(_ value: JSONValue?) -> String? {
        if case .string(let s)? = value { return s }
        return nil
    }

    private func metadata(_ n: HeraldNotification) -> [String: JSONValue] {
        if case .object(let o)? = n.metadata { return o }
        return [:]
    }

    // MARK: - Web watcher

    func testWebWatcherMapsEveryField() {
        let watcher = makeWatcher()
        let text = NotificationService.watcherContent(watcher: watcher, newValue: "3", oldValue: "0")
        let n = HeraldBridge.webWatcher(watcher: watcher, content: text, newValue: "3", oldValue: "0",
                                        id: HeraldBridge.webWatcherNotificationId(watcher.id))

        XCTAssertEqual(n.app, "webwatcher.web")
        XCTAssertEqual(n.id, "watcher-22222222-2222-2222-2222-222222222222")
        XCTAssertEqual(n.title, "Inbox")
        XCTAssertEqual(n.body, "You have 3 new messages")
        XCTAssertNil(n.subtitle, "empty subtitle must not be sent")
        XCTAssertEqual(n.image, "/tmp/icon.png")
        XCTAssertEqual(n.url, "https://example.com/inbox")
        XCTAssertEqual(n.sound, "default")
        XCTAssertEqual(n.persistent, true)
        XCTAssertEqual(n.buttons?.map(\.label), ["Open"])
        XCTAssertEqual(n.buttons?.first?.url, "https://example.com/inbox")
        XCTAssertNil(n.buttons?.first?.callback)
        XCTAssertEqual(string(metadata(n)["watcherId"]), watcher.id.uuidString)
        XCTAssertEqual(string(metadata(n)["value"]), "3")
        XCTAssertEqual(string(metadata(n)["previous"]), "0")
    }

    func testWebWatcherSoundFollowsToggle() {
        let watcher = makeWatcher(sound: false)
        let text = NotificationService.watcherContent(watcher: watcher, newValue: "1", oldValue: nil)
        let n = HeraldBridge.webWatcher(watcher: watcher, content: text, newValue: "1", oldValue: nil, id: "watcher-x")
        XCTAssertEqual(n.sound, "none")
    }

    func testWebWatcherFallsBackToPageURLAndOmitsEmptyIcon() {
        let watcher = makeWatcher(actionURL: nil, icon: "")
        let text = NotificationService.watcherContent(watcher: watcher, newValue: "1", oldValue: nil)
        let n = HeraldBridge.webWatcher(watcher: watcher, content: text, newValue: "1", oldValue: nil, id: "watcher-x")
        XCTAssertEqual(n.url, "https://example.com/page")
        XCTAssertNil(n.image)
    }

    func testWebWatcherWithAPILookupGetsACallbackOpenButton() throws {
        let watcher = makeWatcher(apiLookup: "echo https://x")
        let text = NotificationService.watcherContent(watcher: watcher, newValue: "1", oldValue: nil)
        let n = HeraldBridge.webWatcher(watcher: watcher, content: text, newValue: "1", oldValue: nil, id: "watcher-x")
        let button = try XCTUnwrap(n.buttons?.first)
        XCTAssertEqual(button.label, "Open")
        XCTAssertNil(button.url)
        XCTAssertEqual(HeraldCallbackAction.parse(button.callback?.payload), .openWatcher(watcherId: watcher.id))
    }

    func testTextChangeSubtitleCarriesTheNewValue() {
        var watcher = makeWatcher()
        watcher.watchType = .textChange
        let text = NotificationService.watcherContent(watcher: watcher, newValue: "Order shipped", oldValue: "Packed")
        let n = HeraldBridge.webWatcher(watcher: watcher, content: text, newValue: "Order shipped", oldValue: "Packed", id: "watcher-x")
        XCTAssertEqual(n.subtitle, "Order shipped")
        XCTAssertEqual(n.body, "Content updated")
    }

    func testPreviewIsLabelledAlwaysAudibleAndFlagged() {
        let watcher = makeWatcher(sound: false)
        let text = NotificationService.watcherContent(watcher: watcher, newValue: "3", oldValue: "0", isPreview: true)
        let n = HeraldBridge.webWatcher(watcher: watcher, content: text, newValue: "3", oldValue: "0",
                                        id: "preview-abc", isPreview: true)
        XCTAssertEqual(n.title, "[Preview] Inbox")
        XCTAssertEqual(n.id, "preview-abc")
        XCTAssertEqual(n.sound, "default")
        XCTAssertEqual(metadata(n)["preview"], .bool(true))
    }

    func testBrokenWatcherNotificationIsSilentAndKeepsItsId() {
        let watcher = makeWatcher()
        let text = NotificationService.brokenContent(watcher: watcher, reason: .signedOut)
        let n = HeraldBridge.watcherBroken(watcher: watcher, content: text, reason: .signedOut)
        XCTAssertEqual(n.id, "health-\(watcher.id.uuidString)")
        XCTAssertEqual(n.title, "Inbox isn't working")
        XCTAssertEqual(n.subtitle, CannotReason.signedOut.shortStatus)
        XCTAssertEqual(n.body, CannotReason.signedOut.remedy)
        XCTAssertEqual(n.sound, "none")
        XCTAssertEqual(n.persistent, true)
        XCTAssertEqual(string(metadata(n)["type"]), "health")
    }

    // MARK: - Gmail

    func testGmailMessageMapping() throws {
        let account = makeAccount()
        let message = makeMessage()
        let text = NotificationService.gmailContent(message: message, account: account)
        let n = HeraldBridge.gmailMessage(message: message, account: account, content: text)

        XCTAssertEqual(n.id, "gmail-m1")
        XCTAssertEqual(n.title, "Jane Doe")
        XCTAssertEqual(n.subtitle, "Invoice #42")
        XCTAssertEqual(n.body, "Hello", "the banner binds {body}: the snippet, without the label ids and account the macOS text carries")
        XCTAssertEqual(n.url, "https://mail.google.com/mail/u/2/#inbox/t1")
        XCTAssertEqual(n.sound, "default")
        XCTAssertEqual(n.persistent, true)
        XCTAssertEqual(n.buttons?.map(\.label), ["Mark as Read", "Archive", "Delete", "Spam"])
        XCTAssertEqual(n.buttons?.map(\.style), ["default", "destructive", "destructive", "destructive"])
        for button in try XCTUnwrap(n.buttons) {
            XCTAssertNil(button.url)
            XCTAssertNil(button.callback?.url, "callbacks go to the app's registered callback URL")
        }
    }

    func testGmailButtonPayloadsRoundTripThroughTheParser() throws {
        let buttons = HeraldBridge.gmailButtons(accountId: accountId, messageIds: ["a", "b"], emailWatcherId: watcherId)
        let actions = try buttons.map { try XCTUnwrap(HeraldCallbackAction.parse($0.callback?.payload)) }
        XCTAssertEqual(actions, [
            .gmail(action: "GMAIL_MARK_READ", accountId: accountId, messageIds: ["a", "b"], emailWatcherId: watcherId),
            .gmail(action: "GMAIL_ARCHIVE", accountId: accountId, messageIds: ["a", "b"], emailWatcherId: watcherId),
            .gmail(action: "GMAIL_DELETE", accountId: accountId, messageIds: ["a", "b"], emailWatcherId: watcherId),
            .gmail(action: "GMAIL_SPAM", accountId: accountId, messageIds: ["a", "b"], emailWatcherId: watcherId)
        ])
    }

    func testPayloadWithoutWatcherIdParsesToNil() throws {
        let button = try XCTUnwrap(HeraldBridge.gmailButtons(accountId: accountId, messageIds: ["a"], emailWatcherId: nil).first)
        XCTAssertEqual(HeraldCallbackAction.parse(button.callback?.payload),
                       .gmail(action: "GMAIL_MARK_READ", accountId: accountId, messageIds: ["a"], emailWatcherId: nil))
    }

    func testParserRejectsMalformedPayloads() {
        XCTAssertNil(HeraldCallbackAction.parse(nil))
        XCTAssertNil(HeraldCallbackAction.parse(.string("GMAIL_DELETE")))
        XCTAssertNil(HeraldCallbackAction.parse(.object(["action": .string("RM_RF")])))
        XCTAssertNil(HeraldCallbackAction.parse(.object([
            "action": .string("GMAIL_DELETE"), "accountId": .string("not-a-uuid"), "messageIds": .array([.string("a")])
        ])))
        XCTAssertNil(HeraldCallbackAction.parse(.object([
            "action": .string("GMAIL_DELETE"), "accountId": .string(accountId.uuidString), "messageIds": .array([])
        ])))
        XCTAssertNil(HeraldCallbackAction.parse(.object([
            "action": .string("GMAIL_DELETE"), "accountId": .string(accountId.uuidString)
        ])))
        XCTAssertNil(HeraldCallbackAction.parse(.object(["action": .string("WATCHER_OPEN"), "watcherId": .string("nope")])))
    }

    // MARK: - Email watchers

    func testEmailWatcherMessageIdIsKeyedByWatcher() {
        let watcher = makeEmailWatcher()
        let account = makeAccount()
        let message = makeMessage()
        let text = NotificationService.emailWatcherContent(watcher: watcher, message: message, account: account)
        let n = HeraldBridge.emailWatcherMessage(watcher: watcher, message: message, account: account, content: text)

        XCTAssertEqual(n.id, "gmail-m1-\(watcher.id.uuidString)")
        XCTAssertEqual(n.title, "Acme")
        XCTAssertEqual(n.image, "/tmp/acme.png")
        XCTAssertEqual(n.url, "https://mail.google.com/mail/u/2/#inbox/t1")
        XCTAssertEqual(n.buttons?.count, 4)
        XCTAssertEqual(HeraldCallbackAction.parse(n.buttons?.first?.callback?.payload),
                       .gmail(action: "GMAIL_MARK_READ", accountId: accountId, messageIds: ["m1"], emailWatcherId: watcher.id))
    }

    func testAccumulatedNotificationReplacesInPlaceAndActsOnAllUnread() {
        let watcher = makeEmailWatcher()
        let account = makeAccount()
        let newest = makeMessage(id: "m3")
        let text = NotificationService.emailWatcherAccumulatedContent(watcher: watcher, newest: newest, account: account, accountCount: 1)
        let n = HeraldBridge.emailWatcherAccumulated(watcher: watcher, newest: newest, account: account, content: text)

        XCTAssertEqual(n.id, NotificationService.emailWatcherNotificationIdentifier(watcher.id))
        XCTAssertEqual(n.id, "emailwatcher-\(watcher.id.uuidString)")
        XCTAssertEqual(n.title, "3 new from Jane Doe")
        XCTAssertEqual(n.persistent, true)
        XCTAssertEqual(n.sound, "default")
        XCTAssertEqual(n.image, "/tmp/acme.png")
        // More than one unread → the unread search, not a single thread.
        XCTAssertEqual(n.url, watcher.openURL(accountIndex: 2)?.absoluteString)
        XCTAssertEqual(HeraldCallbackAction.parse(n.buttons?.last?.callback?.payload),
                       .gmail(action: "GMAIL_SPAM", accountId: accountId, messageIds: ["m1", "m2", "m3"], emailWatcherId: watcher.id))

        // A second update for the same watcher keeps the id (Herald replaces the banner).
        var updated = watcher
        updated.unreadMessageIds.append("m4")
        updated.unreadCount = 4
        let n2 = HeraldBridge.emailWatcherAccumulated(watcher: updated, newest: makeMessage(id: "m4"), account: account, content: text)
        XCTAssertEqual(n2.id, n.id)
    }

    func testAccumulatedSoundFollowsWatcherToggleAndPreviewIsAudible() {
        let silent = makeEmailWatcher(sound: false)
        let account = makeAccount()
        let newest = makeMessage()
        let text = NotificationService.emailWatcherAccumulatedContent(watcher: silent, newest: newest, account: account, accountCount: 1)
        XCTAssertEqual(HeraldBridge.emailWatcherAccumulated(watcher: silent, newest: newest, account: account, content: text).sound, "none")

        let preview = HeraldBridge.emailWatcherAccumulated(watcher: silent, newest: newest, account: account, content: text,
                                                            idOverride: "preview-1", isPreview: true)
        XCTAssertEqual(preview.id, "preview-1")
        XCTAssertEqual(preview.sound, "default")
        XCTAssertEqual(metadata(preview)["preview"], .bool(true))
    }

    func testAccumulatedFallsBackToNewestMessageWhenUnreadListIsEmpty() {
        var watcher = makeEmailWatcher()
        watcher.unreadMessageIds = []
        watcher.unreadCount = 1
        let account = makeAccount()
        let newest = makeMessage(id: "only")
        let text = NotificationService.emailWatcherAccumulatedContent(watcher: watcher, newest: newest, account: account, accountCount: 1)
        let n = HeraldBridge.emailWatcherAccumulated(watcher: watcher, newest: newest, account: account, content: text)
        XCTAssertEqual(HeraldCallbackAction.parse(n.buttons?.first?.callback?.payload),
                       .gmail(action: "GMAIL_MARK_READ", accountId: accountId, messageIds: ["only"], emailWatcherId: watcher.id))
    }

    func testMappedNotificationEncodesToHeraldJSON() throws {
        let watcher = makeEmailWatcher()
        let account = makeAccount()
        let newest = makeMessage()
        let text = NotificationService.emailWatcherAccumulatedContent(watcher: watcher, newest: newest, account: account, accountCount: 1)
        let n = HeraldBridge.emailWatcherAccumulated(watcher: watcher, newest: newest, account: account, content: text)

        let data = try HeraldJSON.encoder().encode(n)
        let decoded = try HeraldJSON.decoder().decode(HeraldNotification.self, from: data)
        XCTAssertEqual(decoded, n)
    }

    // MARK: - Delivery decision

    func testSendsToHeraldWhenAvailableAndDoesNotFallBack() async {
        let (bridge, sender) = bridge(available: true)
        let fallback = Counter()
        let n = HeraldNotification(app: "webwatcher.web", id: "watcher-1", title: "Hi")

        await bridge.route(n) { fallback.bump() }

        XCTAssertEqual(sender.sent.map(\.id), ["watcher-1"])
        XCTAssertEqual(sender.registrations.count, 1)
        XCTAssertEqual(sender.registrations.first?.app, "webwatcher.web")
        XCTAssertEqual(sender.registrations.first?.appName, "WebWatcher · Web")
        XCTAssertEqual(sender.registrations.first?.allowCommands, false)
        XCTAssertEqual(fallback.value, 0)
    }

    func testFallsBackToSystemWhenHeraldIsNotRunning() async {
        let (bridge, sender) = bridge(available: false)
        let fallback = Counter()
        await bridge.route(HeraldNotification(app: "webwatcher.email", id: "x", title: "Hi")) { fallback.bump() }
        XCTAssertEqual(fallback.value, 1)
        XCTAssertTrue(sender.sent.isEmpty)
        XCTAssertTrue(sender.registrations.isEmpty)
    }

    func testSystemSettingNeverUsesHeraldEvenWhenRunning() async {
        let (bridge, sender) = bridge(available: true, delivery: .system)
        let fallback = Counter()
        await bridge.route(HeraldNotification(app: "webwatcher.email", id: "x", title: "Hi")) { fallback.bump() }
        XCTAssertEqual(fallback.value, 1)
        XCTAssertTrue(sender.sent.isEmpty)
    }

    func testFallsBackWhenTheSendFails() async {
        let sender = FakeSender()
        sender.failure = HeraldError.notRunning
        let (bridge, _) = bridge(available: true, sender: sender)
        let fallback = Counter()
        await bridge.route(HeraldNotification(app: "webwatcher.email", id: "x", title: "Hi")) { fallback.bump() }
        XCTAssertEqual(fallback.value, 1)
        XCTAssertTrue(sender.sent.isEmpty)
    }

    func testDismissOnlyGoesToHeraldWhenThatIsTheChosenDelivery() async throws {
        let (herald, heraldSender) = bridge(available: true)
        herald.dismiss(id: "emailwatcher-1")
        let (system, systemSender) = bridge(available: true, delivery: .system)
        system.dismiss(id: "emailwatcher-1")

        // Dismissals are queued; give the serial queue a moment.
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertEqual(heraldSender.dismissed, ["emailwatcher-1"])
        XCTAssertTrue(systemSender.dismissed.isEmpty)
    }

    // MARK: - Callback validation

    func testOnlyPayloadsWebWatcherSentAreExpected() throws {
        let (bridge, _) = bridge(available: true)
        let account = makeAccount()
        let watcher = makeEmailWatcher()
        let newest = makeMessage()
        let text = NotificationService.emailWatcherAccumulatedContent(watcher: watcher, newest: newest, account: account, accountCount: 1)
        let n = HeraldBridge.emailWatcherAccumulated(watcher: watcher, newest: newest, account: account, content: text)
        bridge.remember(n)

        let genuine = try XCTUnwrap(n.buttons?[2].callback?.payload)
        XCTAssertTrue(bridge.isExpected(HeraldCallbackEvent(notificationId: n.id!, app: "webwatcher.email", action: "Delete", payload: genuine)))

        // Same notification, different messages: a forged request must not pass.
        let forged = HeraldBridge.gmailButtons(accountId: accountId, messageIds: ["someone-elses-mail"], emailWatcherId: nil)[2].callback?.payload
        XCTAssertFalse(bridge.isExpected(HeraldCallbackEvent(notificationId: n.id!, app: "webwatcher.email", action: "Delete", payload: forged)))
        // Right payload, unknown notification.
        XCTAssertFalse(bridge.isExpected(HeraldCallbackEvent(notificationId: "other", app: "webwatcher.email", action: "Delete", payload: genuine)))
        // No payload at all.
        XCTAssertFalse(bridge.isExpected(HeraldCallbackEvent(notificationId: n.id!, app: "webwatcher.email", action: "Delete", payload: nil)))
    }

    func testTemplateExtraInTheCallbackPayloadStillCountsAsOurButton() throws {
        let (bridge, _) = bridge(available: true)
        let account = makeAccount()
        let watcher = makeEmailWatcher()
        let newest = makeMessage()
        let text = NotificationService.emailWatcherAccumulatedContent(watcher: watcher, newest: newest, account: account, accountCount: 1)
        let n = HeraldBridge.emailWatcherAccumulated(watcher: watcher, newest: newest, account: account, content: text)
        bridge.remember(n)

        // Herald adds the template's `extra` values under "extra" of an object payload.
        func withExtra(_ payload: JSONValue) -> JSONValue {
            guard case .object(var o) = payload else { return payload }
            o["extra"] = .object(["project": .string("x")])
            return .object(o)
        }
        for button in try XCTUnwrap(n.buttons) {
            guard let sent = button.callback?.payload else { continue }
            let event = HeraldCallbackEvent(notificationId: n.id!, app: "webwatcher.email", action: button.label, payload: withExtra(sent))
            XCTAssertTrue(bridge.isExpected(event), button.label)
            XCTAssertEqual(bridge.matchedPayload(event), sent, "the handler gets what WebWatcher sent, not what arrived")
        }

        // Extra does not make a forged payload pass, and it does not hide a changed one.
        let forged = try XCTUnwrap(HeraldBridge.gmailButtons(accountId: accountId, messageIds: ["someone-elses-mail"], emailWatcherId: nil)[2].callback?.payload)
        XCTAssertFalse(bridge.isExpected(HeraldCallbackEvent(notificationId: n.id!, app: "webwatcher.email", action: "Delete", payload: withExtra(forged))))
        // A payload that already used "extra" itself is compared as it is.
        let own: JSONValue = .object(["action": .string("WATCHER_OPEN"), "extra": .string("mine")])
        XCTAssertFalse(bridge.isExpected(HeraldCallbackEvent(notificationId: n.id!, app: "webwatcher.email", action: "Open", payload: own)))
        // A button with no payload that arrives as {"extra": {...}} has no stored payload to match.
        XCTAssertFalse(bridge.isExpected(HeraldCallbackEvent(notificationId: n.id!, app: "webwatcher.email", action: "Open",
                                                             payload: .object(["extra": .object(["project": .string("x")])]))))
    }

    func testReplacingANotificationReplacesItsExpectedPayloads() throws {
        let (bridge, _) = bridge(available: true)
        let first = HeraldBridge.gmailButtons(accountId: accountId, messageIds: ["m1"], emailWatcherId: nil)
        let second = HeraldBridge.gmailButtons(accountId: accountId, messageIds: ["m1", "m2"], emailWatcherId: nil)
        var n = HeraldNotification(app: "webwatcher.email", id: "emailwatcher-1", title: "t")
        n.buttons = first
        bridge.remember(n)
        n.buttons = second
        bridge.remember(n)

        let oldPayload = first[0].callback?.payload
        let newPayload = second[0].callback?.payload
        XCTAssertFalse(bridge.isExpected(HeraldCallbackEvent(notificationId: "emailwatcher-1", app: "webwatcher.email", action: "x", payload: oldPayload)))
        XCTAssertTrue(bridge.isExpected(HeraldCallbackEvent(notificationId: "emailwatcher-1", app: "webwatcher.email", action: "x", payload: newPayload)))
    }

    // MARK: - Callback answers

    private func expectedEvent(_ bridge: HeraldBridge, messageIds: [String] = ["m1"], id: String = "gmail-m1") -> HeraldCallbackEvent {
        var n = HeraldNotification(app: "webwatcher.email", id: id, title: "t")
        n.buttons = HeraldBridge.gmailButtons(accountId: accountId, messageIds: messageIds, emailWatcherId: nil)
        bridge.remember(n)
        return HeraldCallbackEvent(notificationId: id, app: "webwatcher.email", action: "Archive", payload: n.buttons?[1].callback?.payload)
    }

    func testACallbackThatIsNotOneOfOursIsAnsweredForbiddenAndNeverHandled() async {
        let (bridge, _) = bridge(available: true)
        let handled = Counter()
        bridge.installCallbackHandler { _, _ in handled.bump(); return 200 }
        let forged = HeraldCallbackEvent(notificationId: "gmail-m1", app: "webwatcher.email", action: "Delete",
                                         payload: HeraldBridge.gmailButtons(accountId: accountId, messageIds: ["x"], emailWatcherId: nil)[2].callback?.payload)
        let status = await bridge.handleCallback(forged)
        XCTAssertEqual(status, 403)
        let wrongApp = expectedEvent(bridge)
        let other = HeraldCallbackEvent(notificationId: wrongApp.notificationId, app: "someone-else", action: "x", payload: wrongApp.payload)
        let status2 = await bridge.handleCallback(other)
        XCTAssertEqual(status2, 403)
        XCTAssertEqual(handled.value, 0)
    }

    /// Herald dismisses the banner on a 2xx, so the answer has to be the outcome of the action.
    func testTheCallbackIsAnsweredWithTheOutcomeOfTheAction() async {
        let (bridge, _) = bridge(available: true)
        let event = expectedEvent(bridge)
        for status in [200, 409, 504] {
            bridge.installCallbackHandler { _, action in
                if case .gmail(let name, _, let ids, _) = action { XCTAssertEqual(name, HeraldBridge.archiveAction); XCTAssertEqual(ids, ["m1"]) }
                else { XCTFail("gmail action expected") }
                return status
            }
            let got = await bridge.handleCallback(event)
            XCTAssertEqual(got, status)
        }
    }

    func testTheCallbackWaitsForTheHandlerBeforeAnswering() async {
        let (bridge, _) = bridge(available: true)
        let event = expectedEvent(bridge)
        bridge.installCallbackHandler { _, _ in
            try? await Task.sleep(nanoseconds: 300_000_000)
            return 409
        }
        let started = Date()
        let got = await bridge.handleCallback(event)
        XCTAssertEqual(got, 409)
        XCTAssertGreaterThanOrEqual(Date().timeIntervalSince(started), 0.25)
    }

    func testBoundedWaitReturnsTheResultOrGivesUp() async {
        let quick = await HeraldBridge.boundedWait(seconds: 2) { true }
        XCTAssertEqual(quick, true)
        let finished = Counter()
        let started = Date()
        let slow: Bool? = await HeraldBridge.boundedWait(seconds: 0.15) {
            try? await Task.sleep(nanoseconds: 600_000_000)
            finished.bump()
            return true
        }
        XCTAssertNil(slow)
        XCTAssertLessThan(Date().timeIntervalSince(started), 0.5, "stops waiting at the budget")
        try? await Task.sleep(nanoseconds: 900_000_000)
        XCTAssertEqual(finished.value, 1, "the work itself is not cancelled")
    }

    // MARK: - Callback table after a relaunch

    private func gmailNotification(id: String, messageIds: [String]) -> HeraldNotification {
        var n = HeraldNotification(app: "webwatcher.email", id: id, title: "t")
        n.buttons = HeraldBridge.gmailButtons(accountId: accountId, messageIds: messageIds, emailWatcherId: nil)
        return n
    }

    private func event(for n: HeraldNotification, button: Int = 1) -> HeraldCallbackEvent {
        HeraldCallbackEvent(notificationId: n.id!, app: "webwatcher.email", action: "x", payload: n.buttons?[button].callback?.payload)
    }

    /// A banner that was on screen before WebWatcher relaunched is still recognised afterwards.
    func testRehydratingLearnsThePayloadsOfBannersHeraldStillHolds() async {
        let sender = FakeSender()
        let onScreen = gmailNotification(id: "emailwatcher-1", messageIds: ["m1", "m2"])
        sender.live = [onScreen]
        let (bridge, _) = bridge(available: true, sender: sender)
        XCTAssertFalse(bridge.isExpected(event(for: onScreen)), "a fresh process knows nothing")
        await bridge.rehydrate()
        XCTAssertTrue(bridge.isExpected(event(for: onScreen)))
        let forged = gmailNotification(id: "emailwatcher-1", messageIds: ["someone-elses-mail"])
        XCTAssertFalse(bridge.isExpected(event(for: forged)), "only what Herald holds is trusted")
    }

    func testRehydratingDoesNotDropWhatWasJustSent() async {
        let sender = FakeSender()
        let older = gmailNotification(id: "emailwatcher-1", messageIds: ["m1"])
        let newer = gmailNotification(id: "emailwatcher-1", messageIds: ["m1", "m2"])
        sender.live = [older]
        let (bridge, _) = bridge(available: true, sender: sender)
        bridge.remember(newer)
        await bridge.rehydrate()
        XCTAssertTrue(bridge.isExpected(event(for: newer)))
        XCTAssertTrue(bridge.isExpected(event(for: older)), "the banner Herald still shows may be the older one")
    }

    func testRehydratingRunsOncePerProcessAndRetriesAfterAFailure() async {
        let sender = FakeSender()
        sender.liveFailure = HeraldError.notRunning
        let (bridge, _) = bridge(available: true, sender: sender)
        let apps = HeraldBridge.allAppIds.count
        await bridge.rehydrate()
        XCTAssertEqual(sender.liveCalls, 1, "the first failure stops the pass")
        sender.liveFailure = nil
        await bridge.rehydrate()
        XCTAssertEqual(sender.liveCalls, 1 + apps, "a failed attempt is retried, asking for each of our apps")
        await bridge.rehydrate()
        XCTAssertEqual(sender.liveCalls, 1 + apps, "a successful one is not repeated")
    }

    func testTheFirstDeliveryRehydratesBeforeSending() async {
        let sender = FakeSender()
        let onScreen = gmailNotification(id: "gmail-old", messageIds: ["old"])
        sender.live = [onScreen]
        let (bridge, _) = bridge(available: true, sender: sender)
        await bridge.route(gmailNotification(id: "gmail-new", messageIds: ["new"])) { XCTFail("delivered to Herald, no fallback") }
        XCTAssertEqual(sender.sent.map(\.id), ["gmail-new"])
        XCTAssertTrue(bridge.isExpected(event(for: onScreen)))
        XCTAssertEqual(sender.liveCalls, HeraldBridge.allAppIds.count, "once per app, before the first send")
    }

    func testDismissingABannerForgetsItsPayloads() {
        let (bridge, _) = bridge(available: true)
        let n = gmailNotification(id: "emailwatcher-1", messageIds: ["m1"])
        bridge.remember(n)
        XCTAssertTrue(bridge.isExpected(event(for: n)))
        bridge.dismiss(id: "emailwatcher-1")
        XCTAssertFalse(bridge.isExpected(event(for: n)))
    }

    /// Only ids beyond the capacity are dropped, oldest first, so a banner that is still on screen is not
    /// evicted by routine traffic.
    func testTheTableKeepsFarMoreThanTheBannersThatCanBeOnScreen() {
        let (bridge, _) = bridge(available: true)
        XCTAssertGreaterThanOrEqual(HeraldBridge.expectedCapacity, 1024)
        let first = gmailNotification(id: "n0", messageIds: ["m0"])
        bridge.remember(first)
        for i in 1..<HeraldBridge.expectedCapacity { bridge.remember(gmailNotification(id: "n\(i)", messageIds: ["m\(i)"])) }
        XCTAssertTrue(bridge.isExpected(event(for: first)), "at capacity nothing is dropped yet")
        bridge.remember(gmailNotification(id: "overflow", messageIds: ["z"]))
        XCTAssertFalse(bridge.isExpected(event(for: first)), "the oldest goes first")
        XCTAssertTrue(bridge.isExpected(event(for: gmailNotification(id: "overflow", messageIds: ["z"]))))
    }

    // MARK: - Manifests (Herald DESIGN 7.8)

    func testBothManifestsAreValidAndRoundTripThroughTheWireForm() throws {
        for issuer in HeraldIssuer.allCases {
            let manifest = HeraldManifests.manifest(for: issuer, icon: "/tmp/icon.png")
            XCTAssertEqual(manifest.validationErrors(), [], issuer.appId)
            XCTAssertEqual(manifest.app, issuer.appId)
            XCTAssertEqual(manifest.appName, issuer.appName)
            XCTAssertEqual(manifest.icon, "/tmp/icon.png", "the exported app icon")
            XCTAssertEqual(manifest.version, 1)
            XCTAssertEqual(manifest.defaultTemplate, issuer.defaultTemplateName)
            let data = try HeraldJSON.encoder().encode(manifest)
            XCTAssertEqual(try HeraldJSON.decoder().decode(HeraldManifest.self, from: data), manifest, "what Herald stores is what we sent")
        }
        XCTAssertEqual(HeraldIssuer.allCases.map(\.appId), ["webwatcher.web", "webwatcher.email"])
    }

    func testTheWebManifestDeclaresItsFieldsWithSamples() throws {
        let manifest = HeraldManifests.manifest(for: .web, icon: "/tmp/icon.png")
        let keys = manifest.fields.map(\.key)
        for key in ["title", "value", "previous", "url", "image", "watcherName", "site"] {
            XCTAssertTrue(keys.contains(key), "web manifest declares \(key)")
        }
        XCTAssertEqual(manifest.field("title")?.required, true)
        XCTAssertEqual(manifest.field("image")?.type, .image)
        XCTAssertEqual(manifest.field("image")?.sample, .text("/tmp/icon.png"), "the designer previews with the app icon")
        XCTAssertEqual(manifest.field("url")?.type, .url)
        XCTAssertEqual(manifest.field("count")?.type, .number)
        XCTAssertTrue(manifest.fields.allSatisfy { $0.sample != nil }, "every field has a sample for the designer")
        XCTAssertEqual(manifest.actions.map(\.label), ["Open"])
        XCTAssertEqual(manifest.actionIDs, ["open"])
        XCTAssertEqual(manifest.defaultTemplate, "web-default")
    }

    func testTheEmailManifestDeclaresItsFieldsAndTheFourGmailActions() throws {
        let manifest = HeraldManifests.manifest(for: .email, icon: nil)
        XCTAssertEqual(manifest.fields.map(\.key),
                       ["title", "subject", "sender", "address", "count", "receivedAt", "image", "url", "snippet"])
        XCTAssertEqual(manifest.field("count")?.type, .number)
        XCTAssertEqual(manifest.field("receivedAt")?.type, .date)
        XCTAssertEqual(manifest.field("image")?.type, .image)
        XCTAssertNil(manifest.field("image")?.sample, "no icon exported, so no invented sample")
        XCTAssertEqual(manifest.actions.map(\.label), ["Mark as Read", "Archive", "Delete", "Spam"])
        XCTAssertEqual(manifest.actionIDs, ["markRead", "archive", "delete", "spam"])
        XCTAssertEqual(manifest.actions.map(\.style), ["default", "destructive", "destructive", "destructive"])
        XCTAssertTrue(manifest.actions.allSatisfy { $0.callback != nil }, "declared as callback entries")
        XCTAssertEqual(manifest.defaultTemplate, "email-default")
    }

    /// Herald matches a notification's buttons to the manifest's action ids by label, which is what lets a
    /// template rule say `match: "archive"` and have it find WebWatcher's Archive button.
    func testTheGmailButtonsTakeTheManifestActionIDs() {
        let manifest = HeraldManifests.manifest(for: .email, icon: nil)
        let buttons = HeraldBridge.gmailButtons(accountId: accountId, messageIds: ["m1"], emailWatcherId: nil)
        XCTAssertEqual(ActionResolver.issuerIDs(for: buttons, manifest: manifest), ["markRead", "archive", "delete", "spam"])
        let resolved = ActionResolver.resolve(issuer: buttons, ids: ActionResolver.issuerIDs(for: buttons, manifest: manifest),
                                              rules: [HeraldActionRule(match: "markRead", hide: true)])
        XCTAssertEqual(resolved.map(\.id), ["archive", "delete", "spam"])

        let web = HeraldManifests.manifest(for: .web, icon: nil)
        let open = HeraldBridge.openButtons(for: makeWatcher(), url: "https://example.com")
        XCTAssertEqual(ActionResolver.issuerIDs(for: open, manifest: web), ["open"])
    }

    func testFieldKeysFollowTheManifests() {
        XCTAssertEqual(HeraldIssuer.web.fieldKeys, HeraldManifests.manifest(for: .web, icon: nil).fields.map(\.key))
        XCTAssertEqual(HeraldIssuer.issuer(forApp: "webwatcher.email"), .email)
        XCTAssertNil(HeraldIssuer.issuer(forApp: "webwatcher"), "the legacy id is not an issuer")
    }

    // MARK: - Fields

    func testWebFieldsRideInMetadataAndAWatcherWithANumberHasACount() throws {
        let watcher = makeWatcher()
        let text = NotificationService.watcherContent(watcher: watcher, newValue: "3", oldValue: "1")
        let n = HeraldBridge.webWatcher(watcher: watcher, content: text, newValue: "3", oldValue: "1", id: "watcher-x")
        XCTAssertEqual(string(metadata(n)["value"]), "3")
        XCTAssertEqual(string(metadata(n)["previous"]), "1")
        XCTAssertEqual(string(metadata(n)["watcherName"]), "Inbox")
        XCTAssertEqual(string(metadata(n)["site"]), "example.com")
        XCTAssertEqual(metadata(n)["count"], .number(3), "a number, so a count badge can bind to it")

        var textWatcher = makeWatcher()
        textWatcher.watchType = .textChange
        let t = HeraldBridge.webWatcher(watcher: textWatcher, content: text, newValue: "Shipped", oldValue: "Packed", id: "watcher-y")
        XCTAssertNil(metadata(t)["count"], "nothing to count for a text change")
        XCTAssertEqual(string(metadata(t)["value"]), "Shipped")
    }

    func testSiteNameDropsSchemeAndWWW() {
        XCTAssertEqual(HeraldBridge.siteName(for: "https://www.example.com/a/b?c=1"), "example.com")
        XCTAssertEqual(HeraldBridge.siteName(for: "http://shop.example.org"), "shop.example.org")
        XCTAssertNil(HeraldBridge.siteName(for: "not a url"))
    }

    func testBrokenWatchersAreWebNotificationsToo() {
        let watcher = makeWatcher()
        let text = NotificationService.brokenContent(watcher: watcher, reason: .signedOut)
        let n = HeraldBridge.watcherBroken(watcher: watcher, content: text, reason: .signedOut)
        XCTAssertEqual(n.app, "webwatcher.web")
        XCTAssertEqual(string(metadata(n)["watcherName"]), "Inbox")
        XCTAssertEqual(string(metadata(n)["site"]), "example.com")
    }

    func testEmailNotificationsAreSentAsTheEmailIssuerWithTheirFields() throws {
        let account = makeAccount()
        let message = makeMessage()
        let watcher = makeEmailWatcher()
        let content = NotificationService.gmailContent(message: message, account: account)
        let each = HeraldBridge.gmailMessage(message: message, account: account, content: content)
        let matched = HeraldBridge.emailWatcherMessage(
            watcher: watcher, message: message, account: account,
            content: NotificationService.emailWatcherContent(watcher: watcher, message: message, account: account))
        let accumulated = HeraldBridge.emailWatcherAccumulated(
            watcher: watcher, newest: message, account: account,
            content: NotificationService.emailWatcherAccumulatedContent(watcher: watcher, newest: message, account: account, accountCount: 1))
        for n in [each, matched, accumulated] {
            XCTAssertEqual(n.app, "webwatcher.email")
            XCTAssertEqual(string(metadata(n)["sender"]), "Jane Doe")
            XCTAssertEqual(string(metadata(n)["address"]), "jane@acme.com")
            XCTAssertEqual(string(metadata(n)["subject"]), "Invoice #42")
            XCTAssertEqual(string(metadata(n)["snippet"]), "Hello")
            XCTAssertEqual(string(metadata(n)["receivedAt"]), "2023-11-14T22:13:20Z", "ISO 8601, UTC")
        }
    }

    func testTheCountIsANumberOnlyWhenABannerStandsForSeveralMessages() {
        let watcher = makeEmailWatcher()   // 3 unread
        let account = makeAccount()
        let newest = makeMessage(id: "m3")
        let content = NotificationService.emailWatcherAccumulatedContent(watcher: watcher, newest: newest, account: account, accountCount: 1)
        let several = HeraldBridge.emailWatcherAccumulated(watcher: watcher, newest: newest, account: account, content: content)
        XCTAssertEqual(metadata(several)["count"], .number(3))

        var single = watcher
        single.unreadMessageIds = ["m3"]
        single.unreadCount = 1
        let one = HeraldBridge.emailWatcherAccumulated(watcher: single, newest: newest, account: account, content: content)
        XCTAssertNil(metadata(one)["count"], "no count badge for one message")
        let perMessage = HeraldBridge.gmailMessage(message: newest, account: account,
                                                   content: NotificationService.gmailContent(message: newest, account: account))
        XCTAssertNil(metadata(perMessage)["count"])
    }

    func testAnEmptySnippetIsNotSent() {
        let account = makeAccount()
        let message = GmailMessage(accountId: accountId, messageId: "p", threadId: "p", from: "A <a@x.com>", subject: "S",
                                   date: Date(), labelIds: [], snippet: "  ")
        let n = HeraldBridge.gmailMessage(message: message, account: account,
                                          content: NotificationService.gmailContent(message: message, account: account))
        XCTAssertNil(metadata(n)["snippet"])
    }

    // MARK: - Fields at the top level of the notify payload

    func testTopLevelFieldsAreTheDeclaredOnesThatAreNotNotificationProperties() {
        let account = makeAccount()
        let watcher = makeEmailWatcher()
        let newest = makeMessage(id: "m3")
        let content = NotificationService.emailWatcherAccumulatedContent(watcher: watcher, newest: newest, account: account, accountCount: 1)
        let n = HeraldBridge.emailWatcherAccumulated(watcher: watcher, newest: newest, account: account, content: content)
        let top = HeraldBridge.topLevelFields(of: n)
        XCTAssertEqual(Set(top.keys), ["subject", "sender", "address", "count", "receivedAt", "snippet"])
        XCTAssertEqual(top["count"], .number(3))
        XCTAssertNil(top["title"], "title, image and url are notification properties already")
        XCTAssertNil(top["emailWatcherId"], "bookkeeping stays in metadata")
        XCTAssertNil(top["type"])

        XCTAssertTrue(HeraldBridge.topLevelFields(of: HeraldNotification(app: "webwatcher", title: "t")).isEmpty, "the retired id is not an issuer: nothing to lift")
        XCTAssertTrue(HeraldBridge.topLevelFields(of: HeraldNotification(app: "bidbot", title: "t")).isEmpty)
    }

    func testTheWireBodyCarriesFieldsAtTheTopLevelAndKeepsMetadata() throws {
        let watcher = makeWatcher()
        let text = NotificationService.watcherContent(watcher: watcher, newValue: "3", oldValue: "1")
        let n = HeraldBridge.webWatcher(watcher: watcher, content: text, newValue: "3", oldValue: "1", id: "watcher-x")
        let body = try HeraldBridge.wireBody(for: n)
        let object = try XCTUnwrap(try JSONSerialization.jsonObject(with: body) as? [String: Any])

        XCTAssertEqual(object["app"] as? String, "webwatcher.web")
        XCTAssertEqual(object["id"] as? String, "watcher-x")
        XCTAssertEqual(object["title"] as? String, "Inbox")
        XCTAssertEqual(object["value"] as? String, "3")
        XCTAssertEqual(object["previous"] as? String, "1")
        XCTAssertEqual(object["watcherName"] as? String, "Inbox")
        XCTAssertEqual(object["site"] as? String, "example.com")
        XCTAssertEqual(object["count"] as? Int, 3, "a JSON number")
        XCTAssertNil(object["template"], "the user's chosen look is the manifest default, never forced by the payload")
        let meta = try XCTUnwrap(object["metadata"] as? [String: Any])
        XCTAssertEqual(meta["value"] as? String, "3", "still in metadata for a Herald that reads only that")
        XCTAssertEqual(meta["type"] as? String, "watcher")

        // The body is still a HeraldNotification (unknown keys are ignored on decode).
        let decoded = try HeraldJSON.decoder().decode(HeraldNotification.self, from: body)
        XCTAssertEqual(decoded, n)
    }

    func testTheWireBodyOfANonIssuerAppIsExactlyTheEncodedNotification() throws {
        var n = HeraldNotification(app: "bidbot", id: "x", title: "Hi")
        n.metadata = .object(["value": .string("3")])
        let wire = try XCTUnwrap(try JSONSerialization.jsonObject(with: HeraldBridge.wireBody(for: n)) as? NSDictionary)
        let plain = try XCTUnwrap(try JSONSerialization.jsonObject(with: HeraldJSON.encoder().encode(n)) as? NSDictionary)
        XCTAssertEqual(wire, plain)
        XCTAssertNil(wire["value"], "only the declared fields of an issuer are lifted")
    }

    /// What Herald does with the payload, reproduced: resolve the fields of the delivered notification
    /// against the manifest and bind the default template's tokens.
    func testTheFieldsResolveAgainstTheManifestAndBindTheTemplateTokens() throws {
        let account = makeAccount()
        let watcher = makeEmailWatcher()
        let newest = makeMessage(id: "m3")
        let content = NotificationService.emailWatcherAccumulatedContent(watcher: watcher, newest: newest, account: account, accountCount: 1)
        let n = HeraldBridge.emailWatcherAccumulated(watcher: watcher, newest: newest, account: account, content: content)
        let manifest = HeraldManifests.manifest(for: .email, icon: nil)
        let fields = TemplateResolver.fields(for: n, manifest: manifest)

        XCTAssertEqual(TemplateResolver.bind("{sender}", fields: fields), "Jane Doe")
        XCTAssertEqual(TemplateResolver.bind("{subject}", fields: fields), "Invoice #42")
        XCTAssertEqual(TemplateResolver.bind("{snippet}", fields: fields), "Hello")
        XCTAssertEqual(TemplateResolver.bind("{count}", fields: fields), "3")
        XCTAssertEqual(fields["count"], .number(3))
        XCTAssertEqual(TemplateResolver.bind("{image}", fields: fields), "/tmp/acme.png")
        XCTAssertNotNil(TemplateResolver.bind("{receivedAt}", fields: fields))
        XCTAssertNil(TemplateResolver.bind("{nothing}", fields: fields), "an absent token is empty, so its component collapses")
    }

    // MARK: - Default templates

    func testTheDefaultTemplatesAreValidGridTemplatesForTheirIssuers() throws {
        for issuer in HeraldIssuer.allCases {
            let template = HeraldManifests.defaultTemplate(for: issuer)
            let manifest = HeraldManifests.manifest(for: issuer, icon: nil)
            XCTAssertEqual(template.name, issuer.defaultTemplateName)
            XCTAssertEqual(template.name, manifest.defaultTemplate)
            XCTAssertEqual(template.app, issuer.appId)
            XCTAssertEqual(template.layoutVersion, 2)
            XCTAssertTrue(template.usesGrid)
            XCTAssertTrue(template.collapseEmpty)
            XCTAssertEqual(template.validate(manifest: manifest), [], "no errors and no warnings for \(issuer.appId)")
            let data = try HeraldJSON.encoder().encode(template)
            XCTAssertEqual(try HeraldJSON.decoder().decode(HeraldTemplate.self, from: data), template)
        }
    }

    func testTheWebTemplateIsImageLeftWithACountBadge() {
        let template = HeraldManifests.defaultTemplate(for: .web)
        XCTAssertEqual(template.cell(withID: "image")?.col, 0)
        XCTAssertEqual(template.cell(withID: "image")?.rowSpan, 3)
        XCTAssertEqual(template.grid?.colSizes.first, .points(72), "the image column is on the left")
        guard case .badge(let badge)? = template.cell(withID: "count")?.component else { return XCTFail("a count badge") }
        XCTAssertEqual(badge.binding, "{count}")
        guard case .text(let title)? = template.cell(withID: "title")?.component else { return XCTFail("a title") }
        XCTAssertEqual(title.binding, "{title}")
    }

    func testTheEmailTemplateShowsSenderSubjectSnippetTimeAndActions() throws {
        let template = HeraldManifests.defaultTemplate(for: .email)
        func binding(_ id: String) -> String? {
            switch template.cell(withID: id)?.component {
            case .text(let t)?: return t.binding
            case .timestamp(let t)?: return t.binding
            default: return nil
            }
        }
        // {title} and {body} carry what the builders wrote: the user's own text, "[Preview] ", the subject bullets.
        XCTAssertEqual(binding("title"), "{title}")
        XCTAssertEqual(binding("subtitle"), "{subject}")
        XCTAssertEqual(binding("body"), "{body}")
        XCTAssertEqual(binding("time"), "{receivedAt}")
        guard case .actions(let actions)? = template.cell(withID: "actions")?.component else { return XCTFail("an actions row") }
        XCTAssertEqual(actions.source, .merged)
        XCTAssertEqual(template.cell(withID: "actions")?.col, 1, "not under the image column, which must be free to collapse")
        XCTAssertEqual(template.cell(withID: "actions")?.colSpan, 3)
        XCTAssertTrue(template.actionRules.isEmpty, "the issuer's four actions pass through untouched")
    }

    func testTheEmailBannerShowsTheUsersOwnTextAndThePreviewMarker() throws {
        var watcher = makeEmailWatcher()
        watcher.notificationTitle = "{count} new from {sender}"
        watcher.notificationBodyTemplate = "{subject} / {name}"
        let account = makeAccount()
        let newest = makeMessage()
        var content = NotificationService.emailWatcherAccumulatedContent(watcher: watcher, newest: newest, account: account, accountCount: 1)
        content.title = "[Preview] " + content.title      // what sendEmailPreview does
        let n = HeraldBridge.emailWatcherAccumulated(watcher: watcher, newest: newest, account: account, content: content,
                                                      idOverride: "preview-1", isPreview: true)
        let manifest = HeraldManifests.manifest(for: .email, icon: nil)
        let template = HeraldManifests.defaultTemplate(for: .email)
        let fields = TemplateResolver.fields(for: n, manifest: manifest)
        func shown(_ id: String) -> String? {
            guard case .text(let t)? = template.cell(withID: id)?.component else { return nil }
            return TemplateResolver.bind(t.binding, fields: fields)
        }
        XCTAssertEqual(shown("title"), "[Preview] 3 new from Jane Doe")
        XCTAssertEqual(shown("body"), "Invoice #42 / Acme")
        XCTAssertEqual(shown("subtitle"), "Invoice #42")
    }

    func testTheDefaultAccumulatedBodyIsNotEmptyAndKeepsTheSnippet() throws {
        let watcher = makeEmailWatcher()
        let account = makeAccount()
        let manifest = HeraldManifests.manifest(for: .email, icon: nil)
        let template = HeraldManifests.defaultTemplate(for: .email)

        // The editor's preview mail has no snippet: the bullet list still fills the body, so it does not collapse.
        let bare = GmailMessage(accountId: accountId, messageId: "m1", threadId: "t1", from: "Jane Doe <jane@acme.com>",
                                subject: "Invoice #42", date: Date(timeIntervalSince1970: 1_700_000_000), labelIds: ["INBOX"], snippet: "")
        let c0 = NotificationService.emailWatcherAccumulatedContent(watcher: watcher, newest: bare, account: account, accountCount: 1)
        let n0 = HeraldBridge.emailWatcherAccumulated(watcher: watcher, newest: bare, account: account, content: c0)
        let plan = template.plan(fields: TemplateResolver.fields(for: n0, manifest: manifest), actions: [])
        XCTAssertFalse(plan.isCollapsed(cell: "body"))

        // With a snippet, it is one of the body's lines.
        let c1 = NotificationService.emailWatcherAccumulatedContent(watcher: watcher, newest: makeMessage(), account: account, accountCount: 1)
        XCTAssertTrue(c1.body.contains("\nHello\n"), c1.body)
        XCTAssertTrue(c1.body.hasPrefix("• "), "the bullet list is still the default")
    }

    func testAnUntouchedEarlierDefaultIsReplacedButAnEditedTemplateIsKept() throws {
        let wanted = HeraldManifests.defaultTemplate(for: .email)
        let legacy = HeraldManifests.defaultTemplate(for: .email, legacy: true)
        XCTAssertNotEqual(wanted, legacy)
        XCTAssertTrue(HeraldManifests.shouldStore(wanted, over: nil), "nothing stored yet")
        XCTAssertTrue(HeraldManifests.shouldStore(wanted, over: legacy), "an install that still has the 1.10 default gets the new one")
        XCTAssertFalse(HeraldManifests.shouldStore(wanted, over: wanted))
        var edited = legacy
        edited.accentColor = "#FF0000"
        XCTAssertFalse(HeraldManifests.shouldStore(wanted, over: edited), "the user changed it in Herald: leave it")
        let web = HeraldManifests.defaultTemplate(for: .web)
        var asWeb = legacy
        asWeb.name = web.name; asWeb.app = web.app
        XCTAssertFalse(HeraldManifests.shouldStore(web, over: asWeb), "only the email default has an earlier version")
        // The earlier version survives the trip through Herald's JSON, so the comparison against what Herald stored holds.
        let data = try HeraldJSON.encoder().encode(legacy)
        XCTAssertEqual(try HeraldJSON.decoder().decode(HeraldTemplate.self, from: data), legacy)
    }

    /// With real notifications: the plan collapses what has nothing to show and keeps the four buttons.
    func testEmptyPartsOfTheDefaultTemplatesCollapse() {
        let account = makeAccount()
        let message = makeMessage()
        let n = HeraldBridge.gmailMessage(message: message, account: account,
                                          content: NotificationService.gmailContent(message: message, account: account))
        let manifest = HeraldManifests.manifest(for: .email, icon: nil)
        let template = HeraldManifests.defaultTemplate(for: .email)
        let fields = TemplateResolver.fields(for: n, manifest: manifest)
        let actions = ActionResolver.resolveDetailed(
            issuer: n.buttons ?? [], ids: ActionResolver.issuerIDs(for: n.buttons ?? [], manifest: manifest), rules: template.actionRules)
        XCTAssertEqual(actions.map(\.id), ["markRead", "archive", "delete", "spam"])
        XCTAssertEqual(actions.map(\.origin), Array(repeating: .issuer, count: 4))

        let plan = template.plan(fields: fields, actions: actions)
        XCTAssertTrue(plan.isCollapsed(cell: "image"), "no picture on a per-message email")
        XCTAssertTrue(plan.isCollapsed(cell: "count"), "one message, no badge")
        XCTAssertFalse(plan.isCollapsed(cell: "title"))
        XCTAssertFalse(plan.isCollapsed(cell: "subtitle"))
        XCTAssertFalse(plan.isCollapsed(cell: "body"))
        XCTAssertFalse(plan.isCollapsed(cell: "actions"))
        XCTAssertTrue(plan.collapsedCols.contains(0), "the image column goes with its image")

        // An accumulated banner with an icon keeps both.
        let watcher = makeEmailWatcher()
        let accumulated = HeraldBridge.emailWatcherAccumulated(
            watcher: watcher, newest: message, account: account,
            content: NotificationService.emailWatcherAccumulatedContent(watcher: watcher, newest: message, account: account, accountCount: 1))
        let more = template.plan(fields: TemplateResolver.fields(for: accumulated, manifest: manifest), actions: actions)
        XCTAssertFalse(more.isCollapsed(cell: "image"))
        XCTAssertFalse(more.isCollapsed(cell: "count"))
    }

    // MARK: - Delivery set-up

    func testDeliveryRegistersTheIssuerThenStoresItsTemplateAndManifestBeforeSending() async {
        let (bridge, sender) = bridge(available: true)
        let n = HeraldNotification(app: "webwatcher.email", id: "gmail-1", title: "Hi")
        await bridge.route(n) { XCTFail("no fallback") }

        XCTAssertEqual(sender.log, [
            "register:webwatcher.email",
            "template:webwatcher.email/email-default",
            "manifest:webwatcher.email",
            "send:gmail-1"
        ])
        XCTAssertEqual(sender.manifests.first, HeraldManifests.manifest(for: .email, icon: nil))
        XCTAssertEqual(sender.templates.first, HeraldManifests.defaultTemplate(for: .email))
    }

    func testTheLegacyAppIdIsNeverRegistered() async {
        let (bridge, sender) = bridge(available: true)
        await bridge.route(HeraldNotification(app: "webwatcher", id: "x", title: "Hi")) { XCTFail("no fallback") }
        XCTAssertEqual(sender.log, ["send:x"], "no registration, manifest or template for the retired id")
        XCTAssertTrue(sender.registrations.isEmpty)
    }

    func testBothIssuersAreRegisteredWithTheSameCallbackIconAndBundle() async throws {
        let (bridge, sender) = bridge(available: true)
        bridge.start { _, _ in 200 }
        defer { bridge.stop() }
        try await bridge.prepare(app: "webwatcher.web")
        try await bridge.prepare(app: "webwatcher.email")
        XCTAssertEqual(Set(sender.registrations.map(\.app)), ["webwatcher.web", "webwatcher.email"])
        XCTAssertFalse(sender.registrations.contains { $0.app == "webwatcher" })
        XCTAssertEqual(Set(sender.registrations.map(\.callbackURL)).count, 1)
        XCTAssertNotNil(sender.registrations[0].callbackURL)
        XCTAssertEqual(Set(sender.registrations.map(\.allowCommands)), [false])
        XCTAssertEqual(Set(sender.registrations.map(\.bundleId)).count, 1)
    }

    func testTheLegacyBannersAreClearedOncePerRunAndNeverRegistered() async {
        let (bridge, sender) = bridge(available: true)
        await bridge.cleanUpLegacyBanners()
        await bridge.cleanUpLegacyBanners()
        XCTAssertEqual(sender.dismissedAll, ["webwatcher"], "once, under the retired id only")
        XCTAssertTrue(sender.registrations.isEmpty)
    }

    func testRegistrationNamesTheIssuerAndHandsOverTheCallbackURL() {
        let (bridge, _) = bridge(available: true)
        let web = bridge.registration(for: "webwatcher.web")
        XCTAssertEqual(web.appName, "WebWatcher · Web")
        XCTAssertEqual(web.allowCommands, false)
        XCTAssertEqual(bridge.registration(for: "webwatcher.email").appName, "WebWatcher · Email")
    }

    /// A Herald that predates manifests answers 404; the banner must still go out as a Herald banner.
    func testAHeraldWithoutManifestsStillShowsTheBanner() async {
        let sender = FakeSender()
        sender.manifestFailure = HeraldError.server(status: 404, message: "not found")
        sender.templateFailure = HeraldError.server(status: 404, message: "not found")
        let (bridge, _) = bridge(available: true, sender: sender)
        let fallback = Counter()
        await bridge.route(HeraldNotification(app: "webwatcher.web", id: "watcher-1", title: "Hi")) { fallback.bump() }
        XCTAssertEqual(sender.sent.map(\.id), ["watcher-1"])
        XCTAssertEqual(fallback.value, 0)
    }

    func testCallbacksFromEveryOneOfOurAppIdsAreRecognisedAndOthersAreNot() async {
        XCTAssertTrue(HeraldBridge.isOurApp("webwatcher.web"))
        XCTAssertTrue(HeraldBridge.isOurApp("webwatcher.email"))
        XCTAssertFalse(HeraldBridge.isOurApp("webwatcher"), "the retired id no longer answers")
        XCTAssertFalse(HeraldBridge.isOurApp("bidbot"))

        let (bridge, _) = bridge(available: true)
        let handled = Counter()
        bridge.installCallbackHandler { _, _ in handled.bump(); return 200 }
        var n = HeraldNotification(app: "webwatcher.email", id: "gmail-m1", title: "t")
        n.buttons = HeraldBridge.gmailButtons(accountId: accountId, messageIds: ["m1"], emailWatcherId: nil)
        bridge.remember(n)
        let event = HeraldCallbackEvent(notificationId: "gmail-m1", app: "webwatcher.email", action: "Archive",
                                        payload: n.buttons?[1].callback?.payload)
        let ok = await bridge.handleCallback(event)
        XCTAssertEqual(ok, 200)
        XCTAssertEqual(handled.value, 1)

        let elsewhere = HeraldCallbackEvent(notificationId: "gmail-m1", app: "bidbot", action: "Archive", payload: event.payload)
        let refused = await bridge.handleCallback(elsewhere)
        XCTAssertEqual(refused, 403)
    }

    func testDismissGoesToTheIssuerThatOwnsTheId() async throws {
        XCTAssertEqual(HeraldBridge.issuers(forNotificationId: "watcher-1"), [.web])
        XCTAssertEqual(HeraldBridge.issuers(forNotificationId: "health-1"), [.web])
        XCTAssertEqual(HeraldBridge.issuers(forNotificationId: "gmail-m1-w"), [.email])
        XCTAssertEqual(HeraldBridge.issuers(forNotificationId: "emailwatcher-1"), [.email])
        XCTAssertEqual(HeraldBridge.issuers(forNotificationId: "preview-1"), HeraldIssuer.allCases, "a preview could be either")

        let (bridge, sender) = bridge(available: true)
        bridge.dismiss(id: "emailwatcher-1")
        bridge.dismiss(id: "watcher-1")
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertEqual(sender.log, ["dismiss:webwatcher.email/emailwatcher-1", "dismiss:webwatcher.web/watcher-1"])
    }

    // MARK: - Settings

    func testDeliveryDefaultsToHeraldWhenAvailable() {
        XCTAssertEqual(NotificationDelivery.default, .heraldWhenAvailable)
        XCTAssertEqual(NotificationDelivery.fromStored(nil), .heraldWhenAvailable)
        XCTAssertEqual(NotificationDelivery.fromStored("garbage"), .heraldWhenAvailable)
        XCTAssertEqual(NotificationDelivery.fromStored("system"), .system)
        XCTAssertEqual(NotificationDelivery.fromStored("heraldWhenAvailable"), .heraldWhenAvailable)
    }

    func testDeliveryRawValuesAreStable() throws {
        // The raw value is what UserDefaults stores; changing it would silently reset users.
        XCTAssertEqual(NotificationDelivery.system.rawValue, "system")
        XCTAssertEqual(NotificationDelivery.heraldWhenAvailable.rawValue, "heraldWhenAvailable")
        let data = try JSONEncoder().encode(NotificationDelivery.system)
        XCTAssertEqual(try JSONDecoder().decode(NotificationDelivery.self, from: data), .system)
    }

    func testStatusLines() {
        XCTAssertEqual(HeraldStatus(isRunning: true, port: 48617).line, "Herald: running (port 48617)")
        XCTAssertEqual(HeraldStatus(isRunning: false, port: 48617).line, "Herald not running — using macOS notifications")
    }

    func testCurrentStatusUsesAvailability() {
        let up = HeraldBridge(availability: FakeAvailability(available: true, port: 51000), sender: FakeSender(), delivery: { .system })
        XCTAssertEqual(up.currentStatus(), HeraldStatus(isRunning: true, port: 51000))
        let down = HeraldBridge(availability: FakeAvailability(available: false), sender: FakeSender(), delivery: { .system })
        XCTAssertFalse(down.currentStatus().isRunning)
    }

    func testStackingGroupKeys() {
        let account = makeAccount()
        let message = GmailMessage(accountId: accountId, messageId: "m1", threadId: "t1",
                                   from: "Jane <Jane.Doe@ACME.com>", subject: "Hi",
                                   date: Date(timeIntervalSince1970: 1_700_000_000), labelIds: ["INBOX"], snippet: "x")
        let text = NotificationService.gmailContent(message: message, account: account)
        XCTAssertEqual(HeraldBridge.gmailMessage(message: message, account: account, content: text).group, "jane.doe@acme.com")

        let watcher = makeEmailWatcher()
        let acc = NotificationService.emailWatcherAccumulatedContent(watcher: watcher, newest: message, account: account, accountCount: 1)
        XCTAssertEqual(HeraldBridge.emailWatcherAccumulated(watcher: watcher, newest: message, account: account, content: acc).group,
                       "jane@acme.com", "accumulated banners stack by the watcher's first sender pattern")
        XCTAssertEqual(HeraldBridge.emailWatcherMessage(watcher: watcher, message: message, account: account, content: acc).group,
                       "jane.doe@acme.com")

        let web = makeWatcher()
        let wt = NotificationService.watcherContent(watcher: web, newValue: "3", oldValue: "0")
        XCTAssertEqual(HeraldBridge.webWatcher(watcher: web, content: wt, newValue: "3", oldValue: "0", id: "watcher-x").group, "example.com")
    }

    func testManifestsDeclareTheWebWatcherFamily() {
        for issuer in [HeraldIssuer.web, .email] {
            XCTAssertEqual(HeraldManifests.manifest(for: issuer, icon: nil).family, "webwatcher")
        }
    }
}
