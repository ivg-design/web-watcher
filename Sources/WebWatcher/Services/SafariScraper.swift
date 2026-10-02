import Foundation

/// Everything the editor's Element Picker Assistant needs from Safari: scanning the
/// page for candidates, running a "Pick in Safari" session, and the tab-liveness
/// primitives (activate / reload) that both the assistant and `WatcherService`'s
/// recovery path rely on. `SafariScraper` conforms; tests use a fake.
protocol ElementProbing: AnyObject {
    func scan(_ watcher: Watcher, profile: SiteProfile?) async -> ProbeReport
    /// Activates the tab, injects the hover-highlight overlay. Success ⇔
    /// `report.pickState == .waiting`.
    func beginPick(_ watcher: Watcher, profile: SiteProfile?) async -> ProbeReport
    func pollPick(_ watcher: Watcher, profile: SiteProfile?) async -> ProbeReport
    func endPick(_ watcher: Watcher, profile: SiteProfile?) async
    /// Activates the tab, then asks the page to flash the element. True iff found.
    func highlight(_ selector: String, watcher: Watcher, profile: SiteProfile?) async -> Bool
    func reloadTab(for watcher: Watcher, profile: SiteProfile?) async -> Bool
    func openBackgroundTab(for watcher: Watcher, profile: SiteProfile?) async -> Bool
    func diagnose(_ watcher: Watcher, profile: SiteProfile?) async -> ProbeReport
    /// G1 step 1 ("Page"): is the watcher's page open in Safari and loaded? Never
    /// activates the tab or disturbs a pick session in progress (§3.6).
    func locate(_ watcher: Watcher, profile: SiteProfile?) async -> ProbeReport
    /// The app-side "Use this element" action (§9.2) — confirms whatever is
    /// currently selected in an in-progress pick session.
    func pickConfirm(_ watcher: Watcher, profile: SiteProfile?) async -> ProbeReport
}

/// Reads page state out of Safari using AppleScript.
///
/// Checks run inside the user's own logged-in session, which is the app's core
/// advantage: no separate authentication, and reading an already-open tab generates
/// no network traffic of its own.
final class SafariScraper: ElementProbing, @unchecked Sendable {
    static let shared = SafariScraper()

    /// Routine checks/diagnosis: probes that can legitimately take up to ~17s
    /// (a 15s in-script reload wait plus settle delay).
    private let scriptQueue = DispatchQueue(label: "com.webwatcher.safari-scraper", qos: .userInitiated)

    /// Scan / Pick in Safari / highlight / their own activate & reload recoveries.
    /// A "Pick in Safari" session polls every 0.5s for up to 90s — if that shared
    /// the queue above, it would stall behind whatever routine watcher check
    /// happened to be running, and the picker would feel broken. Kept serial (not
    /// concurrent) because NSAppleScript talking to the same Safari process from two
    /// threads at once is exactly the kind of thing that produces stale tab references.
    private let interactiveQueue = DispatchQueue(label: "com.webwatcher.safari-scraper.interactive", qos: .userInitiated)

    // MARK: - Public — routine checks

    /// Run a normal check.
    func check(_ watcher: Watcher, profile: SiteProfile?) async -> WatchResult {
        let report = await run(watcher: watcher, profile: profile, mode: .check)
        return WatchResult(watcherId: watcher.id, report: report, timestamp: Date())
    }

    /// Run a check and collect a step-by-step diagnosis for the editor.
    func diagnose(_ watcher: Watcher, profile: SiteProfile?) async -> ProbeReport {
        await run(watcher: watcher, profile: profile, mode: .diagnose)
    }

    /// Ask the page for ranked anchor candidates.
    func suggestAnchors(_ watcher: Watcher, profile: SiteProfile?) async -> ProbeReport {
        await run(watcher: watcher, profile: profile, mode: .suggestAnchors)
    }

