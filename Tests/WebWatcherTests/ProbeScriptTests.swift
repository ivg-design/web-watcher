import XCTest
@testable import WebWatcher

/// Coverage for `ProbeMode` and the AppleScript/CFG generation in `ProbeScript`
/// (DESIGN.md §3.6/§5). These assert on the generated *text* rather than trying to
/// run the scripts (that needs live Safari — see ScriptDumpTests + the live
/// verification protocol in §10), so they stay fast and hermetic.
final class ProbeScriptTests: XCTestCase {

    /// Pulls the `CFG` object back out of `javaScript(for:profile:mode:)`'s output
    /// and decodes it, so assertions compare actual values rather than fragile
    /// substrings — selectors can contain quotes (`[data-testid="…"]`) that JSON
    /// escapes, which a plain `.contains` check would get wrong.
    ///
    /// `__CFG__` is gone from the output (it was substituted), but the JSON object
    /// ProbeScript put in its place is still there as a self-contained `{...}`
    /// blob. This scans for it directly rather than assuming anything about the
    /// surrounding JS text, which `ProbeProgram` (owned separately) is free to change.
    private func cfg(_ js: String) throws -> [String: Any] {
        // `ProbeProgram.source` is `(function () { … })()` (§3.5) — its own
        // opening brace precedes `var CFG = { … }`, so the first `{` in the
        // whole script is the IIFE's, not the CFG object's. Anchor on the
        // assignment itself and take the first `{` after it.
        guard let assign = js.range(of: "CFG = "),
              let start = js[assign.upperBound...].firstIndex(of: "{") else {
            throw XCTSkip("no CFG object found in generated JS")
        }
        var depth = 0
        var inString = false
        var escaped = false
        var end = start
        var i = start
        while i < js.endIndex {
            let c = js[i]
            if inString {
                if escaped { escaped = false }
                else if c == "\\" { escaped = true }
                else if c == "\"" { inString = false }
            } else {
                if c == "\"" { inString = true }
                else if c == "{" { depth += 1 }
                else if c == "}" {
                    depth -= 1
                    if depth == 0 { end = i; break }
                }
            }
            i = js.index(after: i)
        }
        let jsonText = String(js[start...end])
        let data = try XCTUnwrap(jsonText.data(using: .utf8))
        let obj = try JSONSerialization.jsonObject(with: data)
        return try XCTUnwrap(obj as? [String: Any])
    }

    // MARK: - ProbeMode

    func testModeKeys() {
        XCTAssertEqual(ProbeMode.check.key, "check")
        XCTAssertEqual(ProbeMode.diagnose.key, "diagnose")
        XCTAssertEqual(ProbeMode.suggestAnchors.key, "suggest")
        XCTAssertEqual(ProbeMode.scan.key, "scan")
        XCTAssertEqual(ProbeMode.pickStart.key, "pickStart")
        XCTAssertEqual(ProbeMode.pickPoll.key, "pickPoll")
        XCTAssertEqual(ProbeMode.pickStop.key, "pickStop")
        XCTAssertEqual(ProbeMode.highlight(selector: "#x").key, "highlight")
    }

    func testIsInteractive() {
        XCTAssertFalse(ProbeMode.check.isInteractive)
        XCTAssertFalse(ProbeMode.diagnose.isInteractive)
        XCTAssertFalse(ProbeMode.suggestAnchors.isInteractive)
        XCTAssertTrue(ProbeMode.scan.isInteractive)
        XCTAssertTrue(ProbeMode.pickStart.isInteractive)
        XCTAssertTrue(ProbeMode.pickPoll.isInteractive)
        XCTAssertTrue(ProbeMode.pickStop.isInteractive)
        XCTAssertTrue(ProbeMode.highlight(selector: "#x").isInteractive)
    }

    /// §3.6/9: the guided assistant's "Page" step (`locate`) and the CSP-proof
    /// "Use this element" action (`pickConfirm`) dispatch on their own CFG.mode keys.
    func testLocateAndPickConfirmModeKeys() {
        XCTAssertEqual(ProbeMode.locate.key, "locate")
        XCTAssertEqual(ProbeMode.pickConfirm.key, "pickConfirm")
    }

    /// Both read/act on whatever the user is currently looking at, so — like scan
    /// and the other pick modes — they must never trigger a background-tab reload.
    func testLocateAndPickConfirmAreInteractive() {
        XCTAssertTrue(ProbeMode.locate.isInteractive)
        XCTAssertTrue(ProbeMode.pickConfirm.isInteractive)
    }

