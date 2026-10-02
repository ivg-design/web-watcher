import XCTest
import CoreGraphics
@testable import WebWatcher

/// Covers the Element Picker Assistant's wire protocol additions: `.tabSuspended`,
/// the scan/pick envelope fields, and lenient candidate decoding. Kept separate from
/// ObservationTests.swift so the pre-existing suite there is never touched.
final class ObservationEnvelopeTests: XCTestCase {

    // MARK: - tabSuspended

    func testTabBlankCodeMapsToTabSuspended() {
        let report = ProbeEnvelopeParser.parse(#"{"status":"MISS","code":"TAB_BLANK"}"#)
        XCTAssertEqual(report.observation.cannotReason, .tabSuspended)
    }

    func testTabSuspendedIsEnvironmentKindAndWorthEscalating() {
        XCTAssertEqual(CannotReason.tabSuspended.kind, .environment)
        XCTAssertTrue(CannotReason.tabSuspended.isWorthEscalating)
    }

    func testTabSuspendedCopyMatchesContract() {
        XCTAssertEqual(CannotReason.tabSuspended.shortStatus, "Tab unloaded by Safari")
        XCTAssertEqual(
            CannotReason.tabSuspended.remedy,
            "WebWatcher reloads it automatically. If this keeps happening, keep the page in a visible tab."
        )
    }

    // MARK: - Envelope scan/pick fields

    func testEnvelopeDecodesScanAndPickFields() {
        let json = #"""
        {"status":"OK","value":"2","title":"Feed | Rive Community","href":"https://community.rive.app/feed",
         "tabState":"live","visible":true,"note":"iframe","pickState":"picked",
         "candidates":[{"selector":"[data-testid=\"unread-notifications-count\"]","anchor":"button[data-testid=\"notifications-menu-popover-button\"]","strategy":"badgeText","value":"2","label":"2 · inside Notifications","tier":1,"score":9}],
         "pick":{"selector":"a[aria-label=\"Go to Messages\"]","strategy":"badgeText","value":"3","label":"3 · inside Go to Messages","tier":2,"score":7}}
        """#
        let report = ProbeEnvelopeParser.parse(json)

        XCTAssertEqual(report.candidates.count, 1)
        XCTAssertEqual(report.candidates.first?.selector, "[data-testid=\"unread-notifications-count\"]")
        XCTAssertEqual(report.candidates.first?.anchor, "button[data-testid=\"notifications-menu-popover-button\"]")
        XCTAssertEqual(report.candidates.first?.strategy, .badgeText)

        XCTAssertEqual(report.pick?.value, "3")
        XCTAssertEqual(report.pickState, .picked)
        XCTAssertEqual(report.note, "iframe")
        XCTAssertEqual(report.tabVisible, true)
    }

    func testEnvelopeWithoutNewFieldsLeavesThemAtDefaults() {
        let report = ProbeEnvelopeParser.parse(#"{"status":"ZERO"}"#)
        XCTAssertEqual(report.candidates, [])
        XCTAssertNil(report.pick)
        XCTAssertNil(report.pickState)
        XCTAssertNil(report.note)
        XCTAssertNil(report.tabVisible)
    }

    // MARK: - Candidate strategy decoding

    func testUnknownCandidateStrategyFallsBackToText() {
        let json = #"{"status":"OK","value":"x","candidates":[{"selector":"div.x","strategy":"somethingNew","label":"l","tier":5,"score":0}]}"#
        let report = ProbeEnvelopeParser.parse(json)
        XCTAssertEqual(report.candidates.first?.strategy, .text)
    }

    /// A rect that decodes from {x,y,w,h} and is absent entirely both resolve to a candidate;
    /// the missing one defaults its rect to .zero rather than failing the whole entry.
    func testCandidateRectDecodesOrDefaultsToZero() {
        let json = #"""
        {"status":"OK","value":"x","candidates":[
            {"selector":"a","strategy":"exists","label":"l1","tier":2,"score":1,"rect":{"x":1,"y":2,"w":3,"h":4}},
            {"selector":"b","strategy":"exists","label":"l2","tier":2,"score":1}
        ]}
        """#
        let report = ProbeEnvelopeParser.parse(json)
        XCTAssertEqual(report.candidates.count, 2)
        XCTAssertEqual(report.candidates[0].rect, CGRect(x: 1, y: 2, width: 3, height: 4))
        XCTAssertEqual(report.candidates[1].rect, .zero)
    }

    // MARK: - Lossy candidate decoding

    /// A malformed entry (missing the required `label`) must not sink the other
    /// candidates in the same envelope, and must not be mistaken for one of them.
    func testOneMalformedCandidateIsDroppedOthersSurvive() {
        let json = #"""
        {"status":"OK","value":"x","candidates":[
            {"selector":"a","strategy":"badgeText","label":"l1","tier":1,"score":5},
            {"selector":"b","strategy":"badgeText","tier":2},
            {"selector":"c","strategy":"badgeText","label":"l3","tier":3,"score":1}
        ]}
        """#
        let report = ProbeEnvelopeParser.parse(json)
        XCTAssertEqual(report.candidates.map { $0.selector }, ["a", "c"])
    }

    /// All-malformed still parses as an empty (not nil, not a parse failure) array.
    func testAllMalformedCandidatesYieldsEmptyArrayNotFailure() {
        let json = #"{"status":"OK","value":"x","candidates":[{"selector":"a"},{"strategy":"text"}]}"#
        let report = ProbeEnvelopeParser.parse(json)
        XCTAssertEqual(report.observation.observedValue, "x")
        XCTAssertEqual(report.candidates, [])
    }

    /// Regression: an interactive envelope has no `value`; it must never become a
    /// protocol error, or the assistant discards its own scan/pick results.
    func testInteractiveEnvelopesWithoutValueAreConclusive() {
        let scan = """
        {"status":"OK","candidates":[{"selector":"#a","strategy":"badgeText","label":"1","tier":1}],"tabState":"live","visible":true}
        """
        let r1 = ProbeEnvelopeParser.parse(scan)
        XCTAssertNil(r1.observation.cannotReason)
        XCTAssertEqual(r1.candidates.count, 1)

        let pick = """
        {"status":"OK","pickState":"waiting"}
        """
        let r2 = ProbeEnvelopeParser.parse(pick)
        XCTAssertNil(r2.observation.cannotReason)
        XCTAssertEqual(r2.pickState, .waiting)

        let bare = """
        {"status":"OK"}
        """
        XCTAssertEqual(ProbeEnvelopeParser.parse(bare).observation.cannotReason, .protocolError)
    }
}
