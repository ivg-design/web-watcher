import Foundation
import UserNotifications
import AppKit

/// Conformance point (§3.10) so `GmailPollingService` can be driven by a fake in tests
/// instead of the real `UNUserNotificationCenter`.
protocol GmailNotifying: AnyObject {
    func notifyGmail(message: GmailMessage, account: GmailAccount)
    func notifyEmailWatcher(_ watcher: EmailWatcher, message: GmailMessage, account: GmailAccount)
    /// Posts (or replaces in place) the single accumulated notification for `watcher`.
    func notifyEmailWatcherAccumulated(_ watcher: EmailWatcher, newest: GmailMessage, account: GmailAccount)
    /// Removes the delivered accumulated notification once the unread count drops to 0.
    func clearEmailWatcherNotification(watcherId: UUID)
}

/// The title/subtitle/body of an email-watcher notification, split out from the actual
/// `UNNotificationContent` construction so `EmailNotificationContentTests` can check the
/// text without touching Notification Center.
struct EmailNotificationContent: Equatable {
    var title: String
    var subtitle: String
    var body: String
}

/// Title/subtitle/body of a web-watcher or health notification, split from the delivery
/// mechanism so the same text feeds both the native notification and the Herald banner.
struct WatcherNotificationContent: Equatable {
    var title: String
    var subtitle: String
    var body: String
}