    func testModeEquatable() {
        XCTAssertEqual(ProbeMode.highlight(selector: "#a"), ProbeMode.highlight(selector: "#a"))
        XCTAssertNotEqual(ProbeMode.highlight(selector: "#a"), ProbeMode.highlight(selector: "#b"))
        XCTAssertNotEqual(ProbeMode.scan, ProbeMode.pickStart)
    }

    // MARK: - CFG · mode key

    func testJavaScriptEmbedsModeKey() {
        let js = ProbeScript.javaScript(for: Watcher(url: "https://example.com"), profile: nil, mode: .scan)
        // Literal substring check, per DESIGN.md §9's own wording.
        XCTAssertTrue(js.contains(#""mode":"scan""#), "expected CFG.mode to be scan, got: \(js)")
    }

    // MARK: - CFG · strategy precedence (profile > watcher.strategy > "manual")

    func testStrategyPrecedenceProfileWinsOverWatcher() throws {
        var w = Watcher(url: "https://community.rive.app/feed")
        w.strategy = .autoBadge
        let profile = try XCTUnwrap(SiteProfileStore.builtIns.first { $0.id == "rive.notifications" })
        XCTAssertEqual(profile.strategy, .anchoredBadge)

        let c = try cfg(ProbeScript.javaScript(for: w, profile: profile, mode: .check))
        XCTAssertEqual(c["strategy"] as? String, "anchoredBadge")
    }

    func testStrategyFallsBackToWatcherWhenNoProfile() throws {
        var w = Watcher(url: "https://example.com")
        w.strategy = .autoBadge

        let c = try cfg(ProbeScript.javaScript(for: w, profile: nil, mode: .check))
        XCTAssertEqual(c["strategy"] as? String, "autoBadge")
    }

    func testStrategyFallsBackToManualWithNeitherProfileNorWatcherStrategy() throws {
        let w = Watcher(url: "https://example.com")
        XCTAssertNil(w.strategy)

        let c = try cfg(ProbeScript.javaScript(for: w, profile: nil, mode: .check))
        XCTAssertEqual(c["strategy"] as? String, "manual")
    }

    // MARK: - CFG · badge fallback

    func testBadgeFallsBackToWatcherSelectorWhenWatcherHasStrategy() throws {
        var w = Watcher(url: "https://example.com", selector: ".my-badge")
        w.strategy = .autoBadge

        let c = try cfg(ProbeScript.javaScript(for: w, profile: nil, mode: .check))
        XCTAssertEqual(c["badge"] as? String, ".my-badge")
    }

    func testBadgeIsNullForManualWatcherWithNoProfile() throws {
        let w = Watcher(url: "https://example.com", selector: ".my-badge")
        XCTAssertNil(w.strategy)

        let c = try cfg(ProbeScript.javaScript(for: w, profile: nil, mode: .check))
        // "manual" watchers read `selector`/`watchType` directly; `badge` must stay
        // null so the anchoredBadge/autoBadge code paths in the program never fire.
        XCTAssertTrue(c["badge"] is NSNull, "expected badge to be JSON null, got \(String(describing: c["badge"]))")
    }

    func testBadgePrefersProfileOverWatcherStrategy() throws {
        var w = Watcher(url: "https://community.rive.app/feed", selector: "should-be-ignored")
        w.strategy = .autoBadge
        let profile = try XCTUnwrap(SiteProfileStore.builtIns.first { $0.id == "rive.notifications" })

        let c = try cfg(ProbeScript.javaScript(for: w, profile: profile, mode: .check))
        XCTAssertEqual(c["badge"] as? String, profile.badgeSelector)
    }

    // MARK: - CFG · watchType key (G2 subtree)

    /// §3.6: `watchTypeKey(.subtreeChange)` must be `"subtree"`, the key the JS
    /// fingerprint branch (§3.5/9.2) dispatches its CFG.watchType check on.
    func testWatchTypeKeySubtreeChange() throws {
        let w = Watcher(url: "https://example.com", watchType: .subtreeChange)
        let c = try cfg(ProbeScript.javaScript(for: w, profile: nil, mode: .check))
        XCTAssertEqual(c["watchType"] as? String, "subtree")
    }

    // MARK: - CFG · highlight selector

    func testHighlightModePutsSelectorIntoHl() throws {
        let w = Watcher(url: "https://example.com")
        let c = try cfg(ProbeScript.javaScript(for: w, profile: nil, mode: .highlight(selector: "[data-testid=\"x\"]")))
        XCTAssertEqual(c["hl"] as? String, "[data-testid=\"x\"]")
        XCTAssertEqual(c["mode"] as? String, "highlight")
    }

    func testHlIsNullOutsideHighlightMode() throws {
        let w = Watcher(url: "https://example.com")
        let c = try cfg(ProbeScript.javaScript(for: w, profile: nil, mode: .check))
        XCTAssertTrue(c["hl"] is NSNull)
    }

    // MARK: - AppleScript · sentinels and structure

    func testCheckScriptContainsTabBlankSentinelAndNeverOpensATab() {
        let w = Watcher(url: "https://example.com")
        let script = ProbeScript.probeScript(for: w, profile: nil, mode: .check)
        XCTAssertTrue(script.contains("WW_TAB_BLANK"))
        XCTAssertFalse(script.contains("make new tab"))
    }

    func testInteractiveModesCarryTheInteractiveMarker() {
        let w = Watcher(url: "https://example.com")
        for mode: ProbeMode in [.scan, .pickStart, .pickPoll, .pickStop, .highlight(selector: "#x"), .locate, .pickConfirm] {
            let script = ProbeScript.probeScript(for: w, profile: nil, mode: mode)
            XCTAssertTrue(script.contains("-- interactive"), "mode \(mode.key) missing interactive marker")
        }
    }

    func testNonInteractiveModesDoNotCarryTheInteractiveMarker() {
        let w = Watcher(url: "https://example.com")
        for mode: ProbeMode in [.check, .diagnose, .suggestAnchors] {
            let script = ProbeScript.probeScript(for: w, profile: nil, mode: mode)
            XCTAssertFalse(script.contains("-- interactive"), "mode \(mode.key) should not force wantsRefresh off")
        }
    }

    // MARK: - Reload/activate script sentinels

    func testActivateAndReloadScriptsCarryTheirSentinels() {
        let w = Watcher(url: "https://example.com")
        let activate = ProbeScript.activateTabScript(for: w, profile: nil)
        XCTAssertTrue(activate.contains("WW_ACTIVATED"))
        XCTAssertFalse(activate.contains("make new tab"))

        let reload = ProbeScript.reloadTabScript(for: w, profile: nil)
        XCTAssertTrue(reload.contains("WW_RELOADED"))
        XCTAssertTrue(reload.contains("WW_STILL_BLANK"))
        XCTAssertFalse(reload.contains("make new tab"))
    }

    /// Regression for the stale-tab-reference defect: `tab (tabIdx of chosen) of
    /// (winRef of chosen)` must never be resolved once into a `t` variable and then
    /// reused across the multi-second reload/wait pipeline, since Safari's
    /// positional tab specifier can drift under it if another tab in the same
    /// window closes mid-wait. `waitForLive`/`reloadTab` must instead take
    /// `winRef`/`tabIdx` and every caller must re-resolve the tab at each Apple
    /// Event send.
    func testReloadDoesNotCaptureAStaleTabReference() {
        let w = Watcher(url: "https://example.com", forceRefresh: true)

        let probe = ProbeScript.probeScript(for: w, profile: nil, mode: .check)
        let reload = ProbeScript.reloadTabScript(for: w, profile: nil)
        let activate = ProbeScript.activateTabScript(for: w, profile: nil)

        for script in [probe, reload, activate] {
            XCTAssertFalse(script.contains("set t to tab"),
                            "must not bind a single tab reference reused across multiple Apple Events")
        }

        XCTAssertTrue(probe.contains("on waitForLive(winRef, tabIdx)"))
        XCTAssertTrue(probe.contains("on reloadTab(winRef, tabIdx, settleSeconds)"))
        XCTAssertTrue(probe.contains("my reloadTab((winRef of chosen), (tabIdx of chosen)"))
        XCTAssertTrue(probe.contains("tell tab (tabIdx of chosen) of (winRef of chosen)"),
                      "the final do JavaScript read must re-resolve the tab by position, not reuse a captured reference")

        XCTAssertTrue(reload.contains("my reloadTab((winRef of chosen), (tabIdx of chosen)"))
    }

    /// The reload decision must key off the page's own visibility, not Safari's
    /// per-window `visible` tab flag: the current tab of a window behind other apps
    /// is `visible` to AppleScript yet `hidden` to the document, and hidden pages
    /// do not repaint. Measured 2026-09-26: a check on such a tab skipped its reload.
    func testChosenTabVisibilityComesFromDocumentVisibilityState() {
        let w = Watcher(name: "x", url: "https://example.com/", selector: ".b")
        let script = ProbeScript.probeScript(for: w, profile: nil, mode: .check)
        XCTAssertTrue(script.contains("document.visibilityState"))
        XCTAssertTrue(script.contains("vis:docVisible"))
        XCTAssertFalse(script.contains("vis:(vis of rec), blank:false"))
    }
}
