import XCTest
@testable import WebWatcher

/// Scripted `ElementProbing` stand-in for `ElementPickerModel` tests — no Safari,
/// no AppleScript. Each `xResults` array is played back by call index (clamped to
/// the last entry), so a single scripted "OK" response can stand in for however
/// many retries a test's flow ends up making.
@MainActor
private final class FakeElementProbing: ElementProbing {
    var scanResults: [ProbeReport] = []
    var beginPickResults: [ProbeReport] = []
    var pollPickResults: [ProbeReport] = []
    var locateResults: [ProbeReport] = []
    var pickConfirmResults: [ProbeReport] = []
    /// Lets a test hold `pickConfirm` open long enough to race `cancel()`/`back(to:)`
    /// against `ElementPickerModel.confirmSelection()`'s in-flight continuation.
    var pickConfirmDelayNanoseconds: UInt64 = 0
    var reloadTabResult = true
    var openBackgroundTabResult = true
    var highlightResult = true

    private(set) var scanCallCount = 0
    private(set) var beginPickCallCount = 0
    private(set) var pollPickCallCount = 0
    private(set) var endPickCallCount = 0
    private(set) var reloadTabCallCount = 0
    private(set) var openBackgroundTabCallCount = 0
    private(set) var locateCallCount = 0
    private(set) var pickConfirmCallCount = 0
    private(set) var highlightedSelectors: [String] = []

    func scan(_ watcher: Watcher, profile: SiteProfile?) async -> ProbeReport {
        let report = playback(scanResults, at: scanCallCount) ?? ProbeReport(observation: .cannot(.protocolError, detail: "no fixture"))
        scanCallCount += 1
        return report
    }

    func beginPick(_ watcher: Watcher, profile: SiteProfile?) async -> ProbeReport {
        let report = playback(beginPickResults, at: beginPickCallCount) ?? ProbeReport(observation: .cannot(.protocolError, detail: "no fixture"))
        beginPickCallCount += 1
        return report
    }

    func pollPick(_ watcher: Watcher, profile: SiteProfile?) async -> ProbeReport {
        // No fixture left → stay "waiting" so a test that never scripts an ending
        // relies on `cancel()`/timeout rather than looping over stale data.
        let report = playback(pollPickResults, at: pollPickCallCount) ?? ProbeReport(observation: .zero, pickState: .waiting)
        pollPickCallCount += 1
        return report
    }

    func endPick(_ watcher: Watcher, profile: SiteProfile?) async {
        endPickCallCount += 1
    }

    func highlight(_ selector: String, watcher: Watcher, profile: SiteProfile?) async -> Bool {
        highlightedSelectors.append(selector)
        return highlightResult
    }

    func reloadTab(for watcher: Watcher, profile: SiteProfile?) async -> Bool {
        reloadTabCallCount += 1
        return reloadTabResult
    }

    func openBackgroundTab(for watcher: Watcher, profile: SiteProfile?) async -> Bool {
        openBackgroundTabCallCount += 1
        return openBackgroundTabResult
    }

    func diagnose(_ watcher: Watcher, profile: SiteProfile?) async -> ProbeReport {
        ProbeReport(observation: .cannot(.protocolError, detail: "not used"))
    }

    func locate(_ watcher: Watcher, profile: SiteProfile?) async -> ProbeReport {
        let report = playback(locateResults, at: locateCallCount) ?? ProbeReport(observation: .cannot(.protocolError, detail: "no fixture"))
        locateCallCount += 1
        return report
    }

    func pickConfirm(_ watcher: Watcher, profile: SiteProfile?) async -> ProbeReport {
        if pickConfirmDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: pickConfirmDelayNanoseconds)
        }
        let report = playback(pickConfirmResults, at: pickConfirmCallCount) ?? ProbeReport(observation: .zero, pickState: .absent)
        pickConfirmCallCount += 1
        return report
    }

    private func playback(_ results: [ProbeReport], at index: Int) -> ProbeReport? {
        guard !results.isEmpty else { return nil }
        return results[min(index, results.count - 1)]
    }
}

@MainActor
final class ElementPickerModelTests: XCTestCase {

