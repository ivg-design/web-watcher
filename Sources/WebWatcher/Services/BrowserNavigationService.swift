import Foundation
import AppKit
import ApplicationServices

/// Handles opening watcher destinations with optional tab reuse and API lookup commands.
final class BrowserNavigationService: @unchecked Sendable {
    static let shared = BrowserNavigationService()

    private let commandQueue = DispatchQueue(label: "com.webwatcher.navigation.command", qos: .userInitiated)
    private let permissionAlertQueue = DispatchQueue(label: "com.webwatcher.navigation.permission-alert")
    private let tccResetQueue = DispatchQueue(label: "com.webwatcher.navigation.tcc-reset")
    private var lastPermissionAlertDate: Date?

    private init() {}

    /// Open the target destination for a watcher.
    func openWatcherDestination(_ watcher: Watcher) {
        openDestination(
            preferredURLString: watcher.actionURL,
            fallbackURLString: watcher.url,
            apiLookupCommand: watcher.apiLookupCommand
        )
    }

    /// Ensure Safari automation is available for page monitoring.
    /// Returns true when WebWatcher can send AppleEvents to Safari.
    @MainActor
    func ensureSafariAutomationPermissionForMonitoring() -> Bool {
        let safari = BrowserTarget(bundleID: "com.apple.Safari", appName: "Safari", kind: .safari)
        let state = resolveAutomationPermissionState(for: safari)
        guard state == .allowed else {
            showAutomationPermissionAlert(for: safari.appName)
            return false
        }
        return true
    }