/// Handles sending notifications: through Herald when the user's setting and Herald's
/// availability allow it (`HeraldBridge`), otherwise as native macOS notifications.
class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()

    /// Resolves a watcher id to the live watcher (set by the app delegate). Used by Herald's
    /// "Open" callback for watchers whose destination needs an API lookup.
    var watcherLookup: (@MainActor (UUID) -> Watcher?)?

    private override init() {
        super.init()
        // Set delegate to handle foreground notifications
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        registerGmailCategory(center: center)
    }

    private func registerGmailCategory(center: UNUserNotificationCenter) {
        let markRead = UNNotificationAction(
            identifier: "GMAIL_MARK_READ",
            title: "Mark as Read",
            options: []
        )
        let archive = UNNotificationAction(
            identifier: "GMAIL_ARCHIVE",
            title: "Archive",
            options: [.destructive]
        )
        let delete = UNNotificationAction(
            identifier: "GMAIL_DELETE",
            title: "Delete",
            options: [.destructive]
        )
        let spam = UNNotificationAction(
            identifier: "GMAIL_SPAM",
            title: "Spam",
            options: [.destructive]
        )

        let gmailCategory = UNNotificationCategory(
            identifier: "GMAIL_MESSAGE",
            actions: [markRead, archive, delete, spam],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([gmailCategory])
    }

    /// Request notification permissions
    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            print("Notification authorization: granted=\(granted) status=\(Self.describe(settings.authorizationStatus)) alert=\(settings.alertSetting.rawValue)")
            return granted
        } catch {
            // A refusal here arrives as a thrown error on macOS when the app is not
            // registered with Notification Center at all — which looks identical to
            // "no new mail" unless we say so.
            print("Notification authorization FAILED: \(error.localizedDescription)")
            return false
        }
    }

    static func describe(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "notDetermined"
        case .denied:        return "denied"
        case .authorized:    return "authorized"
        case .provisional:   return "provisional"
        case .ephemeral:     return "ephemeral"
        @unknown default:    return "unknown"
        }
    }

    /// Check if notifications are authorized
    func checkPermission() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized
    }

    /// Send a notification for a watcher update
    func notify(watcher: Watcher, newValue: String, oldValue: String?) {
        let text = Self.watcherContent(watcher: watcher, newValue: newValue, oldValue: oldValue)
        let herald = HeraldBridge.webWatcher(
            watcher: watcher, content: text, newValue: newValue, oldValue: oldValue,
            id: HeraldBridge.webWatcherNotificationId(watcher.id)
        )
        HeraldBridge.shared.deliver(herald) { [self] in
            postSystemWatcherNotification(watcher: watcher, newValue: newValue, oldValue: oldValue)
        }
    }

    private func postSystemWatcherNotification(watcher: Watcher, newValue: String, oldValue: String?) {
        let identifier = HeraldBridge.webWatcherNotificationId(watcher.id)
        let content = buildNotificationContent(watcher: watcher, newValue: newValue, oldValue: oldValue)
        let center = UNUserNotificationCenter.current()

        // Keep only a single active notification per watcher.
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil // Deliver immediately
        )

        center.add(request) { error in
            if let error = error {
                print("Failed to send notification: \(error)")
            }
        }
    }

    /// Send a preview notification
    func sendPreview(watcher: Watcher, testValue: String = "3") {
        let identifier = "preview-\(UUID().uuidString)"
        let text = Self.watcherContent(watcher: watcher, newValue: testValue, oldValue: "0", isPreview: true)
        let herald = HeraldBridge.webWatcher(
            watcher: watcher, content: text, newValue: testValue, oldValue: "0",
            id: identifier, isPreview: true
        )
        HeraldBridge.shared.deliver(herald) { [self] in
            postSystemPreview(watcher: watcher, testValue: testValue, identifier: identifier)
        }
    }

    private func postSystemPreview(watcher: Watcher, testValue: String, identifier: String) {
        let content = buildNotificationContent(watcher: watcher, newValue: testValue, oldValue: "0", isPreview: true)

        // Always play sound for preview
        content.sound = UNNotificationSound.default

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil  // Deliver immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to send preview notification: \(error)")
            } else {
                print("Preview notification sent successfully")
            }
        }
    }

    /// Title/subtitle/body for a per-message Gmail notification.
    static func gmailContent(message: GmailMessage, account: GmailAccount) -> EmailNotificationContent {
        // Parse sender name from "Name <email>" format
        let senderName: String
        if let angleBracket = message.from.firstIndex(of: "<") {
            senderName = String(message.from[..<angleBracket]).trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        } else {
            senderName = message.from
        }

        var body = message.snippet
        if !message.labelIds.isEmpty {
            body += " [\(message.labelIds.joined(separator: ", "))]"
        }
        body += " — \(account.email)"
        return EmailNotificationContent(title: senderName, subtitle: message.subject, body: body)
    }

    /// Send a notification for a new Gmail message
    func notifyGmail(message: GmailMessage, account: GmailAccount) {
        let text = Self.gmailContent(message: message, account: account)
        let herald = HeraldBridge.gmailMessage(message: message, account: account, content: text)
        HeraldBridge.shared.deliver(herald) { [self] in
            postSystemGmail(message: message, account: account, text: text)
        }
    }

    private func postSystemGmail(message: GmailMessage, account: GmailAccount, text: EmailNotificationContent) {
        let content = UNMutableNotificationContent()
        content.title = text.title
        content.subtitle = text.subtitle
        content.body = text.body

        if account.notificationSound {
            content.sound = .default
        }

        content.categoryIdentifier = "GMAIL_MESSAGE"
        content.userInfo = [
            "type": "gmail",
            "accountId": account.id.uuidString,
            "messageId": message.messageId,
            "threadId": message.threadId,
            "accountIndex": account.accountIndex
        ]

        let identifier = "gmail-\(message.messageId)"

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to send Gmail notification: \(error)")
            }
        }
    }

    /// Tell the user a watcher has stopped working, and what to do about it.
    ///
    /// This exists because the previous design could accumulate thousands of consecutive
    /// failures without ever surfacing one.
    func notifyWatcherBroken(watcher: Watcher, reason: CannotReason) {
        let text = Self.brokenContent(watcher: watcher, reason: reason)
        let herald = HeraldBridge.watcherBroken(watcher: watcher, content: text, reason: reason)
        HeraldBridge.shared.deliver(herald) { [self] in
            postSystemBroken(watcher: watcher, text: text)
        }
    }

    static func brokenContent(watcher: Watcher, reason: CannotReason) -> WatcherNotificationContent {
        WatcherNotificationContent(
            title: "\(watcher.name) isn't working",
            subtitle: reason.shortStatus,
            body: reason.remedy ?? "WebWatcher can't read this page right now."
        )
    }

    private func postSystemBroken(watcher: Watcher, text: WatcherNotificationContent) {
        let content = UNMutableNotificationContent()
        content.title = text.title
        content.subtitle = text.subtitle
        content.body = text.body
        content.sound = nil
        content.userInfo = [
            "type": "health",
            "watcherId": watcher.id.uuidString,
            "watcherURL": watcher.url
        ]

        let request = UNNotificationRequest(
            identifier: HeraldBridge.healthNotificationId(watcher.id),
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to send health notification: \(error)")
            }
        }
    }

    /// The text of a web-watcher notification (title, subtitle, body) with every placeholder
    /// expanded. Pure, so it feeds both the native notification and the Herald banner.
    static func watcherContent(watcher: Watcher, newValue: String, oldValue: String?, isPreview: Bool = false) -> WatcherNotificationContent {
        var title: String
        var subtitle = ""
        var body: String

        // Placeholders are expanded in every user-authored string, not just the body —
        // the title previously rendered a literal "{value}".
        func expand(_ template: String) -> String {
            template
                .replacingOccurrences(of: "{value}", with: newValue)
                .replacingOccurrences(of: "{name}", with: watcher.name)
                .replacingOccurrences(of: "{previous}", with: oldValue ?? "0")
        }

        // Title: use custom or default to watcher name
        title = expand(watcher.notificationTitle ?? watcher.name)
        if isPreview {
            title = "[Preview] " + title
        }

        // Body: use custom template or generate based on watch type
        if let template = watcher.notificationBodyTemplate, !template.isEmpty {
            body = expand(template)
        } else {
            // Default body based on watch type
            switch watcher.watchType {
            case .badgeNumber:
                if let count = Int(newValue), count > 0 {
                    body = "You have \(count) new message\(count == 1 ? "" : "s")"
                } else {
                    body = "New activity detected"
                }

            case .elementCount:
                let oldCount = oldValue.flatMap { Int($0) } ?? 0
                let newCount = Int(newValue) ?? 0
                let diff = newCount - oldCount
                if diff > 0 {
                    body = "\(diff) new item\(diff == 1 ? "" : "s") (\(newCount) total)"
                } else {
                    body = "Count changed to \(newCount)"
                }

            case .textChange:
                body = "Content updated"
                subtitle = String(newValue.prefix(100))

            case .elementExists:
                body = newValue == "true" ? "Element appeared" : "Element not found"

            case .elementDisappears:
                body = newValue == "false" ? "Element disappeared" : "Element still present"

            case .subtreeChange:
                body = "Something changed inside the watched area"
            }
        }

        return WatcherNotificationContent(title: title, subtitle: subtitle, body: body)
    }

    /// Build notification content with all customizations
    private func buildNotificationContent(watcher: Watcher, newValue: String, oldValue: String?, isPreview: Bool = false) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        let text = Self.watcherContent(watcher: watcher, newValue: newValue, oldValue: oldValue, isPreview: isPreview)
        content.title = text.title
        content.subtitle = text.subtitle
        content.body = text.body

        // Add custom icon as attachment if provided
        if let iconPath = watcher.customIconPath,
           !iconPath.isEmpty,
           let attachment = createAttachment(from: iconPath, id: "icon") {
            content.attachments = [attachment]
        }

        // Add sound if enabled
        if watcher.notificationSound {
            content.sound = .default
        }

        // Store destination information in userInfo for click handling.
        var userInfo: [String: Any] = [
            "watcherId": watcher.id.uuidString,
            "watcherURL": watcher.url
        ]
        if let actionURL = watcher.actionURL ?? URL(string: watcher.url)?.absoluteString {
            userInfo["actionURL"] = actionURL
        }
        if let apiLookupCommand = watcher.apiLookupCommand, !apiLookupCommand.isEmpty {
            userInfo["apiLookupCommand"] = apiLookupCommand
        }
        content.userInfo = userInfo

        return content
    }

    /// Create a notification attachment from an image path.
    ///
    /// macOS shows attachments as a fixed-size square thumbnail; a non-square image was
    /// letterboxed inside it and looked tiny. The attachment is now a centred square crop
    /// rendered at 512 px (see NotificationIconStore), which fills the whole slot.
    private func createAttachment(from imagePath: String, id: String) -> UNNotificationAttachment? {
        guard FileManager.default.fileExists(atPath: imagePath) else {
            print("Icon file not found: \(imagePath)")
            return nil
        }
        let sourceURL: URL
        if let square = NotificationIconStore.squareThumbnail(from: imagePath) {
            sourceURL = square
        } else {
            // Unreadable as a bitmap (e.g. an .icns the crop cannot decode): plain copy.
            let fileURL = URL(fileURLWithPath: imagePath)
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(id)-\(UUID().uuidString).\(fileURL.pathExtension)")
            do { try FileManager.default.copyItem(at: fileURL, to: tempURL) } catch { return nil }
            sourceURL = tempURL
        }
        do {
            return try UNNotificationAttachment(identifier: id, url: sourceURL, options: [
                UNNotificationAttachmentOptionsThumbnailClippingRectKey: CGRect(x: 0, y: 0, width: 1, height: 1).dictionaryRepresentation
            ])
        } catch {
            print("Failed to create notification attachment: \(error)")
            return nil
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is active - include all options
        print("Notification will present in foreground: \(notification.request.content.title)")
        completionHandler([.banner, .sound, .badge, .list])
    }

    /// Handle notification click
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        // Check if this is a Gmail notification
        if let type = userInfo["type"] as? String, type == "gmail" {
            handleGmailNotificationResponse(response)
            completionHandler()
            return
        }

        let actionURL = userInfo["actionURL"] as? String
        let watcherURL = userInfo["watcherURL"] as? String
        let apiLookupCommand = userInfo["apiLookupCommand"] as? String
        BrowserNavigationService.shared.openDestination(
            preferredURLString: actionURL,
            fallbackURLString: watcherURL,
            apiLookupCommand: apiLookupCommand
        )

        completionHandler()
    }

    // MARK: - Herald

    /// Starts the Herald bridge (callback listener + registration). Call once at launch.
    func startHeraldBridge() {
        HeraldBridge.shared.start { [weak self] event, action in
            guard let self else { return 503 }
            return await self.handleHeraldCallback(event, action: action)
        }
    }

    /// How long a Herald callback may take before it is answered "try again" (Herald gives up after 5 s).
    static let heraldCallbackBudget: TimeInterval = 4

    /// A button pressed on a Herald banner. `HeraldBridge` has already checked that the payload is
    /// one WebWatcher attached to that notification.
    ///
    /// The return value is the HTTP status Herald sees. Herald dismisses the banner on a 2xx and keeps it
    /// (with a failure line) otherwise, so this answers only once the action is done: 200 on success, 409
    /// when it failed (the banner stays, no retry), 504 when it was still running after the budget (Herald
    /// retries once; the Gmail calls are idempotent), 404 when the watcher to open no longer exists.
    func handleHeraldCallback(_ event: HeraldCallbackEvent, action: HeraldCallbackAction) async -> Int {
        switch action {
        case let .gmail(actionIdentifier, accountId, messageIds, emailWatcherId):
            // Preview banners carry no real mail.
            guard !event.notificationId.hasPrefix("preview-") else {
                HeraldBridge.shared.dismiss(id: event.notificationId)
                return 200
            }
            let ok = await HeraldBridge.boundedWait(seconds: Self.heraldCallbackBudget) {
                await self.runGmailAction(
                    actionIdentifier,
                    accountId: accountId,
                    messageIds: messageIds,
                    emailWatcherId: emailWatcherId
                )
            }
            switch ok {
            case .some(true): return 200
            case .some(false):
                print("Herald callback: Gmail action \(actionIdentifier) failed; the banner stays")
                return 409
            case .none:
                print("Herald callback: Gmail action \(actionIdentifier) still running after \(Self.heraldCallbackBudget) s")
                return 504
            }

        case .openWatcher(let watcherId):
            return await MainActor.run {
                guard let watcher = self.watcherLookup?(watcherId) else { return 404 }
                BrowserNavigationService.shared.openWatcherDestination(watcher)
                return 200
            }
        }
    }

    // MARK: - Gmail Action Handling

    private func handleGmailNotificationResponse(_ response: UNNotificationResponse) {
        let userInfo = response.notification.request.content.userInfo
        guard let accountIdString = userInfo["accountId"] as? String,
              let accountId = UUID(uuidString: accountIdString),
              let accountIndex = userInfo["accountIndex"] as? Int else {
            return
        }

        let actionIdentifier = response.actionIdentifier

        // Default action (tap) — open the URL the poller computed (thread for one unread,
        // the unread search for several); fall back to the newest message's thread.
        if actionIdentifier == UNNotificationDefaultActionIdentifier {
            if let urlString = userInfo["openURL"] as? String, let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
            } else if let threadId = userInfo["threadId"] as? String,
                      let url = URL(string: "https://mail.google.com/mail/u/\(accountIndex)/#inbox/\(threadId)") {
                NSWorkspace.shared.open(url)
            }
            return
        }

        // Action button pressed — act on every counted message (accumulated notifications
        // carry `messageIds`; per-message ones only `messageId`).
        var messageIds = userInfo["messageIds"] as? [String] ?? []
        if messageIds.isEmpty, let single = userInfo["messageId"] as? String {
            messageIds = [single]
        }
        guard !messageIds.isEmpty else { return }

        let watcherId = (userInfo["emailWatcherId"] as? String).flatMap(UUID.init(uuidString:))
        let notificationId = response.notification.request.identifier

        Task {
            let ok = await runGmailAction(
                actionIdentifier,
                accountId: accountId,
                messageIds: messageIds,
                emailWatcherId: watcherId
            )
            guard ok else { return }
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [notificationId])
        }
    }

    /// Applies a Gmail action (`GMAIL_MARK_READ`, `GMAIL_ARCHIVE`, `GMAIL_DELETE`, `GMAIL_SPAM`)
    /// to `messageIds`, then clears the email watcher's unread count when it all succeeded.
    /// Shared by the native notification buttons and Herald's button callbacks.
    @discardableResult
    func runGmailAction(_ actionIdentifier: String, accountId: UUID, messageIds: [String], emailWatcherId: UUID?) async -> Bool {
        let ok = await performGmailAction(actionIdentifier: actionIdentifier, accountId: accountId, messageIds: messageIds)
        guard ok else { return false }
        if let emailWatcherId {
            await MainActor.run { EmailWatcherStore.shared.clearUnread(for: emailWatcherId) }
        }
        return true
    }

    @discardableResult
    private func performGmailAction(actionIdentifier: String, accountId: UUID, messageIds: [String]) async -> Bool {
        // Load tokens from Keychain
        guard let tokenData = KeychainService.shared.loadTokens(accountId: accountId) else {
            print("Gmail action: No tokens found for account \(accountId)")
            return false
        }

        var accessToken = tokenData.accessToken

        // Refresh if expired
        if Date() >= tokenData.expiresAt.addingTimeInterval(-60) {
            do {
                let refreshed = try await GmailOAuthService.shared.refreshAccessToken(refreshToken: tokenData.refreshToken)
                accessToken = refreshed.accessToken
                KeychainService.shared.saveTokens(
                    accountId: accountId,
                    accessToken: refreshed.accessToken,
                    refreshToken: tokenData.refreshToken,
                    expiresAt: refreshed.expiresAt
                )
            } catch {
                print("Gmail action: Token refresh failed: \(error)")
                return false
            }
        }

        var allSucceeded = true
        for messageId in messageIds {
            do {
                try await applyGmailAction(actionIdentifier, accessToken: accessToken, messageId: messageId)
                print("Gmail action \(actionIdentifier) completed for message \(messageId)")
            } catch {
                allSucceeded = false
                print("Gmail action \(actionIdentifier) failed for \(messageId): \(error)")
            }
        }
        return allSucceeded
    }

    private func applyGmailAction(_ actionIdentifier: String, accessToken: String, messageId: String) async throws {
        switch actionIdentifier {
            case "GMAIL_MARK_READ":
                try await GmailAPIService.shared.modifyMessage(
                    accessToken: accessToken,
                    messageId: messageId,
                    removeLabels: ["UNREAD"]
                )
            case "GMAIL_ARCHIVE":
                try await GmailAPIService.shared.modifyMessage(
                    accessToken: accessToken,
                    messageId: messageId,
                    removeLabels: ["INBOX"]
                )
            case "GMAIL_DELETE":
                try await GmailAPIService.shared.trashMessage(
                    accessToken: accessToken,
                    messageId: messageId
                )
            case "GMAIL_SPAM":
                try await GmailAPIService.shared.modifyMessage(
                    accessToken: accessToken,
                    messageId: messageId,
                    addLabels: ["SPAM"],
                    removeLabels: ["INBOX"]
                )
            default:
                break
        }
    }
}

