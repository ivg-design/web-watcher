import XCTest
@testable import WebWatcher

final class ZeroConfirmationTests: XCTestCase {
    func testOnlyBadgeNumberNeedsZeroConfirmation() {
        for type in WatchType.allCases {
            XCTAssertEqual(type.needsZeroConfirmation, type == .badgeNumber, "\(type)")
        }
    }
}
