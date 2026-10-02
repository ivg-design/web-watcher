import XCTest
@testable import WebWatcher

/// Live verification through the real Swift stack (DESIGN-V2.md §7).
///
/// F1 shipped because the previous "live verification" ran the injected JavaScript
/// via `osascript` directly and never went through `ProbeEnvelopeParser` /
/// `ElementProbing` — so a parser bug that silently discarded every interactive
/// result (scan/pick) never showed up. These tests instead call `SafariScraper.shared`
/// itself, exactly the path `ElementPickerModel` uses, so a regression there fails a
/// test instead of shipping quietly.
///
/// Requires a `community.rive.app/feed` tab already open in Safari, with Safari
/// automation permission already granted to whatever process runs `swift test`
/// (xctest inherits the terminal's grant — verified working for `ScriptDumpTests`'
/// sibling live-verification protocol). Every test is gated behind `WW_LIVE=1` so an
/// ordinary `swift test` never touches the user's Safari or steals focus from them.
final class LiveSafariTests: XCTestCase {

    private let feedURL = "https://community.rive.app/feed"

    /// The bell icon's own selector doubles as its anchor for the subtree check
    /// below — it is itself the always-present container being watched (§7's own
    /// wording leaves the anchor choice to the implementer; the element that never
    /// disappears is the element itself, so there is no separate anchor to pick).
    private let bellSelector = #"button[data-testid="notifications-menu-popover-button"]"#

    /// A watcher pointed at the already-open feed tab. Only the fields each test
    /// actually needs are non-default — `locate`/`scan` don't care about
    /// selector/watchType at all; `check` and the pick tests set what they use.
    private func feedWatcher(
        watchType: WatchType = .badgeNumber,
        selector: String = "",
        anchorSelector: String? = nil
    ) -> Watcher {
        Watcher(name: "Live Rive Feed", url: feedURL, selector: selector, watchType: watchType, anchorSelector: anchorSelector)
    }

    // MARK: - locate (G1 step 1 "Page")

    func testLocateFindsTheOpenFeedTab() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["WW_LIVE"] == "1")

        let report = await SafariScraper.shared.locate(feedWatcher(), profile: nil)

        XCTAssertNil(report.observation.cannotReason, "locate could not observe: \(String(describing: report.observation.cannotReason))")
        let matchedURL = try XCTUnwrap(report.matchedURL, "locate returned no matchedURL")
        XCTAssertTrue(matchedURL.hasPrefix("https://community.rive.app"), "matchedURL was \(matchedURL)")
        XCTAssertEqual(report.isLoading, false)
    }

    // MARK: - scan (G1 step 2 "Element", automatic scan)

    func testScanReturnsCandidatesOnTheFeedPage() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["WW_LIVE"] == "1")

        let report = await SafariScraper.shared.scan(feedWatcher(), profile: nil)

        XCTAssertFalse(report.candidates.isEmpty, "expected at least one scan candidate on the feed page")
    }

    // MARK: - subtree check (G2 "Anything Changes Inside")

    /// A `.subtreeChange` check on the bell must return the `"<descendantCount>:<hash
    /// hex>"` shape the fingerprint branch produces (§3.5/9.2) — never a bare number
    /// and never empty.
    func testSubtreeCheckOnTheNotificationsBell() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["WW_LIVE"] == "1")

        let watcher = feedWatcher(watchType: .subtreeChange, selector: bellSelector, anchorSelector: bellSelector)
        let result = await SafariScraper.shared.check(watcher, profile: nil)

        let value = try XCTUnwrap(result.observation.observedValue, "no conclusive value; observation was \(result.observation)")
        let fingerprintPattern = #"^\d+:[0-9a-f]{1,8}$"#
        XCTAssertNotNil(value.range(of: fingerprintPattern, options: .regularExpression), "value \"\(value)\" did not match \(fingerprintPattern)")
    }

    // MARK: - pick session lifecycle (G1 "Pick in Safari")

    /// `beginPick` installs the overlay (`.waiting`); `pickConfirm` — the app-side
    /// "Use this element" action and the CSP-proof path per §9.2 — must report
    /// `.waiting` right back when nothing has been clicked yet, never `.picked`
    /// (which would mean confirming a selection that was never made) nor `.absent`
    /// (which would mean the session it just started already vanished).
    func testPickSessionLifecycle() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["WW_LIVE"] == "1")

        let watcher = feedWatcher(selector: bellSelector, anchorSelector: bellSelector)

        let begin = await SafariScraper.shared.beginPick(watcher, profile: nil)
        XCTAssertEqual(begin.pickState, .waiting, "beginPick observation: \(begin.observation)")

        let confirm = await SafariScraper.shared.pickConfirm(watcher, profile: nil)
        XCTAssertEqual(confirm.pickState, .waiting, "pickConfirm with nothing selected returned \(String(describing: confirm.pickState))")

        await SafariScraper.shared.endPick(watcher, profile: nil)
    }

    // MARK: - highlight

    func testHighlightFindsTheBell() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["WW_LIVE"] == "1")

        let watcher = feedWatcher(selector: bellSelector, anchorSelector: bellSelector)
        let found = await SafariScraper.shared.highlight(bellSelector, watcher: watcher, profile: nil)

        XCTAssertTrue(found, "highlight could not find the notifications bell")
    }
}