// MARK: - Email watchers (§3.10)

extension NotificationService: GmailNotifying {

    /// Builds the notification's text. Pure — no `UNUserNotificationCenter`, no
    /// singletons — so tests can check exact copy (title default vs custom, the "received
    /// <time>" body, snippet truncation, the account-suffix rule) without touching
    /// Notification Center.
    static func emailWatcherContent(
        watcher: EmailWatcher,
        message: GmailMessage,
        account: GmailAccount,
        accountCount: Int = 1,
        now: Date = Date()
    ) -> EmailNotificationContent {
        let senderDisplay = message.senderName.isEmpty ? message.senderAddress : message.senderName

        let title = watcher.name.isEmpty
            ? "Email from \(senderDisplay)"
            : watcher.name

        var body = "From \(senderDisplay) · received \(EmailTimeFormatter.received(message.date, now: now))"
        if !message.snippet.isEmpty {
            body += "\n" + String(message.snippet.prefix(120))
        }
        // Only disambiguate which mailbox this came from when there's more than one
        // connected — with a single account it's already obvious.
        if accountCount > 1 {
            body += " — \(account.email)"
        }

        return EmailNotificationContent(title: title, subtitle: message.subject, body: body)
    }

    /// Send a notification for an email watcher match (G2). `notifyGmail` above stays the
    /// per-message-only fallback for the "notify for every new email" toggle (G4).
    ///
    /// `accountCount` (§3.10) comes from `GmailAccountStore.shared`, which is
    /// `@MainActor`-isolated; this method itself stays nonisolated (matching the rest of
    /// the class and the `GmailNotifying` requirement), so it hops onto the main actor
    /// itself to read it rather than requiring every caller to already be there.
    func notifyEmailWatcher(_ watcher: EmailWatcher, message: GmailMessage, account: GmailAccount) {
        Task { @MainActor in
            let accountCount = GmailAccountStore.shared.accounts.count
            let content = Self.emailWatcherContent(watcher: watcher, message: message, account: account, accountCount: accountCount)
            let herald = HeraldBridge.emailWatcherMessage(watcher: watcher, message: message, account: account, content: content)
            HeraldBridge.shared.deliver(herald) { [self] in
                postSystemEmailWatcher(watcher: watcher, message: message, account: account, content: content)
            }
        }
    }

