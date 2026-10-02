import XCTest
@testable import WebWatcher

/// Pure logic tests for `WatcherRecipe` — no Safari, no AppleScript. Every
/// `CandidateStrategy` mapping in DESIGN.md §3.4 gets its own case.
final class WatcherRecipeTests: XCTestCase {

    private func candidate(
        selector: String,
        anchor: String? = nil,
        strategy: CandidateStrategy,
        attr: String? = nil,
        value: String? = nil,
        label: String
    ) -> ElementCandidate {
        ElementCandidate(
            selector: selector, anchor: anchor, strategy: strategy, attr: attr, value: value,
            label: label, detail: "", technical: "", tier: 1, score: 0
        )
    }

    // MARK: - apply(): CandidateStrategy mapping

    func testApplyBadgeTextWithAnchorSetsAnchoredBadge() {
        var d = WatcherDraftFields()
        let c = candidate(selector: "[data-testid=x]", anchor: "button.bell", strategy: .badgeText, value: "2", label: "2 · inside Notifications")
        _ = WatcherRecipe.apply(c, pageURL: nil, pageTitle: nil, to: &d)

        XCTAssertEqual(d.selector, "[data-testid=x]")
        XCTAssertEqual(d.anchorSelector, "button.bell")
        XCTAssertEqual(d.badgeAttribute, "")
        XCTAssertEqual(d.strategy, .anchoredBadge)
        XCTAssertEqual(d.watchType, .badgeNumber)
        XCTAssertEqual(d.selectorType, .css)
        XCTAssertEqual(d.profileId, "")
        XCTAssertTrue(d.forceRefresh)
    }

    func testApplyBadgeTextWithoutAnchorLeavesStrategyNil() {
        var d = WatcherDraftFields()
        let c = candidate(selector: ".x", anchor: nil, strategy: .badgeText, value: "2", label: "2")
        _ = WatcherRecipe.apply(c, pageURL: nil, pageTitle: nil, to: &d)

        XCTAssertEqual(d.anchorSelector, "")
        XCTAssertNil(d.strategy)
        XCTAssertTrue(d.forceRefresh) // still F2-forced even with no anchor
    }

    func testApplyBadgeAttrCarriesAttributeName() {
        var d = WatcherDraftFields()
        let c = candidate(selector: ".x", anchor: "a.anchor", strategy: .badgeAttr, attr: "data-count", value: "5", label: "5 · inside Inbox")
        _ = WatcherRecipe.apply(c, pageURL: nil, pageTitle: nil, to: &d)

        XCTAssertEqual(d.badgeAttribute, "data-count")
        XCTAssertEqual(d.strategy, .anchoredBadge)
        XCTAssertEqual(d.watchType, .badgeNumber)
        XCTAssertTrue(d.forceRefresh)
    }

    func testApplyAriaCountUsesSelectorAsItsOwnAnchor() {
        var d = WatcherDraftFields()
        let c = candidate(selector: "a[aria-label]", strategy: .ariaCount, value: "4", label: "4 · inside Messaging")
        _ = WatcherRecipe.apply(c, pageURL: nil, pageTitle: nil, to: &d)

        XCTAssertEqual(d.selector, "a[aria-label]")
        XCTAssertEqual(d.anchorSelector, "a[aria-label]")
        XCTAssertEqual(d.strategy, .ariaCount)
        XCTAssertEqual(d.watchType, .badgeNumber)
        XCTAssertTrue(d.forceRefresh)
    }

    func testApplyAutoBadgePrefersAnchorOverSelector() {
        var d = WatcherDraftFields()
        let c = candidate(selector: "span.wrapper", anchor: "button.bell", strategy: .autoBadge, value: "0", label: "Number next to Notifications")
        _ = WatcherRecipe.apply(c, pageURL: nil, pageTitle: nil, to: &d)

        XCTAssertEqual(d.selector, "button.bell")
        XCTAssertEqual(d.anchorSelector, "button.bell")
        XCTAssertEqual(d.strategy, .autoBadge)
        XCTAssertTrue(d.forceRefresh)
    }

    func testApplyAutoBadgeFallsBackToSelectorWithoutAnchor() {
        var d = WatcherDraftFields()
        let c = candidate(selector: "button.bell", anchor: nil, strategy: .autoBadge, value: "0", label: "Number next to Bell")
        _ = WatcherRecipe.apply(c, pageURL: nil, pageTitle: nil, to: &d)

        XCTAssertEqual(d.selector, "button.bell")
        XCTAssertEqual(d.anchorSelector, "button.bell")
    }