    /// Open the watcher's page as a background tab. Verified not to steal focus.
    /// Returns true if a tab was opened.
    func openBackgroundTab(for watcher: Watcher, profile: SiteProfile?) async -> Bool {
        let target = profile.map { $0.watchURL.isEmpty ? watcher.url : $0.watchURL } ?? watcher.url
        guard !target.isEmpty else { return false }

        let script = ProbeScript.openBackgroundTabScript(url: target)
        return await withCheckedContinuation { continuation in
            scriptQueue.async {
                let result = self.executeAppleScript(script)
                continuation.resume(returning: result.value == "WW_OPENED")
            }
        }
    }

    // MARK: - Public — Element Picker Assistant

    /// Inspect the open tab and rank badge/counter candidates (G1 "Scan page").
    func scan(_ watcher: Watcher, profile: SiteProfile?) async -> ProbeReport {
        await run(watcher: watcher, profile: profile, mode: .scan)
    }

    /// Brings Safari forward and installs the hover-highlight overlay.
    func beginPick(_ watcher: Watcher, profile: SiteProfile?) async -> ProbeReport {
        guard await activateTab(for: watcher, profile: profile) else {
            return ProbeReport(observation: .cannot(.noTab, detail: nil))
        }
        return await run(watcher: watcher, profile: profile, mode: .pickStart)
    }

    func pollPick(_ watcher: Watcher, profile: SiteProfile?) async -> ProbeReport {
        await run(watcher: watcher, profile: profile, mode: .pickPoll)
    }

    func endPick(_ watcher: Watcher, profile: SiteProfile?) async {
        _ = await run(watcher: watcher, profile: profile, mode: .pickStop)
    }

    /// Reads whether the watcher's page is open/loaded (G1 step 1 "Page"). Purely
    /// a read, exactly like `scan` — never activates the tab, so it is safe to call
    /// on every keystroke's debounce without stealing the user's focus.
    func locate(_ watcher: Watcher, profile: SiteProfile?) async -> ProbeReport {
        await run(watcher: watcher, profile: profile, mode: .locate)
    }

    /// The app-side "Use this element" action (§9.2): asks the page to confirm
    /// whatever is currently selected in an in-progress pick session. Dispatched
    /// exactly like `pollPick` — no tab activation — because it is the CSP-proof
    /// fallback for the in-page toolbar's own key listeners, which some sites block.
    func pickConfirm(_ watcher: Watcher, profile: SiteProfile?) async -> ProbeReport {
        await run(watcher: watcher, profile: profile, mode: .pickConfirm)
    }

    /// Brings Safari forward and asks the page to flash the element at `selector`.
    func highlight(_ selector: String, watcher: Watcher, profile: SiteProfile?) async -> Bool {
        guard await activateTab(for: watcher, profile: profile) else { return false }
        let report = await run(watcher: watcher, profile: profile, mode: .highlight(selector: selector))
        // Pattern-matched rather than `==` — `Observation` isn't `Equatable`, and a
        // literal match is exactly what "true iff observation == .value(\"1\")" means.
        if case .value("1") = report.observation { return true }
        return false
    }

    /// Brings the watcher's tab to the front. Used by `beginPick` and `highlight`,
    /// which need Safari focused for the user to click or to see the flash — never
    /// by `scan`, which reads the page without disturbing whatever the user is doing.
    ///
    /// This is the one script that sends AppleScript's `activate` command, which
    /// brings another application (Safari) to the foreground. Apple's NSAppleScript
    /// threading guidance says scripts that touch the UI/foreground layer should run
    /// on the main thread — off-main worked in this app's own in-session testing on
    /// `interactiveQueue`, but that is not documented behavior to rely on, so this
    /// one script (§9.3) is dispatched via `MainActor.run` instead of the background
    /// queue every other probe/reload script uses. `executeAndReturnError` itself
    /// still blocks synchronously either way; only the thread it blocks on changes.
    func activateTab(for watcher: Watcher, profile: SiteProfile?) async -> Bool {
        let script = ProbeScript.activateTabScript(for: watcher, profile: profile)
        let result = await MainActor.run {
            self.executeAppleScript(script)
        }
        return result.value == "WW_ACTIVATED"
    }

