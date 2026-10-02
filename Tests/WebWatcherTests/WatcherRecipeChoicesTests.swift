import XCTest
@testable import WebWatcher

/// Coverage for §3.3/§9.4's `WatcherRecipe.watchChoices`/`candidate(switchedTo:)`, and the
/// `.subtree` case added to every `CandidateStrategy` switch in `WatcherRecipe`. Pure logic
/// — no Safari, no AppleScript, no Keychain, no network. Kept separate from the pre-existing
/// `WatcherRecipeTests.swift`, which is left untouched.
final class WatcherRecipeChoicesTests: XCTestCase {

    private func candidate(
        selector: String = "a",
        anchor: String? = nil,
        strategy: CandidateStrategy,
        attr: String? = nil,
        value: String? = nil,
        label: String = "label"
    ) -> ElementCandidate {
        ElementCandidate(
            selector: selector, anchor: anchor, strategy: strategy, attr: attr, value: value,
            label: label, detail: "", technical: "", tier: 1, score: 0
        )
    }

    // MARK: - watchChoices: titles + recommended-first, per §3.3/§9.4

    func testBadgeTextAriaCountAndTitleShareTheSameTwoChoices() {
        for strategy: CandidateStrategy in [.badgeText, .badgeAttr, .ariaCount, .title] {
            let choices = WatcherRecipe.watchChoices(for: candidate(strategy: strategy))
            XCTAssertEqual(choices.count, 2, "\(strategy)")
            XCTAssertEqual(choices[0].title, "Track the number", "\(strategy)")
            XCTAssertEqual(choices[0].id, strategy, "\(strategy)")
            XCTAssertTrue(choices[0].recommended, "\(strategy)")
            XCTAssertEqual(choices[1].title, "Anything changes inside", "\(strategy)")
            XCTAssertEqual(choices[1].id, .subtree, "\(strategy)")
            XCTAssertFalse(choices[1].recommended, "\(strategy)")
        }
    }

    func testAutoBadgeOffersThreeChoicesWithAutoBadgeRecommended() {
        let choices = WatcherRecipe.watchChoices(for: candidate(strategy: .autoBadge))
        XCTAssertEqual(choices.map(\.title), [
            "A number appears next to it",
            "Anything changes inside it",
            "It appears or disappears"
        ])
        XCTAssertEqual(choices.map(\.id), [.autoBadge, .subtree, .exists])
        XCTAssertEqual(choices.map(\.recommended), [true, false, false])
        XCTAssertEqual(choices[0].detail, "Confirmed zero while there is no number")
    }

    /// §9.4: autoBadge's subtree row detail becomes the same "Best for an icon with no
    /// counter yet…" text used by exists/count's subtree row.
    func testAutoBadgeSubtreeDetailMatchesExistsAndCountSubtreeDetail() {
        let autoBadgeChoices = WatcherRecipe.watchChoices(for: candidate(strategy: .autoBadge))
        let existsChoices = WatcherRecipe.watchChoices(for: candidate(strategy: .exists))
        let countChoices = WatcherRecipe.watchChoices(for: candidate(strategy: .count))

        let autoBadgeSubtree = autoBadgeChoices.first { $0.id == .subtree }!
        let existsSubtree = existsChoices.first { $0.id == .subtree }!
        let countSubtree = countChoices.first { $0.id == .subtree }!

        XCTAssertEqual(autoBadgeSubtree.detail, existsSubtree.detail)
        XCTAssertEqual(autoBadgeSubtree.detail, countSubtree.detail)
        XCTAssertTrue(autoBadgeSubtree.detail.hasPrefix("Best for an icon with no counter yet"))
    }

    func testTextOffersTwoChoicesWithTextRecommended() {
        let choices = WatcherRecipe.watchChoices(for: candidate(strategy: .text))
        XCTAssertEqual(choices.map(\.title), ["The text changes", "Anything changes inside"])
        XCTAssertEqual(choices.map(\.id), [.text, .subtree])
        XCTAssertEqual(choices.map(\.recommended), [true, false])
    }

    /// §9.4 override: exists gets its own exact title/detail, not the plain §3.3 pair.
    func testExistsOffersCurrentAndSubtreePerAmendment() {
        let choices = WatcherRecipe.watchChoices(for: candidate(strategy: .exists))
        XCTAssertEqual(choices.count, 2)
        XCTAssertEqual(choices[0].id, .exists)
        XCTAssertEqual(choices[0].title, "It appears or disappears")
        XCTAssertEqual(choices[0].detail, "Notify when this element shows up or goes away.")
        XCTAssertTrue(choices[0].recommended)
        XCTAssertEqual(choices[1].id, .subtree)
        XCTAssertEqual(choices[1].title, "Anything changes inside it")
        XCTAssertFalse(choices[1].recommended)
    }

    /// §9.4 override: count gets its own exact title/detail, subtree row identical to exists'.
    func testCountOffersCurrentAndSubtreePerAmendment() {
        let choices = WatcherRecipe.watchChoices(for: candidate(strategy: .count))
        XCTAssertEqual(choices.count, 2)
        XCTAssertEqual(choices[0].id, .count)
        XCTAssertEqual(choices[0].title, "The count changes")
        XCTAssertEqual(choices[0].detail, "Notify when the number of matching elements changes.")
        XCTAssertTrue(choices[0].recommended)
        XCTAssertEqual(choices[1].id, .subtree)
        XCTAssertEqual(choices[1].title, "Anything changes inside it")
    }