    func testApplyTitleSetsGenericProfileAndClearsSelectorish() {
        var d = WatcherDraftFields()
        let c = candidate(selector: "title", strategy: .title, value: "3", label: "(3) in the tab title")
        _ = WatcherRecipe.apply(c, pageURL: nil, pageTitle: nil, to: &d)

        XCTAssertEqual(d.profileId, "generic.title")
        XCTAssertEqual(d.selector, "title")
        XCTAssertEqual(d.anchorSelector, "")
        XCTAssertNil(d.strategy)
        XCTAssertEqual(d.watchType, .badgeNumber)
        XCTAssertFalse(d.forceRefresh) // untouched — title is not one of the four badge strategies
    }

    func testApplyTextSetsTextChangeWatchType() {
        var d = WatcherDraftFields()
        let c = candidate(selector: "p.status", anchor: "div.card", strategy: .text, value: "Open", label: "Open")
        _ = WatcherRecipe.apply(c, pageURL: nil, pageTitle: nil, to: &d)

        XCTAssertEqual(d.selector, "p.status")
        XCTAssertEqual(d.anchorSelector, "div.card")
        XCTAssertNil(d.strategy)
        XCTAssertEqual(d.watchType, .textChange)
    }

    func testApplyExistsSetsElementExists() {
        var d = WatcherDraftFields()
        let c = candidate(selector: ".flag", anchor: "div.card", strategy: .exists, value: "true", label: "flag")
        _ = WatcherRecipe.apply(c, pageURL: nil, pageTitle: nil, to: &d)

        XCTAssertEqual(d.watchType, .elementExists)
        XCTAssertEqual(d.anchorSelector, "div.card")
    }

    func testApplyCountSetsElementCount() {
        var d = WatcherDraftFields()
        let c = candidate(selector: "li.item", strategy: .count, value: "4", label: "items")
        _ = WatcherRecipe.apply(c, pageURL: nil, pageTitle: nil, to: &d)

        XCTAssertEqual(d.watchType, .elementCount)
    }

    /// forceRefresh is untouched (not reset to false) for the non-badge strategies —
    /// a manually-enabled setting must survive re-applying a text/exists/count pick.
    func testApplyLeavesPreExistingForceRefreshUntouchedForNonBadgeStrategies() {
        var d = WatcherDraftFields()
        d.forceRefresh = true
        let c = candidate(selector: "p", strategy: .text, value: "x", label: "x")
        _ = WatcherRecipe.apply(c, pageURL: nil, pageTitle: nil, to: &d)
        XCTAssertTrue(d.forceRefresh)
    }

    // MARK: - apply(): URL rules

    func testApplySetsURLWhenDraftURLIsEmpty() {
        var d = WatcherDraftFields()
        let c = candidate(selector: "a", strategy: .text, value: "x", label: "x")
        let outcome = WatcherRecipe.apply(c, pageURL: "https://example.com/page#frag", pageTitle: nil, to: &d)

        XCTAssertEqual(d.url, "https://example.com/page")
        XCTAssertFalse(outcome.urlChanged)
        XCTAssertNil(outcome.previousURL)
    }

    func testApplyKeepsSameURLWithoutFlaggingChange() {
        var d = WatcherDraftFields()
        d.url = "https://example.com/page"
        let c = candidate(selector: "a", strategy: .text, value: "x", label: "x")
        let outcome = WatcherRecipe.apply(c, pageURL: "https://example.com/page", pageTitle: nil, to: &d)

        XCTAssertEqual(d.url, "https://example.com/page")
        XCTAssertFalse(outcome.urlChanged)
        XCTAssertNil(outcome.previousURL)
    }

    func testApplyFlagsChangedURLWithPrevious() {
        var d = WatcherDraftFields()
        d.url = "https://example.com/old"
        let c = candidate(selector: "a", strategy: .text, value: "x", label: "x")
        let outcome = WatcherRecipe.apply(c, pageURL: "https://example.com/new", pageTitle: nil, to: &d)

        XCTAssertEqual(d.url, "https://example.com/new")
        XCTAssertTrue(outcome.urlChanged)
        XCTAssertEqual(outcome.previousURL, "https://example.com/old")
    }

    func testApplyLeavesURLUntouchedWhenPageURLIsNil() {
        var d = WatcherDraftFields()
        d.url = "https://example.com/old"
        let c = candidate(selector: "a", strategy: .text, value: "x", label: "x")
        let outcome = WatcherRecipe.apply(c, pageURL: nil, pageTitle: nil, to: &d)

        XCTAssertEqual(d.url, "https://example.com/old")
        XCTAssertFalse(outcome.urlChanged)
        XCTAssertNil(outcome.previousURL)
    }

    // MARK: - normalizedPageURL

    func testNormalizedPageURLStripsFragmentKeepsQuery() {
        XCTAssertEqual(WatcherRecipe.normalizedPageURL("https://x.com/a?b=1#frag"), "https://x.com/a?b=1")
        XCTAssertEqual(WatcherRecipe.normalizedPageURL("https://x.com/a"), "https://x.com/a")
    }

    // MARK: - suggestedName

