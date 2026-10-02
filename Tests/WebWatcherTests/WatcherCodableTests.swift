import XCTest
@testable import WebWatcher

/// Codable/migration coverage for the two fields `Watcher` gained: `strategy` and
/// `lastReloadAttempt`. Kept separate from ObservationTests.swift's existing
/// `WatcherMigrationTests`, which is left untouched.
final class WatcherCodableTests: XCTestCase {

    /// JSON written before this feature existed has neither key at all.
    func testLegacyJSONWithoutStrategyOrLastReloadAttemptDecodesWithNil() throws {
        let legacy = """
        {"id":"AE28EB85-DDEE-4A79-8B5A-E02318052247","name":"n","url":"u","selector":"s",
         "selectorType":"CSS Selector","watchType":"Badge/Number","interval":60,
         "isEnabled":true,"notificationSound":true}
        """
        let w = try JSONDecoder().decode(Watcher.self, from: Data(legacy.utf8))

        XCTAssertNil(w.strategy)
        XCTAssertNil(w.lastReloadAttempt)
    }

    /// 1.4.x/1.5.0 watchers.json in general — every other field the assistant did not
    /// touch must still be present after the round trip through the new decoder.
    func test1_4xJSONStillDecodesEveryOtherField() throws {
        let legacy = """
        {"id":"AE28EB85-DDEE-4A79-8B5A-E02318052247","name":"LinkedIn","url":"https://www.linkedin.com/feed/",
         "selector":"/html/body/div[5]","selectorType":"XPath","watchType":"Badge/Number","interval":300,
         "isEnabled":true,"notificationSound":true,"lastValue":"0","consecutiveErrors":4722}
        """
        let w = try JSONDecoder().decode(Watcher.self, from: Data(legacy.utf8))

        XCTAssertEqual(w.name, "LinkedIn")
        XCTAssertNil(w.strategy)
        XCTAssertNil(w.lastReloadAttempt)
    }

    func testRoundTripsWithAutoBadgeStrategyAndReloadTimestamp() throws {
        var w = Watcher(name: "n", url: "u", selector: "s", strategy: .autoBadge)
        w.lastReloadAttempt = Date()

        let data = try JSONEncoder().encode(w)
        let decoded = try JSONDecoder().decode(Watcher.self, from: data)

        XCTAssertEqual(decoded.strategy, .autoBadge)
        XCTAssertNotNil(decoded.lastReloadAttempt)
    }

    func testRoundTripsWithNilStrategy() throws {
        let w = Watcher(name: "n", url: "u", selector: "s")
        let data = try JSONEncoder().encode(w)
        let decoded = try JSONDecoder().decode(Watcher.self, from: data)

        XCTAssertNil(decoded.strategy)
        XCTAssertNil(decoded.lastReloadAttempt)
    }

    /// §3.3: canConfirmZero must be true for autoBadge even with no anchorSelector and
    /// no profile — the strategy itself is self-anchored.
    func testCanConfirmZeroForAutoBadgeWithoutAnchorSelector() {
        let w = Watcher(name: "n", url: "u", selector: "s", strategy: .autoBadge)
        XCTAssertNil(w.anchorSelector)
        XCTAssertNil(w.profileId)
        XCTAssertTrue(w.canConfirmZero)
    }

    func testCanConfirmZeroForAriaCountAndDocumentTitleWithoutAnchorSelector() {
        XCTAssertTrue(Watcher(name: "n", url: "u", selector: "s", strategy: .ariaCount).canConfirmZero)
        XCTAssertTrue(Watcher(name: "n", url: "u", selector: "s", strategy: .documentTitle).canConfirmZero)
    }

    func testCanConfirmZeroFalseForManualWatcherWithNoAnchorOrProfileOrStrategy() {
        let w = Watcher(name: "n", url: "u", selector: "s")
        XCTAssertFalse(w.canConfirmZero)
    }

    func testCanConfirmZeroTrueForAnchoredBadgeWithAnAnchorSelector() {
        var w = Watcher(name: "n", url: "u", selector: "s", anchorSelector: "button.bell", strategy: .anchoredBadge)
        XCTAssertTrue(w.canConfirmZero)
        w.anchorSelector = nil
        XCTAssertFalse(w.canConfirmZero) // anchoredBadge alone, with no anchor, cannot confirm
    }
}
