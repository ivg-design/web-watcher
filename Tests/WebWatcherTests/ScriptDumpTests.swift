import XCTest
@testable import WebWatcher

/// Live-verification support (DESIGN.md §10 step 2). Not a real test in the
/// assertion sense — when `WW_DUMP_DIR` is set, it writes out the AppleScript
/// `ProbeScript` generates for a fixture watcher and for the built-in
/// `rive.notifications` watcher, so the integrator can `osacompile` them for
/// syntax and run them with `osascript` against live Safari (§10 step 3/4).
/// Skipped otherwise, so this never runs as part of an ordinary `swift test`.
final class ScriptDumpTests: XCTestCase {

    func testDumpScripts() throws {
        guard let dumpDir = ProcessInfo.processInfo.environment["WW_DUMP_DIR"], !dumpDir.isEmpty else {
            throw XCTSkip("WW_DUMP_DIR not set")
        }

        let dumpURL = URL(fileURLWithPath: dumpDir)
        try FileManager.default.createDirectory(at: dumpURL, withIntermediateDirectories: true)

        // The fixture lives at "<scratchpad>/fixture/badge-fixture.html" and the
        // integrator always points WW_DUMP_DIR at "<scratchpad>/dump" (see §10
        // step 2's own invocation), so the fixture is WW_DUMP_DIR's sibling
        // directory. Deriving it this way — instead of hardcoding this session's
        // scratchpad path into a file that stays in the repo — keeps the test
        // working for whichever scratchpad a future run uses.
        let fixtureHTML = dumpURL.deletingLastPathComponent()
            .appendingPathComponent("fixture", isDirectory: true)
            .appendingPathComponent("badge-fixture.html")
        let fixtureURLString = "file://" + fixtureHTML.path

        // (a) A custom/manual watcher pointed at the fixture. Its selector/anchor
        // target the fixture's direct-messages badge (a plain badgeText recipe);
        // a second, autoBadge-flavored copy below targets the bell for the
        // check-mode zero/non-zero verification in §10 step 3.
        var fixtureWatcher = Watcher(
            name: "Fixture DMs",
            url: fixtureURLString,
            selector: "[data-testid=\"unread-direct-messages-count\"]",
            anchorSelector: "button[data-testid=\"direct-messages-popover-button\"]"
        )
        fixtureWatcher.forceRefresh = false

        var fixtureBellWatcher = fixtureWatcher
        fixtureBellWatcher.name = "Fixture Bell"
        fixtureBellWatcher.selector = "button[data-testid=\"notifications-menu-popover-button\"]"
        fixtureBellWatcher.anchorSelector = fixtureBellWatcher.selector
        fixtureBellWatcher.strategy = .autoBadge

        // (b) The built-in Rive notifications recipe, exactly as a real watcher
        // using it would be configured (profileId set, selector mirrors the
        // profile's badge selector for display purposes only — the profile wins
        // per the strategy/badge precedence in §3.6).
        let riveProfile = try XCTUnwrap(
            SiteProfileStore.builtIns.first { $0.id == "rive.notifications" },
            "rive.notifications built-in profile is missing"
        )
        var riveWatcher = Watcher(
            name: riveProfile.displayName,
            url: riveProfile.watchURL,
            selector: riveProfile.badgeSelector ?? "",
            anchorSelector: riveProfile.anchorSelector,
            profileId: riveProfile.id
        )
        riveWatcher.forceRefresh = false // profile.needsRefresh already drives this

        func write(_ name: String, _ text: String) throws {
            let url = dumpURL.appendingPathComponent(name)
            try text.write(to: url, atomically: true, encoding: .utf8)
        }

        // Named exactly as DESIGN.md §10 step 2 lists them.
        try write("probe-check-rive.applescript", ProbeScript.probeScript(for: riveWatcher, profile: riveProfile, mode: .check))
        try write("probe-scan.applescript", ProbeScript.probeScript(for: fixtureWatcher, profile: nil, mode: .scan))
        try write("probe-pickStart.applescript", ProbeScript.probeScript(for: fixtureWatcher, profile: nil, mode: .pickStart))
        try write("probe-pickPoll.applescript", ProbeScript.probeScript(for: fixtureWatcher, profile: nil, mode: .pickPoll))
        try write("probe-pickStop.applescript", ProbeScript.probeScript(for: fixtureWatcher, profile: nil, mode: .pickStop))
        try write(
            "probe-highlight.applescript",
            ProbeScript.probeScript(
                for: fixtureWatcher, profile: nil,
                mode: .highlight(selector: "[data-testid=\"unread-direct-messages-count\"]")
            )
        )
        try write("activate.applescript", ProbeScript.activateTabScript(for: fixtureWatcher, profile: nil))
        try write("reload.applescript", ProbeScript.reloadTabScript(for: fixtureWatcher, profile: nil))

        // Extra artifacts, not in §10's named list but needed to actually run the
        // rest of §10 step 3/4 by hand: a check script for the fixture's own
        // autoBadge bell, and a scan script against whatever Rive tab is live.
        try write("probe-check.applescript", ProbeScript.probeScript(for: fixtureBellWatcher, profile: nil, mode: .check))
        try write("probe-scan-rive.applescript", ProbeScript.probeScript(for: riveWatcher, profile: riveProfile, mode: .scan))
    }
}