    /// Reloads the watcher's tab in place. Used both by the assistant's own
    /// `.tabSuspended` recovery (scan/pick) and by `WatcherService`'s throttled
    /// recovery for routine checks (F1).
    func reloadTab(for watcher: Watcher, profile: SiteProfile?) async -> Bool {
        let script = ProbeScript.reloadTabScript(for: watcher, profile: profile)
        return await withCheckedContinuation { continuation in
            interactiveQueue.async {
                let result = self.executeAppleScript(script)
                continuation.resume(returning: result.value == "WW_RELOADED")
            }
        }
    }

    // MARK: - Private

    private func run(watcher: Watcher, profile: SiteProfile?, mode: ProbeMode) async -> ProbeReport {
        let script = ProbeScript.probeScript(for: watcher, profile: profile, mode: mode)
        let queue = mode.isInteractive ? interactiveQueue : scriptQueue

        return await withCheckedContinuation { continuation in
            queue.async {
                let result = self.executeAppleScript(script)

                if let failure = result.failure {
                    continuation.resume(returning: ProbeReport(observation: .cannot(failure.0, detail: failure.1)))
                    return
                }

                switch result.value {
                case "WW_SAFARI_CLOSED":
                    continuation.resume(returning: ProbeReport(observation: .cannot(.safariClosed, detail: nil)))
                case "WW_NO_TAB":
                    continuation.resume(returning: ProbeReport(observation: .cannot(.noTab, detail: nil)))
                case "WW_NO_WINDOW":
                    continuation.resume(returning: ProbeReport(observation: .cannot(.noTab, detail: "Safari has no window")))
                case "WW_TAB_BLANK":
                    // Safari unloaded the tab; the in-script reload-once already failed (F1).
                    continuation.resume(returning: ProbeReport(observation: .cannot(.tabSuspended, detail: nil)))
                case "WW_EMPTY":
                    continuation.resume(returning: ProbeReport(observation: .cannot(.protocolError, detail: "no result")))
                default:
                    continuation.resume(returning: ProbeEnvelopeParser.parse(result.value))
                }
            }
        }
    }

    /// Runs the script and maps AppleScript-level failures onto typed reasons.
    private func executeAppleScript(_ script: String) -> (value: String?, failure: (CannotReason, String?)?) {
        var error: NSDictionary?
        let appleScript = NSAppleScript(source: script)
        let result = appleScript?.executeAndReturnError(&error)

        if let error {
            let message = error[NSAppleScript.errorMessage] as? String ?? "Unknown AppleScript error"
            let code = error[NSAppleScript.errorNumber] as? Int

            if message.contains("Allow JavaScript from Apple Events") {
                return (nil, (.jsDisabled, nil))
            }
            if code == -1743 || message.localizedCaseInsensitiveContains("not authorized to send apple events") {
                Task { @MainActor in
                    _ = BrowserNavigationService.shared.ensureSafariAutomationPermissionForMonitoring()
                }
                return (nil, (.permission, nil))
            }
            // A stale tab/window reference between enumeration and use.
            if code == -1719 || code == -1728 {
                return (nil, (.noTab, "tab went away mid-check"))
            }
            return (nil, (.scriptError, message))
        }

        // `do JavaScript` does not only return strings: a bare number arrives as a
        // double and a thrown exception arrives as empty output with no error at all.
        guard let descriptor = result else {
            return (nil, (.protocolError, "no descriptor"))
        }
        guard let string = descriptor.stringValue else {
            return (nil, (.protocolError, "non-text result"))
        }
        return (string, nil)
    }
}