    private func candidate(
        selector: String = "[data-testid=x]",
        anchor: String? = "button.bell",
        strategy: CandidateStrategy = .badgeText,
        value: String? = "2",
        label: String = "2 · inside Notifications"
    ) -> ElementCandidate {
        ElementCandidate(
            selector: selector, anchor: anchor, strategy: strategy, value: value,
            label: label, detail: "detail", technical: "technical", tier: 1, score: 10
        )
    }

    /// Polls a condition on `@Published` model state — there's no async return to
    /// await directly since the model's methods fire-and-track via `Task`.
    ///
    /// Always sleeps at least once before the first check: the caller just fired
    /// a `Task { … }` (from `scan()`/`beginPick()`/etc.) that hasn't had a chance
    /// to run yet, and its starting condition (e.g. `phase == .idle` before any
    /// scan, or `.applied` left over from a previous choice) can already match
    /// the awaited one — checking synchronously would then return immediately
    /// without the operation under test ever having run.
    private func waitUntil(
        timeout: TimeInterval = 2.0,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ condition: () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            try? await Task.sleep(nanoseconds: 5_000_000)
            if condition() { return }
        } while Date() < deadline
        XCTFail("Timed out waiting for condition", file: file, line: line)
    }

    // MARK: - scan()

    func testScanHappyPath() async {
        let fake = FakeElementProbing()
        let c = candidate()
        fake.scanResults = [
            ProbeReport(observation: .zero, candidates: [c], pageTitle: "Feed", matchedURL: "https://example.com/feed", tabVisible: true)
        ]
        let model = ElementPickerModel(probe: fake)
        model.draft = { Watcher(url: "https://example.com/feed") }

        model.scan()
        await waitUntil { model.phase == .idle }

        XCTAssertEqual(model.candidates, [c])
        XCTAssertEqual(model.scannedTitle, "Feed")
        XCTAssertEqual(model.scannedURL, "https://example.com/feed")
        XCTAssertEqual(model.tabVisible, true)
        XCTAssertTrue(model.showList)
        XCTAssertNil(model.statusLine)
    }

    func testScanWithNoCandidatesShowsExactMessage() async {
        let fake = FakeElementProbing()
        fake.scanResults = [
            ProbeReport(observation: .zero, candidates: [], pageTitle: "Feed", matchedURL: "https://example.com/feed", tabVisible: true)
        ]
        let model = ElementPickerModel(probe: fake)
        model.draft = { Watcher(url: "https://example.com/feed") }

        model.scan()
        await waitUntil { model.phase == .idle }

        XCTAssertEqual(
            model.statusLine,
            "No badges or counters found on this page. Scan looks for notification-style counts — for text, prices or “element exists” watchers, use Pick in Safari."
        )
    }

    func testScanTabSuspendedReloadsThenRetries() async {
        let fake = FakeElementProbing()
        fake.scanResults = [
            ProbeReport(observation: .cannot(.tabSuspended, detail: nil)),
            ProbeReport(observation: .zero, candidates: [], pageTitle: "Feed", matchedURL: "https://example.com/feed", tabVisible: true)
        ]
        let model = ElementPickerModel(probe: fake)
        model.draft = { Watcher(url: "https://example.com/feed") }

        model.scan()
        await waitUntil { model.phase == .idle }

        XCTAssertEqual(fake.reloadTabCallCount, 1)
        XCTAssertEqual(fake.scanCallCount, 2)
        XCTAssertTrue(model.showList)
    }

    func testScanNoTabOpensThenRetries() async {
        let fake = FakeElementProbing()
        fake.scanResults = [
            ProbeReport(observation: .cannot(.noTab, detail: nil)),
            ProbeReport(observation: .zero, candidates: [], pageTitle: "Feed", matchedURL: "https://example.com/feed", tabVisible: true)
        ]
        let model = ElementPickerModel(probe: fake)
        model.draft = { Watcher(url: "https://example.com/feed", autoOpenEnabled: true) }

        model.scan()
        // The "no tab" recovery sleeps a real 4s before retrying (§6.2) — not
        // injectable, so this test simply waits long enough for it.
        await waitUntil(timeout: 6.0) { model.phase == .idle }

        XCTAssertEqual(fake.openBackgroundTabCallCount, 1)
        XCTAssertEqual(fake.scanCallCount, 2)
        XCTAssertTrue(model.showList)
    }

    func testScanNoTabWithoutAutoOpenShowsHostMessage() async {
        let fake = FakeElementProbing()
        fake.scanResults = [ProbeReport(observation: .cannot(.noTab, detail: nil))]
        let model = ElementPickerModel(probe: fake)
        model.draft = { Watcher(url: "https://example.com/feed", autoOpenEnabled: false) }

        model.scan()
        await waitUntil { model.phase == .idle }

        XCTAssertEqual(model.statusLine, "Open example.com in Safari first.")
        XCTAssertEqual(fake.openBackgroundTabCallCount, 0)
    }

    // MARK: - beginPick() / pick flow

    func testPickHappyPathCallsOnChooseAndEndPick() async {
        let fake = FakeElementProbing()
        let c = candidate()
        fake.beginPickResults = [ProbeReport(observation: .zero, pickState: .waiting)]
        fake.pollPickResults = [ProbeReport(observation: .zero, pick: c, pickState: .picked)]

        let model = ElementPickerModel(probe: fake, pollInterval: 0.02)
        model.draft = { Watcher(url: "https://example.com/feed") }

        var chosen: ElementCandidate?
        model.onChoose = { candidate, _, _ in chosen = candidate }

        model.beginPick()
        await waitUntil { model.phase == .applied }

        XCTAssertEqual(chosen, c)
        XCTAssertEqual(model.chosen, c)
        XCTAssertEqual(model.chosenVia, .pick)
        XCTAssertEqual(fake.endPickCallCount, 1)
    }

    func testPickTimeout() async {
        let fake = FakeElementProbing()
        fake.beginPickResults = [ProbeReport(observation: .zero, pickState: .waiting)]
        // No pollPickResults scripted → the fake keeps returning "waiting" forever,
        // so the only way out is the model's own timeout.
        let model = ElementPickerModel(probe: fake, pickTimeout: 0.2, pollInterval: 0.05)
        model.draft = { Watcher(url: "https://example.com/feed") }

        model.beginPick()
        await waitUntil(timeout: 3.0) { model.phase == .idle }

        XCTAssertEqual(model.statusLine, "No click after 90 seconds — try again, or use Scan page instead.")
        XCTAssertGreaterThanOrEqual(fake.endPickCallCount, 1)
    }

    func testCancelDuringPickCallsEndPick() async {
        let fake = FakeElementProbing()
        fake.beginPickResults = [ProbeReport(observation: .zero, pickState: .waiting)]
        let model = ElementPickerModel(probe: fake, pollInterval: 0.02)
        model.draft = { Watcher(url: "https://example.com/feed") }

        model.beginPick()
        await waitUntil { model.phase == .picking }

        model.cancel()
        await waitUntil { fake.endPickCallCount > 0 }

        XCTAssertEqual(model.phase, .idle)
        XCTAssertEqual(model.statusLine, "Cancelled.")
    }

    func testIframeNoteShowsCopyAndStaysPicking() async {
        let fake = FakeElementProbing()
        fake.beginPickResults = [ProbeReport(observation: .zero, pickState: .waiting)]
        fake.pollPickResults = [ProbeReport(observation: .zero, note: "iframe")]
        let model = ElementPickerModel(probe: fake, pollInterval: 0.02)
        model.draft = { Watcher(url: "https://example.com/feed") }

        model.beginPick()
        await waitUntil {
            model.statusLine == "That element is inside an embedded frame WebWatcher can't reach — pick something outside it."
        }

        XCTAssertEqual(model.phase, .picking)

        model.cancel()
        await waitUntil { fake.endPickCallCount > 0 }
    }

    // MARK: - change()

    func testChangeSemanticsForScanVsPick() async {
        let fake = FakeElementProbing()
        let model = ElementPickerModel(probe: fake, pollInterval: 0.02)
        model.draft = { Watcher(url: "https://example.com/feed") }

        // A candidate chosen from the scan list: "Change" re-opens the list.
        model.choose(candidate())
        XCTAssertEqual(model.chosenVia, .scan)
        XCTAssertFalse(model.showList)

        model.change()
        XCTAssertTrue(model.showList)

        // A candidate chosen via "Pick in Safari": "Change" starts a new pick.
        let picked = candidate(selector: "#picked")
        fake.beginPickResults = [ProbeReport(observation: .zero, pickState: .waiting)]
        fake.pollPickResults = [ProbeReport(observation: .zero, pick: picked, pickState: .picked)]

        model.beginPick()
        // `phase` is already `.applied` from the scan choice above, so waiting on
        // it here would return immediately without the pick round-trip ever
        // running. Wait on the property this assertion actually checks instead.
        await waitUntil { model.chosenVia == .pick }
        XCTAssertEqual(model.phase, .applied)

        model.change()
        await waitUntil { fake.beginPickCallCount == 2 }
    }

    // MARK: - Guided assistant: locate() (§3.7, amended §9.2/§9.4)

    func testLocateFoundAdvancesToElementAndScansOnce() async {
        let fake = FakeElementProbing()
        let c = candidate()
        fake.locateResults = [
            ProbeReport(observation: .value(""), pageTitle: "Feed", matchedURL: "https://example.com/feed", tabVisible: true)
        ]
        fake.scanResults = [
            ProbeReport(observation: .zero, candidates: [c], pageTitle: "Feed", matchedURL: "https://example.com/feed", tabVisible: true)
        ]
        let model = ElementPickerModel(probe: fake)
        model.draft = { Watcher(url: "https://example.com/feed") }

        model.locate()
        await waitUntil { model.step == .element }

        guard case .found(let title, let url, let visible) = model.tab else {
            return XCTFail("expected .found, got \(model.tab)")
        }
        XCTAssertEqual(title, "Feed")
        XCTAssertEqual(url, "https://example.com/feed")
        XCTAssertTrue(visible)
        await waitUntil { model.candidates == [c] }
        XCTAssertEqual(fake.scanCallCount, 1)

        // Re-locating the SAME url must not scan a second time (§3.7: "auto-scan once per URL").
        model.locate()
        await waitUntil { fake.locateCallCount == 2 }
        XCTAssertEqual(fake.scanCallCount, 1)
    }

    func testLocateNotOpenThenOpenTabThenFound() async {
        let fake = FakeElementProbing()
        fake.locateResults = [
            ProbeReport(observation: .cannot(.noTab, detail: nil)),
            ProbeReport(observation: .value(""), pageTitle: "Feed", matchedURL: "https://example.com/feed", tabVisible: true)
        ]
        fake.scanResults = [
            ProbeReport(observation: .zero, candidates: [], pageTitle: "Feed", matchedURL: "https://example.com/feed", tabVisible: true)
        ]
        let model = ElementPickerModel(probe: fake)
        model.draft = { Watcher(url: "https://example.com/feed") }

        model.locate()
        await waitUntil { model.tab == .notOpen }

        model.openTab()
        // `openTab()` sleeps a real 4s before re-locating (mirrors the old .noTab recovery).
        await waitUntil(timeout: 6.0) { model.step == .element }

        XCTAssertEqual(fake.openBackgroundTabCallCount, 1)
        XCTAssertEqual(fake.locateCallCount, 2)
    }

    func testLocateLoadingRetriesThenFound() async {
        let fake = FakeElementProbing()
        var loading = ProbeReport(observation: .value(""))
        loading.isLoading = true
        fake.locateResults = [
            loading,
            ProbeReport(observation: .value(""), pageTitle: "Feed", matchedURL: "https://example.com/feed", tabVisible: true)
        ]
        fake.scanResults = [
            ProbeReport(observation: .zero, candidates: [], pageTitle: "Feed", matchedURL: "https://example.com/feed", tabVisible: true)
        ]
        let model = ElementPickerModel(probe: fake)
        model.draft = { Watcher(url: "https://example.com/feed") }

        model.locate()
        // The loading→checking retry sleeps a real 1s before re-locating.
        await waitUntil(timeout: 3.0) { model.step == .element }

        XCTAssertEqual(fake.locateCallCount, 2)
        guard case .found = model.tab else {
            return XCTFail("expected .found, got \(model.tab)")
        }
    }

    // MARK: - Guided assistant: useCandidate() / chooseStrategy() (§3.3/§9.4)

    func testUseCandidateWithMultipleChoicesSetsPendingChoice() {
        let fake = FakeElementProbing()
        let model = ElementPickerModel(probe: fake)
        model.draft = { Watcher(url: "https://example.com/feed") }

        // .badgeText has two watch choices ("Track the number" / "Anything changes inside"),
        // so a single candidate must not auto-commit.
        let c = candidate(strategy: .badgeText)
        model.useCandidate(c)

        XCTAssertEqual(model.pendingChoice, c)
        XCTAssertEqual(model.choices.count, 2)
        XCTAssertNil(model.chosen)
    }

    func testChooseStrategySwitchesCandidateStrategyAndCommits() {
        let fake = FakeElementProbing()
        let model = ElementPickerModel(probe: fake)
        model.draft = { Watcher(url: "https://example.com/feed") }

        var chosenViaOnChoose: ElementCandidate?
        model.onChoose = { c, _, _ in chosenViaOnChoose = c }

        let c = candidate(strategy: .badgeText)
        model.useCandidate(c)
        XCTAssertEqual(model.choices.count, 2)

        model.chooseStrategy(.subtree)

        XCTAssertTrue(model.choices.isEmpty)
        XCTAssertNil(model.pendingChoice)
        XCTAssertEqual(model.chosen?.strategy, .subtree)
        XCTAssertEqual(model.chosen?.selector, c.selector)
        XCTAssertEqual(chosenViaOnChoose?.strategy, .subtree)
        XCTAssertEqual(model.step, .confirm)
    }

    // MARK: - Guided assistant: pick v2 selected/confirm (§9.2/§9.4)

    func testPickSelectedSetsStatusLineAndSelection() async {
        let fake = FakeElementProbing()
        let c = candidate(selector: "#picked", label: "Bell icon")
        fake.beginPickResults = [ProbeReport(observation: .zero, pickState: .waiting)]
        fake.pollPickResults = [ProbeReport(observation: .zero, pick: c, pickState: .selected)]

        let model = ElementPickerModel(probe: fake, pollInterval: 0.02)
        model.draft = { Watcher(url: "https://example.com/feed") }

        model.beginPick()
        await waitUntil { model.selection == c }

        XCTAssertEqual(model.statusLine, "Selected: Bell icon — press ⏎ in Safari, or click Use this here.")
        XCTAssertEqual(model.phase, .picking)

        model.cancel()
        await waitUntil { fake.endPickCallCount > 0 }
    }

    func testConfirmSelectionCommitsTheChoice() async {
        let fake = FakeElementProbing()
        // .subtree has exactly one watch choice, so `useCandidate` commits it directly —
        // the same path `confirmSelection` funnels into.
        let c = candidate(selector: "#picked", strategy: .subtree, value: nil, label: "Bell icon")
        fake.beginPickResults = [ProbeReport(observation: .zero, pickState: .waiting)]
        fake.pollPickResults = [ProbeReport(observation: .zero, pick: c, pickState: .selected)]
        fake.pickConfirmResults = [ProbeReport(observation: .zero, pick: c, pickState: .picked)]

        let model = ElementPickerModel(probe: fake, pollInterval: 0.02)
        model.draft = { Watcher(url: "https://example.com/feed") }

        var chosenViaOnChoose: ElementCandidate?
        model.onChoose = { c, _, _ in chosenViaOnChoose = c }

        model.beginPick()
        await waitUntil { model.selection == c }

        model.confirmSelection()
        await waitUntil { model.chosen == c }

        XCTAssertEqual(fake.pickConfirmCallCount, 1)
        XCTAssertNil(model.selection)
        XCTAssertEqual(model.step, .confirm)
        XCTAssertEqual(chosenViaOnChoose, c)
        // Confirming through the app-side "Use this" button must tag the source as
        // `.pick`, not the scan-list default `.scan` — WatcherEditorView keys its
        // pick-specific grace delay and error copy off this.
        XCTAssertEqual(model.chosenVia, .pick)
    }

    /// Same as above, but through a candidate with more than one watch choice, so
    /// `confirmSelection` → `useCandidate` takes the `chooseStrategy`-mediated branch
    /// instead of committing directly. `via` must still survive to `choose(_:via:)`.
    func testConfirmSelectionWithMultipleChoicesPreservesPickSource() async {
        let fake = FakeElementProbing()
        let c = candidate(selector: "#picked", strategy: .badgeText, value: "2", label: "2 · inside Notifications")
        fake.beginPickResults = [ProbeReport(observation: .zero, pickState: .waiting)]
        fake.pollPickResults = [ProbeReport(observation: .zero, pick: c, pickState: .selected)]
        fake.pickConfirmResults = [ProbeReport(observation: .zero, pick: c, pickState: .picked)]

        let model = ElementPickerModel(probe: fake, pollInterval: 0.02)
        model.draft = { Watcher(url: "https://example.com/feed") }

        model.beginPick()
        await waitUntil { model.selection == c }

        model.confirmSelection()
        await waitUntil { !model.choices.isEmpty }

        XCTAssertNotNil(model.pendingChoice)
        model.chooseStrategy(.subtree)

        await waitUntil { model.chosen != nil }
        XCTAssertEqual(model.chosen?.strategy, .subtree)
        XCTAssertEqual(model.chosenVia, .pick)
    }

    /// If the user navigates away (e.g. taps a completed step header, which calls
    /// `back(to:)` → `cancel()` while `phase == .picking`) before the `pickConfirm`
    /// round trip returns, the stale result must not resurrect `.confirm` under the
    /// user's feet — `cancel()` cancels `confirmSelection`'s own tracked task, and
    /// its continuation bails out on `Task.isCancelled` instead of calling `useCandidate`.
    func testCancelDuringConfirmSelectionDiscardsStaleResult() async {
        let fake = FakeElementProbing()
        let c = candidate(selector: "#picked", strategy: .subtree, value: nil, label: "Bell icon")
        fake.beginPickResults = [ProbeReport(observation: .zero, pickState: .waiting)]
        fake.pollPickResults = [ProbeReport(observation: .zero, pick: c, pickState: .selected)]
        fake.pickConfirmResults = [ProbeReport(observation: .zero, pick: c, pickState: .picked)]
        fake.pickConfirmDelayNanoseconds = 200_000_000 // 200ms — plenty of time to cancel first

        let model = ElementPickerModel(probe: fake, pollInterval: 0.02)
        model.draft = { Watcher(url: "https://example.com/feed") }

        model.beginPick()
        await waitUntil { model.selection == c }

        model.confirmSelection()
        // Navigate away while the confirm round trip is still in flight.
        model.back(to: .page)

        XCTAssertEqual(model.step, .page)
        XCTAssertEqual(model.phase, .idle)

        // Give the delayed pickConfirm plenty of time to resolve and see whether its
        // continuation (wrongly) resurrects the confirm step.
        try? await Task.sleep(nanoseconds: 400_000_000)

        XCTAssertNil(model.chosen, "a stale confirm result must not commit a choice after navigation")
        XCTAssertEqual(model.step, .page, "a stale confirm result must not move the wizard back to .confirm")
    }

    // MARK: - Guided assistant: back(to:) (§9.4)

    func testBackToStepNavigatesAndClearsPendingChoice() {
        let fake = FakeElementProbing()
        let model = ElementPickerModel(probe: fake)
        model.draft = { Watcher(url: "https://example.com/feed") }

        model.useCandidate(candidate(strategy: .badgeText))
        XCTAssertFalse(model.choices.isEmpty)
        XCTAssertNotNil(model.pendingChoice)

        model.back(to: .page)

        XCTAssertEqual(model.step, .page)
        XCTAssertTrue(model.choices.isEmpty)
        XCTAssertNil(model.pendingChoice)
    }

    /// A tab Safari keeps unloading must not spin `locate()` forever: one reload, then
    /// a terminal `.failed` state (mirrors scan()'s single-retry rule).
    func testLocateTabSuspendedReloadsOnceThenFails() async {
        let fake = FakeElementProbing()
        fake.locateResults = [
            ProbeReport(observation: .cannot(.tabSuspended, detail: nil)),
            ProbeReport(observation: .cannot(.tabSuspended, detail: nil)),
            ProbeReport(observation: .cannot(.tabSuspended, detail: nil))
        ]
        let model = ElementPickerModel(probe: fake)
        model.draft = { Watcher(url: "https://example.com/feed") }

        model.locate()
        await waitUntil {
            if case .failed = model.tab { return true }
            return false
        }

        XCTAssertEqual(fake.reloadTabCallCount, 1)
        XCTAssertEqual(model.step, .page)
        if case .failed(let msg) = model.tab {
            XCTAssertTrue(msg.contains("unloading"))
        } else {
            XCTFail("expected .failed, got \(model.tab)")
        }
    }
}
