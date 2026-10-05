import XCTest
@testable import WebWatcher

final class ZeroConfirmationTests: XCTestCase {
    func testOnlyBadgeNumberNeedsZeroConfirmation() {
        for type in WatchType.allCases {
            XCTAssertEqual(type.needsZeroConfirmation, type == .badgeNumber, "\(type)")
        }
    }
}

final class CheckLogTests: XCTestCase {
    func testALineIsOneLineWithATimestamp() {
        let l = CheckLog.line("web \"Reddit\" read=1\nsecond", now: Date(timeIntervalSince1970: 0))
        XCTAssertTrue(l.hasPrefix("1970-01-01T00:00:00.000Z web \"Reddit\" read=1 second"))
        XCTAssertEqual(l.filter { $0 == "\n" }.count, 1)
    }

    func testACheckThatCouldNotLookSaysItKeptThePreviousReading() {
        let w = Watcher(name: "Reddit", url: "https://www.reddit.com/", selector: ".badge", watchType: .badgeNumber, interval: .minutes2)
        var report = ProbeReport(observation: .cannot(.anchorMissing, detail: "anchor missing"))
        report.tabVisible = false
        let text = CheckLog.describe(watcher: w, result: WatchResult(watcherId: w.id, report: report, timestamp: Date()), previous: "1")
        XCTAssertTrue(text.contains("cannot=") && text.contains("kept the previous reading") && text.contains("was=1") && text.contains("tab=hidden"), text)
        let ok = CheckLog.describe(watcher: w, result: WatchResult(watcherId: w.id, report: ProbeReport(observation: .zero), timestamp: Date()), previous: "1")
        XCTAssertTrue(ok.contains("read=0 (confirmed)") && !ok.contains("kept"), ok)
    }

    func testTheLogIsOffUnderTests() { XCTAssertFalse(CheckLog.isEnabled) }
}