    /// The literal example from DESIGN.md §3.4.
    func testSuggestedNameRiveCommunityNotifications() {
        let c = candidate(selector: "[data-testid=x]", anchor: "button.bell", strategy: .badgeText, value: "2", label: "2 · inside Notifications")
        let name = WatcherRecipe.suggestedName(for: c, pageURL: "https://community.rive.app/feed", pageTitle: "Feed | Rive Community")
        XCTAssertEqual(name, "Rive Community Notifications")
    }

    /// The literal example from DESIGN.md §3.4 — "Go to " is stripped from the anchor name.
    func testSuggestedNameContraMessagesStripsGoToPrefix() {
        let c = candidate(
            selector: "a[aria-label=\"Go to Messages\"] number-flow-react",
            anchor: "a[aria-label=\"Go to Messages\"]",
            strategy: .badgeText, value: "3", label: "3 · inside Go to Messages"
        )
        let name = WatcherRecipe.suggestedName(for: c, pageURL: "https://contra.com/community/for-you", pageTitle: "Contra")
        XCTAssertEqual(name, "Contra Messages")
    }

    func testSuggestedNameFallsBackToSubdomainWhenTitleDoesNotConfirmSiteName() {
        let c = candidate(selector: "x", strategy: .exists, value: "true", label: "flag")
        let name = WatcherRecipe.suggestedName(for: c, pageURL: "https://community.rive.app/feed", pageTitle: "Some Unrelated Title")
        XCTAssertEqual(name, "Community Element")
    }

    func testSuggestedNameFallsBackToGenericThingWhenNoAnchorName() {
        let c = candidate(selector: "x", strategy: .text, value: "hi", label: "hi")
        let name = WatcherRecipe.suggestedName(for: c, pageURL: nil, pageTitle: nil)
        XCTAssertEqual(name, "This Site Text")
    }

    func testSuggestedNameBadgeThingFallsBackToBadgeWord() {
        let c = candidate(selector: "x", strategy: .badgeText, value: "1", label: "1")
        let name = WatcherRecipe.suggestedName(for: c, pageURL: "https://example.com/", pageTitle: nil)
        XCTAssertEqual(name, "Example Badge")
    }

    // MARK: - canConfirmZero

    func testCanConfirmZeroAlwaysTrueForAriaCountAutoBadgeAndTitle() {
        XCTAssertTrue(WatcherRecipe.canConfirmZero(candidate(selector: "a", strategy: .ariaCount, label: "l")))
        XCTAssertTrue(WatcherRecipe.canConfirmZero(candidate(selector: "a", strategy: .autoBadge, label: "l")))
        XCTAssertTrue(WatcherRecipe.canConfirmZero(candidate(selector: "title", strategy: .title, label: "l")))
    }

    func testCanConfirmZeroRequiresAnchorForOtherStrategies() {
        XCTAssertTrue(WatcherRecipe.canConfirmZero(candidate(selector: "a", anchor: "b", strategy: .badgeText, label: "l")))
        XCTAssertFalse(WatcherRecipe.canConfirmZero(candidate(selector: "a", anchor: nil, strategy: .badgeText, label: "l")))
        XCTAssertFalse(WatcherRecipe.canConfirmZero(candidate(selector: "a", anchor: nil, strategy: .badgeAttr, label: "l")))
        XCTAssertFalse(WatcherRecipe.canConfirmZero(candidate(selector: "a", anchor: nil, strategy: .text, label: "l")))
        XCTAssertFalse(WatcherRecipe.canConfirmZero(candidate(selector: "a", anchor: nil, strategy: .exists, label: "l")))
        XCTAssertFalse(WatcherRecipe.canConfirmZero(candidate(selector: "a", anchor: nil, strategy: .count, label: "l")))
    }

    // MARK: - summary

    func testSummaryBadgeWithAnchorConfirmsZero() {
        let c = candidate(selector: "a", anchor: "b", strategy: .badgeText, value: "2", label: "2 · inside Notifications")
        XCTAssertEqual(WatcherRecipe.summary(for: c), "Watching “2” inside Notifications · zero confirmed by anchor")
    }

    func testSummaryBadgeWithoutAnchorCannotConfirmZero() {
        let c = candidate(selector: "a", anchor: nil, strategy: .badgeText, value: "9", label: "9")
        XCTAssertEqual(WatcherRecipe.summary(for: c), "Watching “9” · zero can't be confirmed (no anchor)")
    }

    func testSummaryAutoBadgeAlwaysConfirmsZero() {
        let c = candidate(selector: "a", anchor: "b", strategy: .autoBadge, value: "0", label: "Number next to Notifications")
        XCTAssertEqual(WatcherRecipe.summary(for: c), "Watching for a number next to Notifications · zero confirmed by anchor")
    }

    func testSummaryTitle() {
        let c = candidate(selector: "title", strategy: .title, value: "3", label: "(3) in the tab title")
        XCTAssertEqual(WatcherRecipe.summary(for: c), "Watching the (N) in the tab title")
    }
}
