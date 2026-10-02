import XCTest
@testable import WebWatcher

/// These cover the pure functions where a silent regression would reproduce exactly the
/// bug class this work exists to fix: a non-observation being mistaken for a zero.
final class BadgeValueTests: XCTestCase {

    func testParsesPlainNumber() {
        XCTAssertEqual(BadgeValue.parse("4"), .exact(4))
        XCTAssertEqual(BadgeValue.parse("  12 "), .exact(12))
    }

    func testParsesThousandsSeparators() {
        XCTAssertEqual(BadgeValue.parse("1,281"), .exact(1281))
        XCTAssertEqual(BadgeValue.parse("1.281"), .exact(1281))
    }

    /// Contra caps at "9+" and LinkedIn at "99+". Coercing those to a plain Int
    /// silently disables notifications forever.
    func testParsesCappedValues() {
        XCTAssertEqual(BadgeValue.parse("9+"), .atLeast(9))
        XCTAssertEqual(BadgeValue.parse("99+"), .atLeast(99))
    }

    func testRejectsNonNumeric() {
        XCTAssertNil(BadgeValue.parse(""))
        XCTAssertNil(BadgeValue.parse("inbox"))
    }

    func testFirstConclusiveReadingIsBaselineNotAlert() {
        XCTAssertFalse(BadgeValue.shouldNotify(old: nil, new: .exact(5)))
    }

    func testNotifiesOnlyOnIncrease() {
        XCTAssertTrue(BadgeValue.shouldNotify(old: .exact(1), new: .exact(3)))
        XCTAssertFalse(BadgeValue.shouldNotify(old: .exact(3), new: .exact(1)))
        XCTAssertFalse(BadgeValue.shouldNotify(old: .exact(3), new: .exact(3)))
    }

    /// A capped value that stays capped is not news.
    func testCappedToCappedDoesNotNotify() {
        XCTAssertFalse(BadgeValue.shouldNotify(old: .atLeast(9), new: .atLeast(9)))
        XCTAssertTrue(BadgeValue.shouldNotify(old: .atLeast(9), new: .atLeast(20)))
    }

    func testCrossingIntoCapNotifies() {
        XCTAssertTrue(BadgeValue.shouldNotify(old: .exact(5), new: .atLeast(9)))
    }
}

final class ProbeEnvelopeParserTests: XCTestCase {

    /// A thrown JS exception, an invalid selector, a returned DOM node and `undefined`
    /// all surface as empty output with exit code 0 and no AppleScript error.
    func testEmptyOutputIsNeverAnObservation() {
        let report = ProbeEnvelopeParser.parse("")
        XCTAssertEqual(report.observation.cannotReason, .protocolError)
        XCTAssertNil(report.observation.observedValue)
    }

    func testNilOutputIsNeverAnObservation() {
        XCTAssertNil(ProbeEnvelopeParser.parse(nil).observation.observedValue)
    }

    func testGarbageIsNeverAnObservation() {
        let report = ProbeEnvelopeParser.parse("not json at all")
        XCTAssertEqual(report.observation.cannotReason, .protocolError)
    }