    /// Open macOS Automation settings pane.
    @MainActor
    func openAutomationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }

    /// What we can say about an automation permission without prompting the user.
    enum PermissionReport {
        case granted
        case denied
        /// macOS will not reveal the answer without showing a consent prompt. This is
        /// NOT the same as denied, and must not be reported as "not granted" — doing so
        /// showed a red "Not granted" for permissions the user had actually allowed.
        case undetermined

        var isGranted: Bool { self == .granted }
    }

    /// Check whether automation permission is currently granted for a target app bundle identifier.
    func hasAutomationPermission(bundleID: String) -> Bool {
        automationPermissionReport(bundleID: bundleID) == .granted
    }

    /// Tri-state permission check that preserves the "can't tell" case.
    func automationPermissionReport(bundleID: String) -> PermissionReport {
        switch requestAutomationPermissionState(bundleID: bundleID, askUserIfNeeded: false) {
        case .allowed: return .granted
        case .denied:  return .denied
        case .unknown: return .undetermined
        }
    }

    /// Prompt for automation permission for a target app bundle identifier if needed.
    @MainActor
    func requestAutomationPermission(bundleID: String, appName: String) -> Bool {
        // Retry once while frontmost, because macOS can suppress consent prompts for background apps.
        var state = requestAutomationPermissionState(bundleID: bundleID, askUserIfNeeded: true)
        if state == .unknown {
            NSApp.activate(ignoringOtherApps: true)
            state = requestAutomationPermissionState(bundleID: bundleID, askUserIfNeeded: true)
        }

        if state != .allowed {
            showAutomationPermissionAlert(for: appName)
        }

        return state == .allowed
    }

    /// Snapshot automation permission for the current default browser.
    func defaultBrowserAutomationPermissionSnapshot() -> (bundleID: String, appName: String, granted: Bool)? {
        guard let bundleID = defaultBrowserBundleIdentifier() else {
            return nil
        }

        return (
            bundleID: bundleID,
            appName: applicationName(for: bundleID) ?? bundleID,
            granted: hasAutomationPermission(bundleID: bundleID)
        )
    }

    /// Open a destination from notification/user action inputs.
    func openDestination(
        preferredURLString: String?,
        fallbackURLString: String?,
        apiLookupCommand: String?
    ) {
        Task {
            guard let url = await resolveTargetURL(
                preferredURLString: preferredURLString,
                fallbackURLString: fallbackURLString,
                apiLookupCommand: apiLookupCommand
            ) else {
                return
            }

            await MainActor.run {
                self.openURL(url)
            }
        }
    }

    // MARK: - Target Resolution

    private func resolveTargetURL(
        preferredURLString: String?,
        fallbackURLString: String?,
        apiLookupCommand: String?
    ) async -> URL? {
        if let command = apiLookupCommand?.trimmingCharacters(in: .whitespacesAndNewlines),
           !command.isEmpty,
           let commandURL = await resolveURLFromLookupCommand(command, fallbackURLString: fallbackURLString) {
            return commandURL
        }

        if let preferredURLString,
           let preferredURL = URL(string: preferredURLString),
           preferredURL.scheme != nil {
            return preferredURL
        }

        if let fallbackURLString,
           let fallbackURL = URL(string: fallbackURLString),
           fallbackURL.scheme != nil {
            return fallbackURL
        }

        return nil
    }

    private func resolveURLFromLookupCommand(_ command: String, fallbackURLString: String?) async -> URL? {
        await withCheckedContinuation { continuation in
            commandQueue.async {
                let expandedCommand = self.expandLookupCommand(command, fallbackURLString: fallbackURLString)
                guard let output = self.runShellCommand(expandedCommand) else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: self.extractURL(fromCommandOutput: output))
            }
        }
    }

    private func expandLookupCommand(_ command: String, fallbackURLString: String?) -> String {
        var expanded = command
        let fallback = fallbackURLString ?? ""
        let domain = URL(string: fallback)?.host ?? ""

        expanded = expanded.replacingOccurrences(of: "{url}", with: fallback)
        expanded = expanded.replacingOccurrences(of: "{domain}", with: domain)
        return expanded
    }

    private func runShellCommand(_ command: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", command]

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
        } catch {
            print("Failed to run lookup command: \(error)")
            return nil
        }

        let timeout: TimeInterval = 10
        let start = Date()
        while process.isRunning && Date().timeIntervalSince(start) < timeout {
            Thread.sleep(forTimeInterval: 0.05)
        }

        if process.isRunning {
            process.terminate()
            print("Lookup command timed out after \(Int(timeout))s")
            return nil
        }

        let outputData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errorData = stderr.fileHandleForReading.readDataToEndOfFile()

        guard process.terminationStatus == 0 else {
            let errorOutput = String(data: errorData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown error"
            print("Lookup command failed (\(process.terminationStatus)): \(errorOutput)")
            return nil
        }

        return String(data: outputData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractURL(fromCommandOutput output: String) -> URL? {
        if let direct = URL(string: output), direct.scheme != nil {
            return direct
        }

        for rawLine in output.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            if let url = URL(string: line), url.scheme != nil {
                return url
            }
        }

        guard let data = output.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        for key in ["url", "link", "message_url", "action_url"] {
            if let value = object[key] as? String,
               let url = URL(string: value),
               url.scheme != nil {
                return url
            }
        }

        return nil
    }

    // MARK: - Browser Open

    @MainActor
    private func openURL(_ url: URL) {
        if AppSettings.shared.reuseExistingBrowserTabByDomain && activateExistingDomainTabIfPossible(for: url) {
            return
        }

        if let defaultBrowserURL = defaultBrowserApplicationURL() {
            let config = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.open([url], withApplicationAt: defaultBrowserURL, configuration: config) { _, error in
                if let error {
                    print("Failed to open URL in default browser: \(error)")
                    NSWorkspace.shared.open(url)
                }
            }
            return
        }

        NSWorkspace.shared.open(url)
    }

    @MainActor
    private func activateExistingDomainTabIfPossible(for url: URL) -> Bool {
        guard let targetHost = normalizedHost(from: url),
              let browser = defaultBrowserTarget() else {
            return false
        }
        let targetRootDomain = rootDomain(fromHost: targetHost)

        // Reuse is restricted to the default browser only.
        guard isBrowserRunning(bundleID: browser.bundleID) else {
            return false
        }

        let permissionState = resolveAutomationPermissionState(for: browser)
        if case .denied = permissionState {
            Task { @MainActor in
                self.showAutomationPermissionAlert(for: browser.appName)
            }
            return false
        }
        if case .unknown = permissionState {
            // Consent prompt could not be shown (for example, when macOS suppresses background prompts).
            // Skip reuse and fall back to opening the URL in the default browser.
            return false
        }

        let escapedBundleID = browser.bundleID.replacingOccurrences(of: "\"", with: "\\\"")
        let escapedHost = targetHost.replacingOccurrences(of: "\"", with: "\\\"")
        let escapedRootDomain = targetRootDomain.replacingOccurrences(of: "\"", with: "\\\"")

        let script: String
        switch browser.kind {
        case .safari:
            script = generateSafariDomainMatchScript(
                bundleIdentifier: escapedBundleID,
                targetHost: escapedHost,
                targetRootDomain: escapedRootDomain
            )
        case .chromium:
            script = generateChromiumDomainMatchScript(
                bundleIdentifier: escapedBundleID,
                targetHost: escapedHost,
                targetRootDomain: escapedRootDomain
            )
        }

        let result = executeAppleScript(script)
        if result.value == "REUSED" {
            return true
        }
        if let error = result.error {
            if isAutomationPermissionDenied(error: result.error, errorCode: result.errorCode) {
                Task { @MainActor in
                    self.showAutomationPermissionAlert(for: browser.appName)
                }
            }
            print("Tab reuse failed for default browser \(browser.appName) (\(browser.bundleID), code: \(result.errorCode ?? 0)): \(error)")
        }

        return false
    }

    private func normalizedHost(from url: URL) -> String? {
        guard var host = url.host?.lowercased(), !host.isEmpty else { return nil }
        if host.hasSuffix(".") {
            host.removeLast()
        }
        if host.hasPrefix("www.") {
            host = String(host.dropFirst(4))
        }
        return host
    }

    private func rootDomain(fromHost host: String) -> String {
        let components = host.split(separator: ".")
        guard components.count >= 2 else { return host }
        if components.count >= 3 {
            let last = String(components[components.count - 1])
            let secondToLast = String(components[components.count - 2])
            let thirdToLast = String(components[components.count - 3])
            let commonSecondLevel = Set(["co", "com", "org", "net", "gov", "ac", "edu"])
            if last.count == 2 && commonSecondLevel.contains(secondToLast) {
                return "\(thirdToLast).\(secondToLast).\(last)"
            }
        }
        let secondToLast = String(components[components.count - 2])
        let last = String(components[components.count - 1])
        return "\(secondToLast).\(last)"
    }

    private func browserTarget(for bundleID: String) -> BrowserTarget? {
        switch bundleID {
        case "com.apple.Safari":
            return BrowserTarget(
                bundleID: bundleID,
                appName: applicationName(for: bundleID) ?? "Safari",
                kind: .safari
            )
        default:
            guard isChromiumBundleID(bundleID) else { return nil }
            return BrowserTarget(
                bundleID: bundleID,
                appName: applicationName(for: bundleID) ?? "Google Chrome",
                kind: .chromium
            )
        }
    }

    private func defaultBrowserBundleIdentifier() -> String? {
        guard let sampleURL = URL(string: "https://example.com"),
              let appURL = NSWorkspace.shared.urlForApplication(toOpen: sampleURL),
              let bundle = Bundle(url: appURL),
              let bundleID = bundle.bundleIdentifier else {
            return nil
        }
        return bundleID
    }

    private func defaultBrowserApplicationURL() -> URL? {
        guard let sampleURL = URL(string: "https://example.com") else {
            return nil
        }
        return NSWorkspace.shared.urlForApplication(toOpen: sampleURL)
    }

    private func defaultBrowserTarget() -> BrowserTarget? {
        guard let bundleID = defaultBrowserBundleIdentifier() else { return nil }
        return browserTarget(for: bundleID)
    }

    private func applicationName(for bundleID: String) -> String? {
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID),
           let bundle = Bundle(url: appURL) {
            if let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
               !displayName.isEmpty {
                return displayName
            }
            if let name = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String,
               !name.isEmpty {
                return name
            }
        }

        return NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleID)
            .first?
            .localizedName
    }

    private func isBrowserRunning(bundleID: String) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
    }

    private func isChromiumBundleID(_ bundleID: String) -> Bool {
        bundleID.hasPrefix("com.google.Chrome")
            || bundleID == "com.brave.Browser"
            || bundleID == "com.microsoft.edgemac"
            || bundleID == "company.thebrowser.Browser"
            || bundleID == "com.operasoftware.Opera"
            || bundleID == "com.vivaldi.Vivaldi"
    }

    private func requestAutomationPermissionState(bundleID: String, askUserIfNeeded: Bool) -> AutomationPermissionState {
        let descriptor = NSAppleEventDescriptor(bundleIdentifier: bundleID)
        guard let targetDesc = descriptor.aeDesc else {
            return .unknown
        }

        let status = AEDeterminePermissionToAutomateTarget(
            targetDesc,
            AEEventClass(kCoreEventClass),
            AEEventID(kAEGetData),
            askUserIfNeeded
        )

        switch status {
        case OSStatus(noErr):
            return .allowed
        case OSStatus(errAEEventNotPermitted):
            return .denied
        case OSStatus(errAEEventWouldRequireUserConsent):
            return .unknown
        default:
            return .unknown
        }
    }

    @MainActor
    private func resolveAutomationPermissionState(for browser: BrowserTarget) -> AutomationPermissionState {
        var state = requestAutomationPermissionState(bundleID: browser.bundleID, askUserIfNeeded: true)
        if state == .unknown {
            // Bring WebWatcher to front so macOS can present automation consent.
            NSApp.activate(ignoringOtherApps: true)
            state = requestAutomationPermissionState(bundleID: browser.bundleID, askUserIfNeeded: true)
        }

        if state == .unknown {
            state = probeBrowserAutomationPermissionViaAppleScript(browser: browser)
        }

        return state
    }

    private func probeBrowserAutomationPermissionViaAppleScript(browser: BrowserTarget) -> AutomationPermissionState {
        let escapedBundleID = browser.bundleID.replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        with timeout of 3 seconds
            tell application id "\(escapedBundleID)"
                count of windows
                return "OK"
            end tell
        end timeout
        """
        let result = executeAppleScript(script)
        if result.value == "OK" {
            return .allowed
        }
        if isAutomationPermissionDenied(error: result.error, errorCode: result.errorCode) {
            return .denied
        }
        return .unknown
    }

    private func isAutomationPermissionDenied(error: String?, errorCode: Int?) -> Bool {
        if errorCode == -1743 {
            return true
        }
        guard let error else { return false }
        return error.localizedCaseInsensitiveContains("not authorized")
            || error.localizedCaseInsensitiveContains("not permitted")
    }

    private func resetAutomationPermissions() {
        tccResetQueue.async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
            process.arguments = ["reset", "AppleEvents", Bundle.main.bundleIdentifier ?? "com.webwatcher.app"]
            do {
                try process.run()
                process.waitUntilExit()
                print("Reset AppleEvents permissions (status: \(process.terminationStatus))")
            } catch {
                print("Failed to reset AppleEvents permissions: \(error)")
            }
        }
    }

    @MainActor
    private func showAutomationPermissionAlert(for browserName: String) {
        let shouldShow = permissionAlertQueue.sync { () -> Bool in
            let now = Date()
            if let last = lastPermissionAlertDate, now.timeIntervalSince(last) < 30 {
                return false
            }
            lastPermissionAlertDate = now
            return true
        }

        guard shouldShow else { return }

        let retryInstruction: String
        if browserName.caseInsensitiveCompare("Safari") == .orderedSame {
            retryInstruction = "If \(browserName) is NOT listed, click \"Reset Automation Permission\", then click \"Check All Now\" in WebWatcher to trigger consent again."
        } else {
            retryInstruction = "If \(browserName) is NOT listed, click \"Reset Automation Permission\", then click a watcher row in the WebWatcher popover while \(browserName) is running to trigger consent again."
        }

        let alert = NSAlert()
        alert.messageText = "Enable Browser Automation"
        alert.informativeText = """
        WebWatcher can’t read open tabs in \(browserName) yet.

        If \(browserName) is listed under:
        Privacy & Security -> Automation -> WebWatcher
        enable it there.

        \(retryInstruction)
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Automation Settings")
        alert.addButton(withTitle: "Reset Automation Permission")
        alert.addButton(withTitle: "OK")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
                NSWorkspace.shared.open(url)
            }
        case .alertSecondButtonReturn:
            resetAutomationPermissions()
        default:
            break
        }
    }

    private func generateSafariDomainMatchScript(bundleIdentifier: String, targetHost: String, targetRootDomain: String) -> String {
        """
        on normalizedHost(theURL)
            set oldTIDs to AppleScript's text item delimiters
            try
                set urlText to theURL as text
                if urlText does not contain "://" then return ""
                set AppleScript's text item delimiters to "://"
                set schemeParts to text items of urlText
                if (count of schemeParts) < 2 then
                    set AppleScript's text item delimiters to oldTIDs
                    return ""
                end if
                set restPart to item 2 of schemeParts
                set AppleScript's text item delimiters to "/"
                set pathParts to text items of restPart
                set hostPart to item 1 of pathParts

                if hostPart contains ":" then
                    set AppleScript's text item delimiters to ":"
                    set hostParts to text items of hostPart
                    set hostPart to item 1 of hostParts
                end if

                set AppleScript's text item delimiters to oldTIDs
                if hostPart starts with "www." then
                    return text 5 thru -1 of hostPart
                end if
                return hostPart
            on error
                set AppleScript's text item delimiters to oldTIDs
                return ""
            end try
        end normalizedHost

        on rootDomain(theHost)
            if theHost is "" then return ""
            set oldTIDs to AppleScript's text item delimiters
            set AppleScript's text item delimiters to "."
            set hostParts to text items of theHost
            set AppleScript's text item delimiters to oldTIDs

            set partCount to count of hostParts
            if partCount < 2 then return theHost
            if partCount >= 3 then
                set tldPart to item partCount of hostParts
                set sldPart to item (partCount - 1) of hostParts
                set thirdPart to item (partCount - 2) of hostParts
                if (length of tldPart) is 2 and (sldPart is "co" or sldPart is "com" or sldPart is "org" or sldPart is "net" or sldPart is "gov" or sldPart is "ac" or sldPart is "edu") then
                    return thirdPart & "." & sldPart & "." & tldPart
                end if
            end if
            return item (partCount - 1) of hostParts & "." & item partCount of hostParts
        end rootDomain

        set targetDomain to "\(targetHost)"
        set targetRootDomain to "\(targetRootDomain)"
        with timeout of 5 seconds
            tell application id "\(bundleIdentifier)"
                set foundTab to missing value
                set foundWindow to missing value
                repeat with w in windows
                    repeat with t in tabs of w
                        try
                            set tabHost to my normalizedHost(URL of t)
                            set tabRootDomain to my rootDomain(tabHost)
                            if tabHost is targetDomain or tabHost ends with "." & targetDomain or tabRootDomain is targetRootDomain then
                                set foundTab to t
                                set foundWindow to w
                                exit repeat
                            end if
                        end try
                    end repeat
                    if foundTab is not missing value then exit repeat
                end repeat

                if foundTab is missing value then
                    return "NOT_FOUND"
                end if

                set current tab of foundWindow to foundTab
                set index of foundWindow to 1
                activate
                return "REUSED"
            end tell
        end timeout
        """
    }

    private func generateChromiumDomainMatchScript(bundleIdentifier: String, targetHost: String, targetRootDomain: String) -> String {
        """
        on normalizedHost(theURL)
            set oldTIDs to AppleScript's text item delimiters
            try
                set urlText to theURL as text
                if urlText does not contain "://" then return ""
                set AppleScript's text item delimiters to "://"
                set schemeParts to text items of urlText
                if (count of schemeParts) < 2 then
                    set AppleScript's text item delimiters to oldTIDs
                    return ""
                end if
                set restPart to item 2 of schemeParts
                set AppleScript's text item delimiters to "/"
                set pathParts to text items of restPart
                set hostPart to item 1 of pathParts

                if hostPart contains ":" then
                    set AppleScript's text item delimiters to ":"
                    set hostParts to text items of hostPart
                    set hostPart to item 1 of hostParts
                end if

                set AppleScript's text item delimiters to oldTIDs
                if hostPart starts with "www." then
                    return text 5 thru -1 of hostPart
                end if
                return hostPart
            on error
                set AppleScript's text item delimiters to oldTIDs
                return ""
            end try
        end normalizedHost

        on rootDomain(theHost)
            if theHost is "" then return ""
            set oldTIDs to AppleScript's text item delimiters
            set AppleScript's text item delimiters to "."
            set hostParts to text items of theHost
            set AppleScript's text item delimiters to oldTIDs

            set partCount to count of hostParts
            if partCount < 2 then return theHost
            if partCount >= 3 then
                set tldPart to item partCount of hostParts
                set sldPart to item (partCount - 1) of hostParts
                set thirdPart to item (partCount - 2) of hostParts
                if (length of tldPart) is 2 and (sldPart is "co" or sldPart is "com" or sldPart is "org" or sldPart is "net" or sldPart is "gov" or sldPart is "ac" or sldPart is "edu") then
                    return thirdPart & "." & sldPart & "." & tldPart
                end if
            end if
            return item (partCount - 1) of hostParts & "." & item partCount of hostParts
        end rootDomain

        set targetDomain to "\(targetHost)"
        set targetRootDomain to "\(targetRootDomain)"
        with timeout of 5 seconds
            tell application id "\(bundleIdentifier)"
                set foundWindow to missing value
                set foundTabIndex to 0
                repeat with w in windows
                    set tabIndex to 1
                    repeat with t in tabs of w
                        try
                            set tabHost to my normalizedHost(URL of t)
                            set tabRootDomain to my rootDomain(tabHost)
                            if tabHost is targetDomain or tabHost ends with "." & targetDomain or tabRootDomain is targetRootDomain then
                                set foundWindow to w
                                set foundTabIndex to tabIndex
                                exit repeat
                            end if
                        end try
                        set tabIndex to tabIndex + 1
                    end repeat
                    if foundWindow is not missing value then exit repeat
                end repeat

                if foundWindow is missing value then
                    return "NOT_FOUND"
                end if

                set active tab index of foundWindow to foundTabIndex
                set index of foundWindow to 1
                activate
                return "REUSED"
            end tell
        end timeout
        """
    }

    private func executeAppleScript(_ script: String) -> (value: String?, error: String?, errorCode: Int?) {
        var error: NSDictionary?
        let appleScript = NSAppleScript(source: script)
        let result = appleScript?.executeAndReturnError(&error)

        if let error {
            let message = error[NSAppleScript.errorMessage] as? String ?? "Unknown AppleScript error"
            let code = error[NSAppleScript.errorNumber] as? Int
            return (nil, message, code)
        }

        return (result?.stringValue, nil, nil)
    }
}

private struct BrowserTarget {
    let bundleID: String
    let appName: String
    let kind: BrowserTargetKind
}

private enum BrowserTargetKind {
    case safari
    case chromium
}

private enum AutomationPermissionState {
    case allowed
    case denied
    case unknown
}
