import Foundation
import UserNotifications
import AppKit

/// Handles sending native macOS notifications
class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    /// Request notification permissions
    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            return granted
        } catch {
            print("Failed to request notification permission: \(error)")
            return false
        }
    }

    /// Check if notifications are authorized
    func checkPermission() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized
    }

    /// Send a notification for a watcher update
    func notify(watcher: Watcher, newValue: String, oldValue: String?) {
        let content = buildNotificationContent(watcher: watcher, newValue: newValue, oldValue: oldValue)

        // Create request with unique identifier
        let request = UNNotificationRequest(
            identifier: "watcher-\(watcher.id.uuidString)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil // Deliver immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to send notification: \(error)")
            }
        }
    }

    /// Send a preview notification
    func sendPreview(watcher: Watcher, testValue: String = "3") {
        let content = buildNotificationContent(watcher: watcher, newValue: testValue, oldValue: "0", isPreview: true)

        let request = UNNotificationRequest(
            identifier: "preview-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to send preview notification: \(error)")
            }
        }
    }

    /// Build notification content with all customizations
    private func buildNotificationContent(watcher: Watcher, newValue: String, oldValue: String?, isPreview: Bool = false) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()

        // Title: use custom or default to watcher name
        content.title = watcher.notificationTitle ?? watcher.name
        if isPreview {
            content.title = "[Preview] " + content.title
        }

        // Body: use custom template or generate based on watch type
        if let template = watcher.notificationBodyTemplate, !template.isEmpty {
            content.body = template
                .replacingOccurrences(of: "{value}", with: newValue)
                .replacingOccurrences(of: "{name}", with: watcher.name)
        } else {
            // Default body based on watch type
            switch watcher.watchType {
            case .badgeNumber:
                if let count = Int(newValue), count > 0 {
                    content.body = "You have \(count) new message\(count == 1 ? "" : "s")"
                } else {
                    content.body = "New activity detected"
                }

            case .elementCount:
                let oldCount = oldValue.flatMap { Int($0) } ?? 0
                let newCount = Int(newValue) ?? 0
                let diff = newCount - oldCount
                if diff > 0 {
                    content.body = "\(diff) new item\(diff == 1 ? "" : "s") (\(newCount) total)"
                } else {
                    content.body = "Count changed to \(newCount)"
                }

            case .textChange:
                content.body = "Content updated"
                content.subtitle = String(newValue.prefix(100))

            case .elementExists:
                content.body = newValue == "true" ? "Element appeared" : "Element not found"

            case .elementDisappears:
                content.body = newValue == "false" ? "Element disappeared" : "Element still present"
            }
        }

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

        // Store action URL in userInfo
        if let actionURL = watcher.actionURL ?? URL(string: watcher.url)?.absoluteString {
            content.userInfo = ["actionURL": actionURL, "watcherId": watcher.id.uuidString]
        }

        return content
    }

    /// Create a notification attachment from an image path
    private func createAttachment(from imagePath: String, id: String) -> UNNotificationAttachment? {
        let fileURL = URL(fileURLWithPath: imagePath)

        // Check if file exists
        guard FileManager.default.fileExists(atPath: imagePath) else {
            print("Icon file not found: \(imagePath)")
            return nil
        }

        // Copy to temp location (required for attachments)
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent("\(id)-\(UUID().uuidString).\(fileURL.pathExtension)")

        do {
            try FileManager.default.copyItem(at: fileURL, to: tempURL)
            let attachment = try UNNotificationAttachment(identifier: id, url: tempURL, options: [
                UNNotificationAttachmentOptionsThumbnailClippingRectKey: CGRect(x: 0, y: 0, width: 1, height: 1).dictionaryRepresentation
            ])
            return attachment
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
        // Show notification even when app is active
        completionHandler([.banner, .sound])
    }

    /// Handle notification click
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        if let urlString = userInfo["actionURL"] as? String,
           let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }

        completionHandler()
    }
}