    private func postSystemEmailWatcher(watcher: EmailWatcher, message: GmailMessage, account: GmailAccount, content: EmailNotificationContent) {
        let notificationContent = UNMutableNotificationContent()
        notificationContent.title = content.title
        notificationContent.subtitle = content.subtitle
        notificationContent.body = content.body

        if watcher.notificationSound {
            notificationContent.sound = .default
        }

        notificationContent.categoryIdentifier = "GMAIL_MESSAGE"
        notificationContent.userInfo = [
            "type": "gmail",
            "accountId": account.id.uuidString,
            "messageId": message.messageId,
            "threadId": message.threadId,
            "accountIndex": account.accountIndex,
            "emailWatcherId": watcher.id.uuidString
        ]

        // Keyed by watcher too (not just messageId, like `notifyGmail`'s identifier) so
        // the same message can independently notify more than one matching watcher.
        let identifier = "gmail-\(message.messageId)-\(watcher.id.uuidString)"

        let request = UNNotificationRequest(
            identifier: identifier,
            content: notificationContent,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("Failed to send email watcher notification: \(error)")
            }
        }
    }

    // MARK: Accumulated (one notification per watcher, replaced in place)

    static func emailWatcherNotificationIdentifier(_ watcherId: UUID) -> String {
        "emailwatcher-\(watcherId.uuidString)"
    }

    /// Text for the accumulated notification. Placeholders (`{count}`, `{sender}`,
    /// `{address}`, `{subject}`, `{time}`, `{name}`) are expanded in custom title/body.
    static func emailWatcherAccumulatedContent(
        watcher: EmailWatcher,
        newest: GmailMessage,
        account: GmailAccount,
        accountCount: Int,
        now: Date = Date()
    ) -> EmailNotificationContent {
        let sender = newest.senderName.isEmpty ? newest.senderAddress : newest.senderName
        let count = max(watcher.unreadCount, 1)
        let time = EmailTimeFormatter.received(newest.date, now: now)

        func expand(_ template: String) -> String {
            template
                .replacingOccurrences(of: "{count}", with: String(count))
                .replacingOccurrences(of: "{sender}", with: sender)
                .replacingOccurrences(of: "{address}", with: newest.senderAddress)
                .replacingOccurrences(of: "{subject}", with: newest.subject)
                .replacingOccurrences(of: "{time}", with: time)
                .replacingOccurrences(of: "{name}", with: watcher.name)
        }

        let title: String
        if let custom = watcher.notificationTitle, !custom.isEmpty {
            title = expand(custom)
        } else {
            title = count > 1 ? "\(count) new from \(sender)" : "Email from \(sender)"
        }

        let body: String
        if let custom = watcher.notificationBodyTemplate, !custom.isEmpty {
            body = expand(custom)
        } else {
            var subjects = Array(watcher.recentSubjects.prefix(3))
            if subjects.isEmpty { subjects = [newest.subject] }
            var lines = subjects.map { "• \($0)" }
            // The snippet of the newest message, when Gmail gave one: the Herald banner binds this text, and used
            // to show the snippet on its own.
            let snippet = newest.snippet.trimmingCharacters(in: .whitespacesAndNewlines)
            if !snippet.isEmpty { lines.append(String(snippet.prefix(120))) }
            var last = "received \(time)"
            if accountCount > 1 { last += " — \(account.email)" }
            lines.append(last)
            body = lines.joined(separator: "\n")
        }

        return EmailNotificationContent(title: title, subtitle: newest.subject, body: body)
    }

    func notifyEmailWatcherAccumulated(_ watcher: EmailWatcher, newest: GmailMessage, account: GmailAccount) {
        Task { @MainActor in
            let accountCount = GmailAccountStore.shared.accounts.count
            let content = Self.emailWatcherAccumulatedContent(watcher: watcher, newest: newest, account: account, accountCount: accountCount)
            // Same id on every update, so Herald (like Notification Center) replaces it in place.
            let herald = HeraldBridge.emailWatcherAccumulated(watcher: watcher, newest: newest, account: account, content: content)
            HeraldBridge.shared.deliver(herald) { [self] in
                postSystemAccumulated(watcher: watcher, newest: newest, account: account, content: content)
            }
        }
    }

    private func postSystemAccumulated(watcher: EmailWatcher, newest: GmailMessage, account: GmailAccount, content: EmailNotificationContent) {
        let identifier = Self.emailWatcherNotificationIdentifier(watcher.id)

        let nc = UNMutableNotificationContent()
        nc.title = content.title
        nc.subtitle = content.subtitle
        nc.body = content.body
        if watcher.notificationSound { nc.sound = .default }
        if let iconPath = watcher.customIconPath, !iconPath.isEmpty,
           let attachment = createAttachment(from: iconPath, id: "icon") {
            nc.attachments = [attachment]
        }
        nc.categoryIdentifier = "GMAIL_MESSAGE"
        nc.threadIdentifier = identifier

        var userInfo: [String: Any] = [
            "type": "gmail",
            "accountId": account.id.uuidString,
            "messageId": newest.messageId,
            "threadId": newest.threadId,
            "accountIndex": account.accountIndex,
            "emailWatcherId": watcher.id.uuidString,
            "messageIds": watcher.unreadMessageIds
        ]
        if let url = watcher.openURL(accountIndex: account.accountIndex) {
            userInfo["openURL"] = url.absoluteString
        }
        nc.userInfo = userInfo

        // Same identifier as the previous one → replaced in place.
        let request = UNNotificationRequest(identifier: identifier, content: nc, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error { print("Failed to send accumulated email notification: \(error)") }
        }
    }

    func clearEmailWatcherNotification(watcherId: UUID) {
        let identifier = Self.emailWatcherNotificationIdentifier(watcherId)
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [identifier])
        // Also take the banner down in Herald (no-op when Herald isn't the delivery path).
        HeraldBridge.shared.dismiss(id: identifier)
    }

    /// Preview for the email editor's "Preview Notification" button, using sample mail.
    func sendEmailPreview(watcher: EmailWatcher) {
        var sample = watcher
        sample.unreadCount = max(watcher.unreadCount, 3)
        sample.recentSubjects = ["Quarterly invoice", "Meeting notes", "Welcome aboard"]
        let address = watcher.senders.first(where: { $0.contains("@") && !$0.hasPrefix("@") }) ?? "sender@example.com"
        let message = GmailMessage(
            accountId: watcher.accountId, messageId: "preview", threadId: "preview",
            from: "Sample Sender <\(address)>", subject: "Quarterly invoice",
            date: Date(), labelIds: [], snippet: ""
        )
        let account = GmailAccount(email: "you@example.com", accountIndex: 0)
        var content = Self.emailWatcherAccumulatedContent(watcher: sample, newest: message, account: account, accountCount: 1)
        content.title = "[Preview] " + content.title

        let identifier = "preview-\(UUID().uuidString)"
        let finalContent = content
        let herald = HeraldBridge.emailWatcherAccumulated(
            watcher: sample, newest: message, account: account, content: finalContent,
            idOverride: identifier, isPreview: true
        )
        HeraldBridge.shared.deliver(herald) { [self] in
            postSystemEmailPreview(watcher: watcher, content: finalContent, identifier: identifier)
        }
    }

    private func postSystemEmailPreview(watcher: EmailWatcher, content: EmailNotificationContent, identifier: String) {
        let nc = UNMutableNotificationContent()
        nc.title = content.title
        nc.subtitle = content.subtitle
        nc.body = content.body
        nc.sound = .default
        if let iconPath = watcher.customIconPath, !iconPath.isEmpty,
           let attachment = createAttachment(from: iconPath, id: "icon") {
            nc.attachments = [attachment]
        }
        let request = UNNotificationRequest(identifier: identifier, content: nc, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error { print("Failed to send email preview notification: \(error)") }
        }
    }
}