    func testSubtreeCandidateOffersItsSingleChoiceRecommended() {
        let choices = WatcherRecipe.watchChoices(for: candidate(strategy: .subtree))
        XCTAssertEqual(choices.count, 1)
        XCTAssertEqual(choices[0].id, .subtree)
        XCTAssertTrue(choices[0].recommended)
    }

    // MARK: - candidate(_:switchedTo:) — selector/anchor kept, strategy/displayValue adjusted

    func testCandidateSwitchedToSubtreeKeepsSelectorAndAnchor() {
        let c = candidate(selector: "[data-testid=x]", anchor: "button.bell", strategy: .badgeText, value: "2", label: "2 · inside Notifications")
        let switched = WatcherRecipe.candidate(c, switchedTo: .subtree)

        XCTAssertEqual(switched.selector, c.selector)
        XCTAssertEqual(switched.anchor, c.anchor)
        XCTAssertEqual(switched.strategy, .subtree)
        XCTAssertEqual(switched.displayValue, "changes")
    }

    func testCandidateSwitchedToSameStrategyIsUnchanged() {
        let c = candidate(strategy: .text, value: "hi", label: "hi")
        let switched = WatcherRecipe.candidate(c, switchedTo: .text)
        XCTAssertEqual(switched, c)
        XCTAssertEqual(switched.value, "hi")
    }

    func testCandidateSwitchedAwayFromSubtreeClearsStaleValue() {
        let c = candidate(strategy: .subtree, value: "3:aaa", label: "changes · inside Bell")
        let switched = WatcherRecipe.candidate(c, switchedTo: .exists)
        XCTAssertEqual(switched.strategy, .exists)
        XCTAssertNil(switched.value)
    }

    /// The anchor-name marker in `label` must survive a strategy switch so
    /// `summary(for:)`'s subtree wording can still find the anchor's human name.
    func testCandidateSwitchedToSubtreePreservesAnchorNameInLabelForSummary() {
        let c = candidate(anchor: "button.bell", strategy: .badgeText, value: "2", label: "2 · inside Notifications")
        let switched = WatcherRecipe.candidate(c, switchedTo: .subtree)
        XCTAssertEqual(WatcherRecipe.summary(for: switched), "Watching for any change inside Notifications")
    }

    // MARK: - apply(.subtree) — §3.3

    func testApplySubtreeSetsWatchTypeAndClearsBadgeFields() {
        var d = WatcherDraftFields()
        let c = candidate(selector: "div.feed", anchor: "button.bell", strategy: .subtree, label: "changes · inside Notifications")
        _ = WatcherRecipe.apply(c, pageURL: nil, pageTitle: nil, to: &d)

        XCTAssertEqual(d.selector, "div.feed")
        XCTAssertEqual(d.anchorSelector, "button.bell")
        XCTAssertEqual(d.badgeAttribute, "")
        XCTAssertNil(d.strategy)
        XCTAssertEqual(d.watchType, .subtreeChange)
        XCTAssertTrue(d.forceRefresh)
    }

    func testApplySubtreeWithoutAnchorLeavesAnchorSelectorEmpty() {
        var d = WatcherDraftFields()
        let c = candidate(selector: "div.feed", anchor: nil, strategy: .subtree, label: "changes")
        _ = WatcherRecipe.apply(c, pageURL: nil, pageTitle: nil, to: &d)

        XCTAssertEqual(d.anchorSelector, "")
        XCTAssertTrue(d.forceRefresh)
    }

    // MARK: - summary(.subtree) — §3.3

    func testSummarySubtreeWithAnchorName() {
        let c = candidate(anchor: "button.bell", strategy: .subtree, label: "changes · inside Notifications")
        XCTAssertEqual(WatcherRecipe.summary(for: c), "Watching for any change inside Notifications")
    }

    func testSummarySubtreeFallsBackToSelectorWithoutAnchorName() {
        let c = candidate(selector: "div.feed-area", strategy: .subtree, label: "changes")
        XCTAssertEqual(WatcherRecipe.summary(for: c), "Watching for any change inside div.feed-area")
    }

    // MARK: - canConfirmZero(.subtree) — §9.4: always true

    func testCanConfirmZeroSubtreeIsAlwaysTrue() {
        XCTAssertTrue(WatcherRecipe.canConfirmZero(candidate(anchor: "b", strategy: .subtree)))
        XCTAssertTrue(WatcherRecipe.canConfirmZero(candidate(anchor: nil, strategy: .subtree)))
    }

    // MARK: - suggestedName / thingName(.subtree) — §9.4: "Area"

    func testSuggestedNameFallsBackToAreaForSubtreeWithNoAnchorName() {
        let c = candidate(selector: "div.feed", strategy: .subtree, label: "changes")
        let name = WatcherRecipe.suggestedName(for: c, pageURL: "https://example.com/", pageTitle: nil)
        XCTAssertEqual(name, "Example Area")
    }

    func testSuggestedNameUsesAnchorNameForSubtreeWhenPresent() {
        let c = candidate(anchor: "button.bell", strategy: .subtree, label: "changes · inside Notifications")
        let name = WatcherRecipe.suggestedName(for: c, pageURL: "https://example.com/", pageTitle: nil)
        XCTAssertEqual(name, "Example Notifications")
    }

    // MARK: - ElementCandidate.displayValue(.subtree)

    func testDisplayValueForSubtreeIsAlwaysChanges() {
        XCTAssertEqual(candidate(strategy: .subtree, value: nil).displayValue, "changes")
        XCTAssertEqual(candidate(strategy: .subtree, value: "3:aaa").displayValue, "changes")
    }
}