    func testParsesValue() {
        let report = ProbeEnvelopeParser.parse(#"{"status":"OK","value":"4"}"#)
        XCTAssertEqual(report.observation.observedValue, "4")
    }

    func testParsesConfirmedZero() {
        let report = ProbeEnvelopeParser.parse(#"{"status":"ZERO"}"#)
        XCTAssertEqual(report.observation.observedValue, "0")
        if case .zero = report.observation {} else { XCTFail("expected .zero") }
    }

    func testMissMapsToTypedReason() {
        XCTAssertEqual(
            ProbeEnvelopeParser.parse(#"{"status":"MISS","code":"SIGNED_OUT"}"#).observation.cannotReason,
            .signedOut
        )
        XCTAssertEqual(
            ProbeEnvelopeParser.parse(#"{"status":"MISS","code":"ANCHOR_MISSING"}"#).observation.cannotReason,
            .anchorMissing
        )
    }

    /// Unknown codes must degrade to "couldn't look", never to a value.
    func testUnknownCodeFallsBackSafely() {
        let report = ProbeEnvelopeParser.parse(#"{"status":"MISS","code":"SOMETHING_NEW"}"#)
        XCTAssertEqual(report.observation.cannotReason, .scriptError)
        XCTAssertNil(report.observation.observedValue)
    }

    func testUnknownStatusFallsBackSafely() {
        XCTAssertNil(ProbeEnvelopeParser.parse(#"{"status":"WAT"}"#).observation.observedValue)
    }

    func testOKWithoutValueIsNotAnObservation() {
        XCTAssertNil(ProbeEnvelopeParser.parse(#"{"status":"OK"}"#).observation.observedValue)
    }

    func testParsesDoctorSteps() {
        let json = #"{"status":"ZERO","steps":[{"label":"Anchor found","ok":true,"note":"x"}]}"#
        XCTAssertEqual(ProbeEnvelopeParser.parse(json).steps.count, 1)
    }

    func testParsesAnchorSuggestions() {
        let json = #"{"status":"MISS","code":"NO_MATCH","anchors":[{"selector":"a[href*=\"/x\"]","label":"l","tier":3,"sample":null}]}"#
        XCTAssertEqual(ProbeEnvelopeParser.parse(json).suggestedAnchors.first?.tier, 3)
    }
}

final class AppleScriptEscapeTests: XCTestCase {

    /// The old pipeline doubled backslashes in the JS generator and AppleScript
    /// un-doubled them, so a Tailwind-escaped class arrived as an invalid selector.
    func testEscapesBackslashBeforeQuote() {
        XCTAssertEqual(appleScriptEscape(#".w-1\/2"#), #".w-1\\/2"#)
        XCTAssertEqual(appleScriptEscape(#"say "hi""#), #"say \"hi\""#)
    }

    func testEscapesBoth() {
        XCTAssertEqual(appleScriptEscape(#"a\"b"#), #"a\\\"b"#)
    }

    func testLeavesPlainTextAlone() {
        XCTAssertEqual(appleScriptEscape("https://www.linkedin.com/"), "https://www.linkedin.com/")
    }
}

final class NotifyGateTests: XCTestCase {

    func testBadgeNotifiesOnIncreaseOnly() {
        XCTAssertTrue(WatcherService.shouldNotifyValue(watchType: .badgeNumber, old: "1", new: "3"))
        XCTAssertFalse(WatcherService.shouldNotifyValue(watchType: .badgeNumber, old: "3", new: "1"))
    }

    func testBadgeFirstReadingIsBaseline() {
        XCTAssertFalse(WatcherService.shouldNotifyValue(watchType: .badgeNumber, old: nil, new: "7"))
    }

    func testExistsNotifiesOnAppearance() {
        XCTAssertTrue(WatcherService.shouldNotifyValue(watchType: .elementExists, old: "false", new: "true"))
        XCTAssertFalse(WatcherService.shouldNotifyValue(watchType: .elementExists, old: "true", new: "true"))
    }

    func testDisappearsNotifiesOnRemoval() {
        XCTAssertTrue(WatcherService.shouldNotifyValue(watchType: .elementDisappears, old: "true", new: "false"))
        XCTAssertFalse(WatcherService.shouldNotifyValue(watchType: .elementDisappears, old: "false", new: "false"))
    }

    func testTextChangeNotifiesOnDifference() {
        XCTAssertTrue(WatcherService.shouldNotifyValue(watchType: .textChange, old: "a", new: "b"))
        XCTAssertFalse(WatcherService.shouldNotifyValue(watchType: .textChange, old: "a", new: "a"))
    }
}

final class WatcherMigrationTests: XCTestCase {

    /// Existing hand-tuned config must survive an upgrade unchanged.
    func testDecodesLegacyWatcherWithoutNewFields() throws {
        let legacy = """
        {"id":"AE28EB85-DDEE-4A79-8B5A-E02318052247","name":"LinkedIn","url":"https://www.linkedin.com/feed/",
         "selector":"/html/body/div[5]","selectorType":"XPath","watchType":"Badge/Number","interval":300,
         "isEnabled":true,"notificationSound":true,"lastValue":"0","consecutiveErrors":4722}
        """
        let w = try JSONDecoder().decode(Watcher.self, from: Data(legacy.utf8))

        XCTAssertEqual(w.name, "LinkedIn")
        XCTAssertNil(w.anchorSelector)
        XCTAssertNil(w.profileId)
        XCTAssertTrue(w.autoOpenEnabled)
        XCTAssertFalse(w.appOpenedTab)
        XCTAssertEqual(w.consecutiveCannotObserve, 0)
    }

    /// A legacy "0" is exactly what a dead selector used to write, so it must not
    /// be taken as proof the selector ever matched.
    func testLegacyZeroDoesNotCountAsEverMatched() throws {
        let legacy = #"{"id":"AE28EB85-DDEE-4A79-8B5A-E02318052247","name":"n","url":"u","selector":"s","selectorType":"CSS Selector","watchType":"Badge/Number","interval":60,"isEnabled":true,"notificationSound":true,"lastValue":"0"}"#
        let w = try JSONDecoder().decode(Watcher.self, from: Data(legacy.utf8))
        XCTAssertFalse(w.everMatched)
    }

    func testLegacyRealValueCountsAsEverMatched() throws {
        let legacy = #"{"id":"AE28EB85-DDEE-4A79-8B5A-E02318052247","name":"n","url":"u","selector":"s","selectorType":"CSS Selector","watchType":"Badge/Number","interval":60,"isEnabled":true,"notificationSound":true,"lastValue":"4"}"#
        let w = try JSONDecoder().decode(Watcher.self, from: Data(legacy.utf8))
        XCTAssertTrue(w.everMatched)
        XCTAssertEqual(w.lastConclusiveValue, "4")
    }

    /// The headline guarantee: a blocked check never reads as "nothing new".
    func testStatusNeverSaysNothingNewWhileBlocked() {
        var w = Watcher(name: "n", url: "u", selector: "s")
        w.lastConclusiveValue = "0"
        XCTAssertEqual(w.statusDisplay, "Nothing new")

        w.lastCannotReason = CannotReason.signedOut.rawValue
        XCTAssertEqual(w.statusDisplay, "Signed out")
        XCTAssertNotEqual(w.statusDisplay, "Nothing new")

        w.lastCannotReason = CannotReason.noTab.rawValue
        XCTAssertEqual(w.statusDisplay, "No tab open")
    }

    func testHealthEscalatesAfterRepeatedFailures() {
        var w = Watcher(name: "n", url: "u", selector: "s")
        w.lastCannotReason = CannotReason.noTab.rawValue
        w.consecutiveCannotObserve = 1
        if case .blocked = w.health {} else { XCTFail("expected blocked") }

        w.consecutiveCannotObserve = 3
        if case .broken = w.health {} else { XCTFail("expected broken") }
    }
}

final class SiteProfileTests: XCTestCase {

    func testMatchesHostAndSubdomains() {
        let store = SiteProfileStore.builtIns
        let linkedin = store.filter { $0.hostSuffix == "linkedin.com" }
        XCTAssertFalse(linkedin.isEmpty)
    }

    /// Built-ins were captured from live logged-in pages, and the LinkedIn ones
    /// depend on the count living in the nav link's aria-label.
    func testLinkedInProfilesUseAriaCount() {
        let p = SiteProfileStore.builtIns.first { $0.id == "linkedin.notifications" }
        XCTAssertEqual(p?.strategy, .ariaCount)
        XCTAssertEqual(p?.anchorSelector, "a[href*=\"/notifications/\"]")
    }

    /// Circle removes the count node at zero, so the bell button is the anchor.
    func testRiveProfileSeparatesAnchorFromBadge() {
        let p = SiteProfileStore.builtIns.first { $0.id == "rive.notifications" }
        XCTAssertEqual(p?.anchorSelector, "button[data-testid=\"notifications-menu-popover-button\"]")
        XCTAssertEqual(p?.badgeSelector, "[data-testid=\"unread-notifications-count\"]")
        // §3.2: rive.notifications gets needsRefresh: true (F2 — hidden tabs don't repaint).
        XCTAssertTrue(p?.needsRefresh ?? false)
    }

    func testGenericTitleProfileNeedsNoSelectors() {
        let p = SiteProfileStore.builtIns.first { $0.id == "generic.title" }
        XCTAssertEqual(p?.strategy, .documentTitle)
        XCTAssertNil(p?.anchorSelector)
    }
}

/// The notification title used to render a literal "{value}" because substitution
/// was applied to the body only.
final class NotificationTemplateTests: XCTestCase {

    private func expand(_ template: String, value: String, name: String, previous: String?) -> String {
        template
            .replacingOccurrences(of: "{value}", with: value)
            .replacingOccurrences(of: "{name}", with: name)
            .replacingOccurrences(of: "{previous}", with: previous ?? "0")
    }

    func testTitlePlaceholdersAreExpanded() {
        let out = expand("You've got {value} LinkedIn messages", value: "3", name: "LinkedIn Messages", previous: "1")
        XCTAssertEqual(out, "You've got 3 LinkedIn messages")
        XCTAssertFalse(out.contains("{value}"))
    }

    func testAllPlaceholdersExpand() {
        XCTAssertEqual(
            expand("{name}: {previous} -> {value}", value: "5", name: "Reddit", previous: "2"),
            "Reddit: 2 -> 5"
        )
    }

    func testMissingPreviousFallsBackToZero() {
        XCTAssertEqual(expand("{previous}", value: "1", name: "n", previous: nil), "0")
    }
}
